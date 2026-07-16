package cui.controls

import sdl.{Key, MouseButton, Rect, Renderer, UiEvent}
import cui.core.{State, Theme, UiContext}

private func tpTestContext(): UiContext {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    ctx.viewportWidth = 800.0
    ctx.viewportHeight = 600.0
    ctx
}

// Opens the picker (keyboard) and registers its overlay; the caller then drives it via dispatchOverlay.
private func openPicker(ctx: UiContext, picker: TimePicker): Unit {
    picker.layout(ctx, Rect(20.0, 40.0, 132.0, 38.0))
    ctx.focus("tp")
    let _ = picker.handle(ctx, UiEvent.KeyDown(Key.Down, false))
    picker.draw(ctx)
}

/*
 * Field at (20,40,132,38) → popup below at (20,82,220,250). Hours grid origin (28,112), cells 34x30,
 * 6 columns. Minute section: label row at y=238; the editor row sits a 2px cell inset below it and a
 * 9px editor inset from the content edge (the hour digits' column) — minus (37,262,34,30), value box
 * (71,262,48,30), plus (119,262,34,30); slider row (28,298,204,26) with the track inset 9px at both
 * ends, x=37 w=186, pointer line y=311.
 */
private func hourCellCenter(hour: Int64): (Float32, Float32) {
    let col = Float32(hour % 6)
    let row = Float32(hour / 6)
    (28.0 + col * 34.0 + 17.0, 112.0 + row * 30.0 + 15.0)
}

private let TPT_MINUS_X: Float32 = 54.0
private let TPT_VALUE_X: Float32 = 95.0
private let TPT_PLUS_X: Float32 = 136.0
private let TPT_STEPPER_Y: Float32 = 277.0
private let TPT_TRACK_X: Float32 = 37.0
private let TPT_TRACK_W: Float32 = 186.0
private let TPT_SLIDER_Y: Float32 = 311.0

// The x on the slider track whose linear 0–59 mapping lands on `minute` exactly.
private func sliderXFor(minute: Int64): Float32 {
    TPT_TRACK_X + TPT_TRACK_W * Float32(minute) / 59.0
}

@Test
func clampMinuteStepClamps(): Unit {
    @Expect(clampMinuteStep(0), 1)
    @Expect(clampMinuteStep(5), 5)
    @Expect(clampMinuteStep(999), 60)
}

@Test
func appendMinuteDigitCommitRules(): Unit {
    // A leading 0–5 waits for a second digit; the pair then commits.
    let (kept, pending) = appendMinuteDigit("", 3)
    @Expect(kept, "3")
    @Expect(pending.isNone())
    let (cleared, committed) = appendMinuteDigit("3", 7)
    @Expect(cleared, "")
    @Expect(committed.getOrThrow(), 37)
    // A leading 6–9 commits at once: no valid two-digit minute starts with it.
    let (_, seven) = appendMinuteDigit("", 7)
    @Expect(seven.getOrThrow(), 7)
    // The extremes of the two-digit range stay in bounds.
    let (_, low) = appendMinuteDigit("0", 0)
    @Expect(low.getOrThrow(), 0)
    let (_, high) = appendMinuteDigit("5", 9)
    @Expect(high.getOrThrow(), 59)
}

@Test
func sliderMinuteSnapsToStepWithExactEnds(): Unit {
    // Both ends are exact regardless of the step: far left 00, far right 59.
    @Expect(sliderMinute(36.0, 188.0, 36.0, 5), 0)
    @Expect(sliderMinute(36.0, 188.0, 224.0, 5), 59)
    @Expect(sliderMinute(36.0, 188.0, 0.0, 5), 0) // clamped short of the track
    @Expect(sliderMinute(36.0, 188.0, 400.0, 5), 59) // clamped past the track
    // Interior positions snap to step multiples.
    @Expect(sliderMinute(36.0, 188.0, 36.0 + 188.0 * 30.0 / 59.0, 5), 30)
    @Expect(sliderMinute(36.0, 188.0, 36.0 + 188.0 * 30.0 / 59.0, 15), 30)
    // A per-minute step maps positions one to one.
    @Expect(sliderMinute(36.0, 188.0, 36.0 + 188.0 * 37.0 / 59.0, 1), 37)
    // Steps 40–58 cannot snap onto 59 (59/s rounds below 2): the pinned end must still yield it.
    @Expect(sliderMinute(36.0, 188.0, 224.0, 45), 59)
    @Expect(sliderMinute(36.0, 188.0, 36.0 + 188.0 * 0.5, 45), 45) // interior still snaps to the step
}

@Test
func timePickerClickHourAndStepMinute(): Unit {
    let ctx = tpTestContext()
    let selected = State<TimeOfDay>(TimeOfDay(9, 0))
    let picker = TimePicker(selected, minuteStep: 5, key: "tp")
    picker.layout(ctx, Rect(20.0, 40.0, 132.0, 38.0))
    @Expect(picker.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 30.0, 50.0)))
    picker.draw(ctx)

    // Clicking hour 14 updates the hour and keeps the pop-up open.
    let (hx, hy) = hourCellCenter(14)
    @Expect(ctx.dispatchOverlay(UiEvent.MouseDown(MouseButton.Left, hx, hy)))
    @Expect(selected.value, TimeOfDay(14, 0))
    // + steps a single minute even though the coarse step is 5.
    @Expect(ctx.dispatchOverlay(UiEvent.MouseDown(MouseButton.Left, TPT_PLUS_X, TPT_STEPPER_Y)))
    @Expect(selected.value, TimeOfDay(14, 1))
    // − wraps within the hour (01 → 00 → 59) without carrying into it.
    @Expect(ctx.dispatchOverlay(UiEvent.MouseDown(MouseButton.Left, TPT_MINUS_X, TPT_STEPPER_Y)))
    @Expect(ctx.dispatchOverlay(UiEvent.MouseDown(MouseButton.Left, TPT_MINUS_X, TPT_STEPPER_Y)))
    @Expect(selected.value, TimeOfDay(14, 59))
}

@Test
func timePickerSliderDragsCoarseMinute(): Unit {
    let ctx = tpTestContext()
    let selected = State<TimeOfDay>(TimeOfDay(10, 0))
    let picker = TimePicker(selected, minuteStep: 5, key: "tp")
    openPicker(ctx, picker)

    // Pressing the track jumps to the snapped minute and starts a drag.
    @Expect(ctx.dispatchOverlay(UiEvent.MouseDown(MouseButton.Left, sliderXFor(30), TPT_SLIDER_Y)))
    @Expect(selected.value, TimeOfDay(10, 30))
    // Dragging follows the pointer, still snapping to the 5-minute grain.
    ctx.leftMouseDown = true
    @Expect(ctx.dispatchOverlay(UiEvent.MouseMove(sliderXFor(45), TPT_SLIDER_Y)))
    @Expect(selected.value, TimeOfDay(10, 45))
    // Releasing at the far right lands on the exact end of the range.
    ctx.leftMouseDown = false
    @Expect(ctx.dispatchOverlay(UiEvent.MouseUp(MouseButton.Left, TPT_TRACK_X + TPT_TRACK_W, TPT_SLIDER_Y)))
    @Expect(selected.value, TimeOfDay(10, 59))
    ctx.clearDrag()
}

@Test
func timePickerTypedMinutesCommit(): Unit {
    let ctx = tpTestContext()
    let selected = State<TimeOfDay>(TimeOfDay(9, 15))
    let picker = TimePicker(selected, key: "tp")
    openPicker(ctx, picker)

    // Typing works without clicking the value box: "3" pends, "7" completes 37.
    @Expect(ctx.dispatchOverlay(UiEvent.KeyDown(Key.Digit(51), false))) // '3'
    @Expect(selected.value, TimeOfDay(9, 15)) // still pending
    @Expect(ctx.dispatchOverlay(UiEvent.KeyDown(Key.Digit(55), false))) // '7'
    @Expect(selected.value, TimeOfDay(9, 37))
    // A leading 8 commits immediately as 08.
    @Expect(ctx.dispatchOverlay(UiEvent.KeyDown(Key.Digit(56), false))) // '8'
    @Expect(selected.value, TimeOfDay(9, 8))
}

@Test
func timePickerEditCommitAndCancel(): Unit {
    let ctx = tpTestContext()
    let selected = State<TimeOfDay>(TimeOfDay(9, 15))
    let picker = TimePicker(selected, key: "tp")
    openPicker(ctx, picker)

    // Click the value box, type one digit, Enter commits it as a single-digit minute.
    @Expect(ctx.dispatchOverlay(UiEvent.MouseDown(MouseButton.Left, TPT_VALUE_X, TPT_STEPPER_Y)))
    @Expect(ctx.dispatchOverlay(UiEvent.KeyDown(Key.Digit(52), false))) // '4'
    @Expect(ctx.dispatchOverlay(UiEvent.KeyDown(Key.Enter, false)))
    @Expect(selected.value, TimeOfDay(9, 4)) // committed, pop-up still open
    // A re-click on the value box mid-edit keeps the pending digit: "3", click, "7" → 37.
    @Expect(ctx.dispatchOverlay(UiEvent.KeyDown(Key.Digit(51), false))) // '3'
    @Expect(ctx.dispatchOverlay(UiEvent.MouseDown(MouseButton.Left, TPT_VALUE_X, TPT_STEPPER_Y)))
    @Expect(ctx.dispatchOverlay(UiEvent.KeyDown(Key.Digit(55), false))) // '7'
    @Expect(selected.value, TimeOfDay(9, 37))
    // Escape while a digit pends only abandons the edit; the pop-up stays open.
    @Expect(ctx.dispatchOverlay(UiEvent.MouseDown(MouseButton.Left, TPT_VALUE_X, TPT_STEPPER_Y)))
    @Expect(ctx.dispatchOverlay(UiEvent.KeyDown(Key.Digit(50), false))) // '2'
    @Expect(ctx.dispatchOverlay(UiEvent.KeyDown(Key.Escape, false)))
    @Expect(selected.value, TimeOfDay(9, 37)) // unchanged
    // The pop-up is still up: a second Escape (no pending edit) dismisses it.
    @Expect(ctx.dispatchOverlay(UiEvent.KeyDown(Key.Escape, false)))
    @Expect(!ctx.dispatchOverlay(UiEvent.KeyDown(Key.Up, false))) // overlay gone
}

@Test
func timePickerArrowsNudgeTime(): Unit {
    let ctx = tpTestContext()
    let selected = State<TimeOfDay>(TimeOfDay(10, 30))
    let picker = TimePicker(selected, minuteStep: 5, key: "tp")
    openPicker(ctx, picker)

    @Expect(ctx.dispatchOverlay(UiEvent.KeyDown(Key.Up, false))) // +1 minute
    @Expect(selected.value, TimeOfDay(10, 31))
    @Expect(ctx.dispatchOverlay(UiEvent.KeyDown(Key.Right, false))) // +1 hour
    @Expect(selected.value, TimeOfDay(11, 31))
    @Expect(ctx.dispatchOverlay(UiEvent.KeyDown(Key.Down, false))) // -1 minute
    @Expect(selected.value, TimeOfDay(11, 30))
    @Expect(ctx.dispatchOverlay(UiEvent.KeyDown(Key.Left, false))) // -1 hour
    @Expect(selected.value, TimeOfDay(10, 30))
}

@Test
func timePickerEscapeClosesAndStopsConsuming(): Unit {
    let ctx = tpTestContext()
    let selected = State<TimeOfDay>(TimeOfDay(10, 30))
    let picker = TimePicker(selected, key: "tp")
    openPicker(ctx, picker)
    @Expect(ctx.dispatchOverlay(UiEvent.KeyDown(Key.Escape, false)))
    // The overlay was removed on close, so nothing consumes further events.
    @Expect(!ctx.dispatchOverlay(UiEvent.KeyDown(Key.Up, false)))
    @Expect(selected.value, TimeOfDay(10, 30)) // unchanged
}

@Test
func timePickerClickOutsideCommitsPendingEditAndDismisses(): Unit {
    let ctx = tpTestContext()
    let selected = State<TimeOfDay>(TimeOfDay(10, 30))
    let picker = TimePicker(selected, key: "tp")
    openPicker(ctx, picker)
    // A digit pends when the outside click lands: it commits (like blur) before dismissal.
    @Expect(ctx.dispatchOverlay(UiEvent.KeyDown(Key.Digit(53), false))) // '5'
    @Expect(ctx.dispatchOverlay(UiEvent.MouseDown(MouseButton.Left, 500.0, 500.0)))
    @Expect(selected.value, TimeOfDay(10, 5))
    @Expect(!ctx.dispatchOverlay(UiEvent.KeyDown(Key.Up, false))) // overlay gone
}
