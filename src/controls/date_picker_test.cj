package cui.controls

import sdl.{Key, MouseButton, Rect, Renderer, UiEvent}
import cui.core.{State, Theme, UiContext}

private func dpTestContext(): UiContext {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    ctx.viewportWidth = 800.0
    ctx.viewportHeight = 600.0
    ctx
}

// Opens the picker (keyboard) and registers its overlay, returning nothing — the caller then drives the
// calendar through ctx.dispatchOverlay. The field is laid out at a fixed spot so the popup is stable.
private func openPicker(ctx: UiContext, picker: DatePicker): Unit {
    picker.layout(ctx, Rect(20.0, 40.0, 176.0, 38.0))
    ctx.focus("dp")
    let _ = picker.handle(ctx, UiEvent.KeyDown(Key.Down, false))
    picker.draw(ctx)
}

// The centre of the cell showing `day` in the calendar opened over the fixed field position. Mirrors
// the picker's own grid math (pad 8, header 34, weekday 24, cell 34x30, popup at 20,82).
private func dayCellCenter(view: CalendarDate, day: Int64): (Float32, Float32) {
    let firstWd = view.firstWeekdayIndex()
    let index = (day - 1) + firstWd
    let col = Float32(index % 7)
    let row = Float32(index / 7)
    let cx: Float32 = 28.0 + col * 34.0 + 17.0 // grid origin x (popup.x 20 + pad 8) + column
    let cy: Float32 = 148.0 + row * 30.0 + 15.0 // grid origin y (82 + pad 8 + header 34 + weekday 24) + row
    (cx, cy)
}

@Test
func datePickerKeyboardOpenNavigateSelect(): Unit {
    let ctx = dpTestContext()
    let selected = State<CalendarDate>(CalendarDate(2026, 7, 15))
    let picker = DatePicker(selected, key: "dp")
    openPicker(ctx, picker)

    // Highlight starts on the selected day; Right steps a day, Enter commits.
    @Expect(ctx.dispatchOverlay(UiEvent.KeyDown(Key.Right, false)))
    @Expect(ctx.dispatchOverlay(UiEvent.KeyDown(Key.Enter, false)))
    @Expect(selected.value, CalendarDate(2026, 7, 16))
}

@Test
func datePickerArrowDownMovesByWeek(): Unit {
    let ctx = dpTestContext()
    let selected = State<CalendarDate>(CalendarDate(2026, 7, 15))
    let picker = DatePicker(selected, key: "dp")
    openPicker(ctx, picker)

    @Expect(ctx.dispatchOverlay(UiEvent.KeyDown(Key.Down, false))) // +7 days
    @Expect(ctx.dispatchOverlay(UiEvent.KeyDown(Key.Enter, false)))
    @Expect(selected.value, CalendarDate(2026, 7, 22))
}

@Test
func datePickerArrowRollsIntoAdjacentMonth(): Unit {
    let ctx = dpTestContext()
    let selected = State<CalendarDate>(CalendarDate(2026, 7, 31))
    let picker = DatePicker(selected, key: "dp")
    openPicker(ctx, picker)

    // The last day + 1 rolls into August, paging the shown month with it.
    @Expect(ctx.dispatchOverlay(UiEvent.KeyDown(Key.Right, false)))
    @Expect(ctx.dispatchOverlay(UiEvent.KeyDown(Key.Enter, false)))
    @Expect(selected.value, CalendarDate(2026, 8, 1))
}

@Test
func datePickerHomePagesToPreviousMonthAcrossYear(): Unit {
    let ctx = dpTestContext()
    let selected = State<CalendarDate>(CalendarDate(2026, 1, 15))
    let picker = DatePicker(selected, key: "dp")
    openPicker(ctx, picker)

    @Expect(ctx.dispatchOverlay(UiEvent.KeyDown(Key.Home, false))) // previous month
    @Expect(ctx.dispatchOverlay(UiEvent.KeyDown(Key.Enter, false)))
    @Expect(selected.value, CalendarDate(2025, 12, 15))
}

@Test
func datePickerEscapeClosesWithoutSelecting(): Unit {
    let ctx = dpTestContext()
    let selected = State<CalendarDate>(CalendarDate(2026, 7, 15))
    let picker = DatePicker(selected, key: "dp")
    openPicker(ctx, picker)

    let _ = ctx.dispatchOverlay(UiEvent.KeyDown(Key.Right, false)) // move highlight, do not commit
    @Expect(ctx.dispatchOverlay(UiEvent.KeyDown(Key.Escape, false)))
    @Expect(selected.value, CalendarDate(2026, 7, 15)) // unchanged
    // The overlay was removed on close, so nothing consumes further events.
    @Expect(!ctx.dispatchOverlay(UiEvent.KeyDown(Key.Enter, false)))
}

@Test
func datePickerClickSelectsDay(): Unit {
    let ctx = dpTestContext()
    let selected = State<CalendarDate>(CalendarDate(2026, 7, 1))
    let picker = DatePicker(selected, key: "dp")
    picker.layout(ctx, Rect(20.0, 40.0, 176.0, 38.0))
    // Open with a real press on the field, then register the overlay.
    @Expect(picker.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 30.0, 50.0)))
    picker.draw(ctx)

    let (cx, cy) = dayCellCenter(CalendarDate(2026, 7, 1), 10)
    @Expect(ctx.dispatchOverlay(UiEvent.MouseDown(MouseButton.Left, cx, cy)))
    @Expect(selected.value, CalendarDate(2026, 7, 10))
}

@Test
func datePickerClickArrowPagesMonthWithoutClosing(): Unit {
    let ctx = dpTestContext()
    let selected = State<CalendarDate>(CalendarDate(2026, 7, 1))
    let picker = DatePicker(selected, key: "dp")
    openPicker(ctx, picker)

    // The previous-month arrow sits at the header's left: popup(20,82) + pad 8 → box centred near (45,107).
    @Expect(ctx.dispatchOverlay(UiEvent.MouseDown(MouseButton.Left, 45.0, 107.0)))
    // Still open: committing now selects in June.
    @Expect(ctx.dispatchOverlay(UiEvent.KeyDown(Key.Enter, false)))
    @Expect(selected.value.year, 2026)
    @Expect(selected.value.month, 6)
}
