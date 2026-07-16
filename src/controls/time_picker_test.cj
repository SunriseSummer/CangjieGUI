package cui.controls

import sdl.{Key, MouseButton, Rect, Renderer, UiEvent}
import cui.core.{TimeOfDay, State, Theme, UiContext}

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

// Field at (20,40,132,38) → popup below at (20,82). Hours grid origin (28,112); minutes origin (28,260).
// Cells are 34x30; grids are 6 columns wide.
private func hourCellCenter(hour: Int64): (Float32, Float32) {
    let col = Float32(hour % 6)
    let row = Float32(hour / 6)
    (28.0 + col * 34.0 + 17.0, 112.0 + row * 30.0 + 15.0)
}

private func minuteCellCenter(index: Int64): (Float32, Float32) {
    let col = Float32(index % 6)
    let row = Float32(index / 6)
    (28.0 + col * 34.0 + 17.0, 260.0 + row * 30.0 + 15.0)
}

@Test
func minuteOptionsRespectStep(): Unit {
    @Expect(minuteOptions(5).size, 12)
    @Expect(minuteOptions(15), [0, 15, 30, 45])
    @Expect(minuteOptions(30), [0, 30])
    @Expect(minuteOptions(0).size, 60) // step clamped to 1
}

@Test
func minuteRowCountRows(): Unit {
    @Expect(minuteRowCount(12), 2)
    @Expect(minuteRowCount(4), 1)
    @Expect(minuteRowCount(60), 10)
}

@Test
func clampMinuteStepClamps(): Unit {
    @Expect(clampMinuteStep(0), 1)
    @Expect(clampMinuteStep(5), 5)
    @Expect(clampMinuteStep(999), 60)
}

@Test
func timePickerClickHourAndMinute(): Unit {
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
    // Minute option index 6 is 30 (step 5); clicking it updates the minute.
    let (mx, my) = minuteCellCenter(6)
    @Expect(ctx.dispatchOverlay(UiEvent.MouseDown(MouseButton.Left, mx, my)))
    @Expect(selected.value, TimeOfDay(14, 30))
}

@Test
func timePickerArrowsNudgeTime(): Unit {
    let ctx = tpTestContext()
    let selected = State<TimeOfDay>(TimeOfDay(10, 30))
    let picker = TimePicker(selected, minuteStep: 5, key: "tp")
    openPicker(ctx, picker)

    @Expect(ctx.dispatchOverlay(UiEvent.KeyDown(Key.Up, false))) // +1 step (5 min)
    @Expect(selected.value, TimeOfDay(10, 35))
    @Expect(ctx.dispatchOverlay(UiEvent.KeyDown(Key.Right, false))) // +1 hour
    @Expect(selected.value, TimeOfDay(11, 35))
    @Expect(ctx.dispatchOverlay(UiEvent.KeyDown(Key.Down, false))) // -1 step
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
func timePickerClickOutsideDismisses(): Unit {
    let ctx = tpTestContext()
    let selected = State<TimeOfDay>(TimeOfDay(10, 30))
    let picker = TimePicker(selected, key: "tp")
    openPicker(ctx, picker)
    @Expect(ctx.dispatchOverlay(UiEvent.MouseDown(MouseButton.Left, 500.0, 500.0)))
    @Expect(!ctx.dispatchOverlay(UiEvent.KeyDown(Key.Up, false))) // overlay gone
}
