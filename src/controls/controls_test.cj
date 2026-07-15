package cui.controls

import sdl.{Key, MouseButton, Rect, Renderer, Size, UiEvent}
import cui.core.{Button, Modal, Spacer, State, StateStore, Theme, UiContext, Widget, buildRoot, emit}

private func controlTestContext(): UiContext {
    UiContext(Renderer.headless(), Theme.light())
}

@Test
func listViewUsesScrollOffsetWhenSelectingRows(): Unit {
    let ctx = controlTestContext()
    let selected = State<Int64>(0)
    let scroll = State<Float32>(0.0)
    let list = ListView(["A", "B", "C", "D", "E", "F"], selected, scroll: Some(scroll))

    list.layout(ctx, Rect(0.0, 0.0, 180.0, 60.0))

    @Expect(list.handle(ctx, UiEvent.MouseWheel(0.0, -1.0, 12.0, 12.0)))
    @Expect(scroll.value, Float32(72.0))
    @Expect(list.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 12.0, 12.0)))
    @Expect(selected.value, Int64(2))
}

@Test
func listViewArrowKeysMoveSelectionAndKeepItVisible(): Unit {
    let ctx = controlTestContext()
    let selected = State<Int64>(0)
    let scroll = State<Float32>(0.0)
    let list = ListView(["A", "B", "C", "D", "E", "F", "G", "H"], selected, scroll: Some(scroll))
    list.layout(ctx, Rect(0.0, 0.0, 180.0, 90.0))
    ctx.focus("ListView")

    @Expect(list.handle(ctx, UiEvent.KeyDown(Key.Down, false)))
    @Expect(selected.value, Int64(1))

    @Expect(list.handle(ctx, UiEvent.KeyDown(Key.End, false)))
    @Expect(selected.value, Int64(7))
    @Expect(scroll.value > Float32(0.0)) // last row scrolled into view

    @Expect(list.handle(ctx, UiEvent.KeyDown(Key.Home, false)))
    @Expect(selected.value, Int64(0))
    @Expect(scroll.value, Float32(0.0))

    @Expect(list.handle(ctx, UiEvent.KeyDown(Key.Up, false))) // clamps at the top
    @Expect(selected.value, Int64(0))
}

@Test
func listViewIgnoresArrowsWithoutFocus(): Unit {
    let ctx = controlTestContext()
    let selected = State<Int64>(3)
    let list = ListView(["A", "B", "C", "D", "E"], selected)
    list.layout(ctx, Rect(0.0, 0.0, 180.0, 200.0))

    @Expect(!list.handle(ctx, UiEvent.KeyDown(Key.Down, false)))
    @Expect(selected.value, Int64(3))
}

// Without an external scroll state, the wheel offset must survive the per-frame rebuild — a
// regression guard for the fresh-State-each-frame bug that made a scrolled list spring back.
@Test
func listViewRetainsScrollAcrossRebuildsWithoutExternalState(): Unit {
    let ctx = controlTestContext()
    let store = StateStore()
    let selected = State<Int64>(0)
    let captured = State<?ListView>(None)
    let build = {
        =>
        let _ = buildRoot({
            =>
            let list = ListView(["A", "B", "C", "D", "E", "F", "G", "H"], selected)
            captured.value = Some(list)
        }, store)
    }

    build()
    let first = captured.value.getOrThrow()
    first.layout(ctx, Rect(0.0, 0.0, 180.0, 60.0))
    let _ = first.handle(ctx, UiEvent.MouseWheel(0.0, -1.0, 12.0, 12.0)) // offset -> 72

    // Next frame: a brand-new ListView instance under the same store must see the retained offset.
    build()
    let second = captured.value.getOrThrow()
    second.layout(ctx, Rect(0.0, 0.0, 180.0, 60.0))
    // A click near the top now lands on a scrolled-past row (offset 72 / 28px rows -> index 2),
    // which only holds if the offset carried over rather than resetting to 0.
    @Expect(second.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 12.0, 12.0)))
    @Expect(selected.value, Int64(2))
}

@Test
func listViewScrollbarThumbIsDraggable(): Unit {
    let ctx = controlTestContext()
    let selected = State<Int64>(0)
    let scroll = State<Float32>(0.0)
    let list = ListView(Array<String>(20, {i => "row ${i}"}), selected, scroll: Some(scroll))
    list.layout(ctx, Rect(0.0, 0.0, 200.0, 100.0))

    // Grab the thumb in the right-edge lane, then drag it down.
    @Expect(list.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 195.0, 8.0)))
    ctx.leftMouseDown = true
    @Expect(list.handle(ctx, UiEvent.MouseMove(195.0, 60.0)))
    @Expect(scroll.value > Float32(0.0))
}

@Test
func dropdownOpensThenSelectsAnItemViaTheOverlay(): Unit {
    let ctx = controlTestContext()
    ctx.viewportWidth = 300.0
    ctx.viewportHeight = 400.0
    let selected = State<Int64>(0)
    let dropdown = Dropdown(["浅色", "深色", "跟随系统"], selected, key: "theme")
    dropdown.layout(ctx, Rect(20.0, 40.0, 180.0, 34.0))

    // A click opens it; drawing registers the popup as the interactive overlay.
    @Expect(dropdown.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 30.0, 50.0)))
    dropdown.draw(ctx)
    @Expect(ctx.hasOverlay())

    // The popup sits below the box; y=120 lands on the second row. The overlay consumes the
    // click, selects it and closes.
    @Expect(ctx.dispatchOverlay(UiEvent.MouseDown(MouseButton.Left, 100.0, 120.0)))
    @Expect(selected.value, Int64(1))
    @Expect(!ctx.hasOverlay())
}

@Test
func dropdownDismissesOnOutsideClickAndEscape(): Unit {
    let ctx = controlTestContext()
    ctx.viewportWidth = 300.0
    ctx.viewportHeight = 400.0
    let selected = State<Int64>(1)
    let dropdown = Dropdown(["A", "B", "C"], selected, key: "d2")
    dropdown.layout(ctx, Rect(20.0, 40.0, 180.0, 34.0))

    let _ = dropdown.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 30.0, 50.0))
    dropdown.draw(ctx)
    @Expect(ctx.dispatchOverlay(UiEvent.MouseDown(MouseButton.Left, 5.0, 5.0))) // outside the popup
    @Expect(selected.value, Int64(1)) // unchanged
    @Expect(!ctx.hasOverlay())

    let _ = dropdown.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 30.0, 50.0))
    dropdown.draw(ctx)
    @Expect(ctx.dispatchOverlay(UiEvent.KeyDown(Key.Escape, false)))
    @Expect(!ctx.hasOverlay())
}

@Test
func dropdownArrowsMoveHighlightWhileOpen(): Unit {
    let ctx = controlTestContext()
    ctx.viewportWidth = 300.0
    ctx.viewportHeight = 400.0
    let selected = State<Int64>(0)
    let dropdown = Dropdown(["A", "B", "C"], selected, key: "d3")
    dropdown.layout(ctx, Rect(20.0, 40.0, 180.0, 34.0))

    let _ = dropdown.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 30.0, 50.0))
    dropdown.draw(ctx)

    @Expect(ctx.dispatchOverlay(UiEvent.KeyDown(Key.Down, false)))
    @Expect(selected.value, Int64(1))
    @Expect(ctx.hasOverlay()) // arrows do not close the popup
    let _ = ctx.dispatchOverlay(UiEvent.KeyDown(Key.Down, false))
    let _ = ctx.dispatchOverlay(UiEvent.KeyDown(Key.Down, false)) // clamps at the last item
    @Expect(selected.value, Int64(2))
    let _ = ctx.dispatchOverlay(UiEvent.KeyDown(Key.Up, false))
    @Expect(selected.value, Int64(1))
}

// A dropdown inside a modal dialog — the nesting the overlay stack exists for. The popup
// registers above the dialog and wins its clicks; selecting closes only the popup, and the
// dialog dismisses on a later Escape.
@Test
func dropdownInsideModalSelectsWithoutClosingDialog(): Unit {
    let ctx = controlTestContext()
    ctx.viewportWidth = 400.0
    ctx.viewportHeight = 400.0
    let presented = State<Bool>(true)
    let selected = State<Int64>(0)
    let modal = Modal(presented) {
        Dropdown(["北京", "上海", "广州"], selected, key: "city")
    }
    modal.layout(ctx, Rect.zero())
    modal.draw(ctx)
    @Expect(ctx.overlayCount(), Int64(1))

    // The dropdown measures 190x34, so the dialog centres at (83,161,234,78) and the control
    // sits at (105,183,190,34). A press inside, routed through the dialog, opens the popup;
    // drawing the stack registers it above the dialog within the same frame.
    @Expect(ctx.dispatchOverlay(UiEvent.MouseDown(MouseButton.Left, 110.0, 190.0)))
    ctx.drawActiveOverlay()
    @Expect(ctx.overlayCount(), Int64(2))

    // The popup opens below the box at (105,221); rows start at y=226, 28px each, so y=260
    // lands on the second item. Selecting closes the popup only — the dialog stays open.
    @Expect(ctx.dispatchOverlay(UiEvent.MouseDown(MouseButton.Left, 120.0, 260.0)))
    @Expect(selected.value, Int64(1))
    @Expect(ctx.overlayCount(), Int64(1))
    @Expect(presented.value)

    // With the popup gone, Escape reaches the dialog and dismisses it.
    @Expect(ctx.dispatchOverlay(UiEvent.KeyDown(Key.Escape, false)))
    @Expect(!presented.value)
    @Expect(!ctx.hasOverlay())
}

// A long list scrolls inside the popup: the wheel moves the window, hit-testing follows the
// offset, keyboard navigation keeps the highlight visible, and the padding strips hit nothing.
@Test
func dropdownLongListScrollsInsidePopup(): Unit {
    let ctx = controlTestContext()
    ctx.viewportWidth = 300.0
    ctx.viewportHeight = 300.0
    let selected = State<Int64>(0)
    let dropdown = Dropdown(Array<String>(30, {i => "项 ${i}"}), selected, key: "long")
    dropdown.layout(ctx, Rect(20.0, 40.0, 180.0, 34.0))

    // Below the control there are 218px, above only 32px: the popup opens below at 218px
    // (20,78,180,218) and the 840px list scrolls inside a 208px window.
    let _ = dropdown.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 30.0, 50.0))
    dropdown.draw(ctx)
    @Expect(ctx.hasOverlay())

    // One wheel notch scrolls 72px; a click at y=88 then lands on row (88-83+72)/28 = 2.
    @Expect(ctx.dispatchOverlay(UiEvent.MouseWheel(0.0, -1.0, 100.0, 150.0)))
    @Expect(ctx.dispatchOverlay(UiEvent.MouseDown(MouseButton.Left, 100.0, 88.0)))
    @Expect(selected.value, Int64(2))
    @Expect(!ctx.hasOverlay())

    // Reopen (row 2 reveals near the top, unscrolled); a press in the top padding strip
    // (y=80 < 83) hits nothing — the popup dismisses without changing the selection.
    let _ = dropdown.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 30.0, 50.0))
    dropdown.draw(ctx)
    @Expect(ctx.dispatchOverlay(UiEvent.MouseDown(MouseButton.Left, 100.0, 80.0)))
    @Expect(selected.value, Int64(2))
    @Expect(!ctx.hasOverlay())

    // Reopen and walk down with the keyboard: the window scrolls to keep the highlight
    // visible. After reaching row 12 the offset is 12*28+28-208 = 156, so a click near the
    // top of the list (y=84) lands on row (84-83+156)/28 = 5 — not row 0.
    let _ = dropdown.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 30.0, 50.0))
    dropdown.draw(ctx)
    var presses = 0
    while (presses < 10) {
        let _ = ctx.dispatchOverlay(UiEvent.KeyDown(Key.Down, false))
        presses += 1
    }
    @Expect(selected.value, Int64(12))
    @Expect(ctx.dispatchOverlay(UiEvent.MouseDown(MouseButton.Left, 100.0, 84.0)))
    @Expect(selected.value, Int64(5))
    @Expect(!ctx.hasOverlay())
}

// The popup scrollbar rides in the standard right-edge lane: grabbing the thumb neither
// selects nor closes, and dragging it scrolls the window.
@Test
func dropdownPopupScrollbarDragsAndStaysOpen(): Unit {
    let ctx = controlTestContext()
    ctx.viewportWidth = 300.0
    ctx.viewportHeight = 300.0
    let selected = State<Int64>(0)
    let dropdown = Dropdown(Array<String>(30, {i => "row ${i}"}), selected, key: "bar")
    dropdown.layout(ctx, Rect(20.0, 40.0, 180.0, 34.0))
    let _ = dropdown.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 30.0, 50.0))
    dropdown.draw(ctx)

    // The bar lane hugs the popup's right edge (x in 192..198); the thumb starts at the top.
    @Expect(ctx.dispatchOverlay(UiEvent.MouseDown(MouseButton.Left, 195.0, 90.0)))
    @Expect(ctx.hasOverlay()) // grabbing the bar neither selects nor closes
    ctx.leftMouseDown = true
    @Expect(ctx.dispatchOverlay(UiEvent.MouseMove(195.0, 200.0)))
    ctx.leftMouseDown = false
    ctx.clearDrag()

    // After the drag a click near the top of the list lands deep in the list, proving the
    // window scrolled (offset ≈ 453 → row 16); an unscrolled window would select row 0.
    @Expect(ctx.dispatchOverlay(UiEvent.MouseDown(MouseButton.Left, 100.0, 90.0)))
    @Expect(selected.value > Int64(5))
    @Expect(!ctx.hasOverlay())
}

// A column's custom cell painter replaces its text rendering: it runs once per visible row
// inside the cell clip, receives the original row index paired with that row's value, and
// sorting still reorders by the string value under the column's numeric rule.
@Test
func tableCustomCellPainterFollowsDisplayOrder(): Unit {
    let ctx = controlTestContext()
    let selected = State<Int64>(-1)
    let painted = State<String>("")
    let painter: (UiContext, Int64, String, Rect) -> Unit = {
        _, row, value, cell =>
        painted.value = painted.value + "(${row}:${value}@${Int64(cell.x)})"
    }
    let columns: Array<TableColumn> = [
        TableColumn("名称", 100.0),
        TableColumn("进度", 120.0, numeric: true, cell: painter)
    ]
    let rows: Array<Array<String>> = [["乙", "30%"], ["甲", "90%"], ["丙", "60%"]]
    let table = Table(columns, rows, selected, key: "cells")
    table.layout(ctx, Rect(0.0, 0.0, 260.0, 200.0))

    table.draw(ctx)
    @Expect(painted.value, "(0:30%@100)(1:90%@100)(2:60%@100)")

    // Sort by the progress column (numeric ascending): the painter runs in the new display
    // order, each invocation still pairing an original row index with its own value.
    let _ = table.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 150.0, 10.0))
    painted.value = ""
    table.draw(ctx)
    @Expect(painted.value, "(0:30%@100)(2:60%@100)(1:90%@100)")
}

// SegmentedControl joins the focus ring: Left/Right switch the selected segment while it
// holds focus (clamped at the ends) and pass through untouched otherwise.
@Test
func segmentedControlKeyboardSwitchesSegments(): Unit {
    let ctx = controlTestContext()
    let store = StateStore()
    let choice = State<Int64>(1)
    let captured = State<?Widget>(None)
    let _ = buildRoot({
        => captured.value = Some(SegmentedControl(["日", "周", "月"], choice))
    }, store)
    let ring = store.focusRing()
    @Expect(ring.size, 1) // the control registered exactly one focus stop

    let control = captured.value.getOrThrow()
    control.layout(ctx, Rect(0.0, 0.0, 288.0, 34.0))
    @Expect(!control.handle(ctx, UiEvent.KeyDown(Key.Right, false))) // unfocused: not consumed
    @Expect(choice.value, Int64(1))

    ctx.focus(ring[0])
    @Expect(control.handle(ctx, UiEvent.KeyDown(Key.Right, false)))
    @Expect(choice.value, Int64(2))
    let _ = control.handle(ctx, UiEvent.KeyDown(Key.Right, false))
    @Expect(choice.value, Int64(2)) // clamped at the last segment
    @Expect(control.handle(ctx, UiEvent.KeyDown(Key.Left, false)))
    @Expect(choice.value, Int64(1))
}

// TabView's strip is a focus stop ahead of its page content: Left/Right switch tabs while
// the strip has focus and fall through to the active page otherwise.
@Test
func tabViewKeyboardSwitchesTabs(): Unit {
    let ctx = controlTestContext()
    let store = StateStore()
    let page = State<Int64>(0)
    let captured = State<?Widget>(None)
    let _ = buildRoot({
        =>
        captured.value = Some(TabView(["概览", "设置"], page) {
            Spacer()
            Spacer()
        })
    }, store)
    let ring = store.focusRing()
    @Expect(ring.size, 1) // the strip registered exactly one focus stop

    let tabs = captured.value.getOrThrow()
    tabs.layout(ctx, Rect(0.0, 0.0, 400.0, 300.0))
    @Expect(!tabs.handle(ctx, UiEvent.KeyDown(Key.Right, false))) // unfocused: falls to the page
    @Expect(page.value, Int64(0))

    ctx.focus(ring[0])
    @Expect(tabs.handle(ctx, UiEvent.KeyDown(Key.Right, false)))
    @Expect(page.value, Int64(1))
    @Expect(tabs.handle(ctx, UiEvent.KeyDown(Key.Left, false)))
    @Expect(page.value, Int64(0))
}

// Focus stops on hidden tab pages are dead ends (only the active page receives events), so
// the build takes them out of the ring; switching tabs re-registers on the next rebuild.
@Test
func tabViewHiddenPageLeavesFocusRing(): Unit {
    let store = StateStore()
    let page = State<Int64>(0)
    let build = {
        =>
        let _ = buildRoot({
            =>
            let _ = TabView(["一", "二"], page) {
                Button("甲", {=> ()}).key("p1.a")
                Button("乙", {=> ()}).key("p2.a")
            }
        }, store)
    }
    build()
    let first = store.focusRing()
    @Expect(first.size, 2) // the strip plus the active page's button
    @Expect(first[1], "p1.a")

    page.value = 1
    build()
    let second = store.focusRing()
    @Expect(second.size, 2)
    @Expect(second[1], "p2.a")
}

@Test
func sliderMouseAndKeyboardEventsUpdateState(): Unit {
    let ctx = controlTestContext()
    let value = State<Float32>(0.0)
    let slider = Slider(value, key: "volume", lower: 0.0, upper: 10.0)

    slider.layout(ctx, Rect(0.0, 0.0, 116.0, 38.0))
    @Expect(slider.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 58.0, 19.0)))
    @Expect(value.value, Float32(5.0))
    @Expect(ctx.isDragging("volume"))

    ctx.leftMouseDown = true
    @Expect(slider.handle(ctx, UiEvent.MouseMove(108.0, 19.0)))
    @Expect(value.value, Float32(10.0))

    @Expect(slider.handle(ctx, UiEvent.KeyDown(Key.Left, false)))
    @Expect(value.value, Float32(9.9))
}

@Test
func sliderStepSnapsToDiscreteMultiples(): Unit {
    let ctx = controlTestContext()
    let value = State<Float32>(3.0)
    // step 2 over [0, 10]: the legal values are 0, 2, 4, 6, 8, 10. Construction snaps the initial 3.
    let slider = Slider(value, key: "vol", lower: 0.0, upper: 10.0, step: 2.0)
    @Expect(value.value, Float32(4.0))

    slider.layout(ctx, Rect(0.0, 0.0, 116.0, 38.0))
    // The track spans x in [8, 108] (width 100). x=70 -> amount 0.62 -> raw 6.2, which snaps to 6.
    @Expect(slider.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 70.0, 19.0)))
    @Expect(value.value, Float32(6.0))

    // Arrow keys move by exactly one increment, staying on the grid.
    @Expect(slider.handle(ctx, UiEvent.KeyDown(Key.Right, false)))
    @Expect(value.value, Float32(8.0))
    @Expect(slider.handle(ctx, UiEvent.KeyDown(Key.Left, false)))
    @Expect(value.value, Float32(6.0))
}

@Test
func segmentedControlSelectsClickedSegment(): Unit {
    let ctx = controlTestContext()
    let selected = State<Int64>(0)
    let control = SegmentedControl(["One", "Two", "Three"], selected)

    control.layout(ctx, Rect(0.0, 0.0, 300.0, 38.0))
    @Expect(control.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 250.0, 12.0)))
    @Expect(selected.value, Int64(2))
}

@Test
func switchActivatesOnReleaseAndSupportsKeyboard(): Unit {
    let ctx = controlTestContext()
    let checked = State<Bool>(false)
    let control = Switch("Notifications", checked).key("notifications")
    control.layout(ctx, Rect(0.0, 0.0, 180.0, 38.0))

    @Expect(control.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 12.0, 12.0)))
    @Expect(!checked.value)
    @Expect(control.handle(ctx, UiEvent.MouseUp(MouseButton.Left, 12.0, 12.0)))
    @Expect(checked.value)
    @Expect(control.handle(ctx, UiEvent.KeyDown(Key.Space, false)))
    @Expect(!checked.value)
}

@Test
func radioButtonsShareOneSelectionState(): Unit {
    let ctx = controlTestContext()
    let selected = State<Int64>(1)
    let control = RadioButton("Detailed", selected, 2)
    control.layout(ctx, Rect(0.0, 0.0, 180.0, 38.0))

    let _ = control.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 12.0, 12.0))
    let _ = control.handle(ctx, UiEvent.MouseUp(MouseButton.Left, 12.0, 12.0))

    @Expect(selected.value, Int64(2))
}

@Test
func pickerWrapsSelectionAndRespondsToArrowKeys(): Unit {
    let ctx = controlTestContext()
    let selected = State<Int64>(0)
    let picker = Picker(["Compact", "Comfortable", "Spacious"], selected, key: "density")
    picker.layout(ctx, Rect(0.0, 0.0, 190.0, 38.0))

    @Expect(picker.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 8.0, 12.0)))
    @Expect(selected.value, Int64(2))
    @Expect(picker.handle(ctx, UiEvent.KeyDown(Key.Right, false)))
    @Expect(selected.value, Int64(0))
}

@Test
func stepperClampsRangeWithoutIntegerOverflow(): Unit {
    let ctx = controlTestContext()
    let value = State<Int64>(9)
    let stepper = Stepper(value, key: "quantity").range(0, 10).step(3)
    stepper.layout(ctx, Rect(0.0, 0.0, 144.0, 38.0))

    @Expect(stepper.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 136.0, 12.0)))
    @Expect(value.value, Int64(10))
    @Expect(stepper.handle(ctx, UiEvent.KeyDown(Key.Left, false)))
    @Expect(value.value, Int64(7))
}

// A range pressed against the Int64 extremes must not overflow when stepping: the guard saturates
// at the type bound before clamping to the range, so `lowerBound + step` / `upperBound - step` are
// never evaluated into an over/underflow.
@Test
func stepperStepsAtInt64ExtremesWithoutOverflow(): Unit {
    let ctx = controlTestContext()

    // Range crammed against Int64.Max: pressing decrement saturates at Int64.Min then clamps to the
    // floor, rather than evaluating `lowerBound + step` (= Int64.Max + 3) into an overflow.
    let high = State<Int64>(Int64.Max)
    let highStepper = Stepper(high, key: "high", lower: Int64.Max - 2, upper: Int64.Max, step: 5)
    highStepper.layout(ctx, Rect(0.0, 0.0, 144.0, 38.0))
    @Expect(highStepper.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 18.0, 12.0)))
    @Expect(high.value, Int64.Max - 2)

    // Range crammed against Int64.Min: pressing increment saturates at Int64.Max then clamps to the
    // ceiling, rather than evaluating `upperBound - step` (= Int64.Min - 3) into an underflow.
    let low = State<Int64>(Int64.Min)
    let lowStepper = Stepper(low, key: "low", lower: Int64.Min, upper: Int64.Min + 2, step: 5)
    lowStepper.layout(ctx, Rect(0.0, 0.0, 144.0, 38.0))
    @Expect(lowStepper.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 126.0, 12.0)))
    @Expect(low.value, Int64.Min + 2)
}

@Test
func tabViewSelectsHeaderWithoutPages(): Unit {
    let ctx = controlTestContext()
    let selected = State<Int64>(0)
    let tabs = TabView(["First", "Second"], selected) {}

    tabs.layout(ctx, Rect(0.0, 0.0, 200.0, 120.0))
    @Expect(tabs.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 150.0, 12.0)))
    @Expect(selected.value, Int64(1))
}

@Test
func tabViewLaysOutIncomingPageOnSwitch(): Unit {
    let ctx = controlTestContext()
    let selected = State<Int64>(0)
    let second = ControlLayoutProbe()
    let tabs = TabView(["A", "B"], selected) {
        Spacer()
        emit(second)
    }

    tabs.layout(ctx, Rect(0.0, 0.0, 200.0, 150.0))
    @Expect(second.rect.h, Float32(0.0))

    @Expect(tabs.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 150.0, 12.0)))
    @Expect(selected.value, Int64(1))
    @Expect(second.rect.h > 0.0)
}

// Clicking a numeric column header sorts by value (not lexically); Home/End then select the
// smallest/largest row by that column, and the selection is stored as the original row index.
@Test
func tableSortsNumericColumnByValue(): Unit {
    let ctx = controlTestContext()
    let selected = State<Int64>(-1)
    let columns = [TableColumn("名称", 120.0), TableColumn("负载", 80.0, numeric: true)]
    // original indices — 0:"10", 1:"9", 2:"100"; numeric order is 9 < 10 < 100.
    let rows = [["B", "10"], ["A", "9"], ["C", "100"]]
    let table = Table(columns, rows, selected, key: "servers")
    table.layout(ctx, Rect(0.0, 0.0, 200.0, 200.0))

    @Expect(table.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 140.0, 10.0))) // sort by 负载, asc
    @Expect(table.handle(ctx, UiEvent.KeyDown(Key.Home, false)))
    @Expect(selected.value, Int64(1)) // smallest load "9" — lexical sort would pick "10" (index 0)
    @Expect(table.handle(ctx, UiEvent.KeyDown(Key.End, false)))
    @Expect(selected.value, Int64(2)) // largest load "100"

    @Expect(table.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 140.0, 10.0))) // toggle to desc
    @Expect(table.handle(ctx, UiEvent.KeyDown(Key.Home, false)))
    @Expect(selected.value, Int64(2)) // largest first
}

// A text sort reorders the display, but the selection follows its row (stored by original index),
// and Up/Down move through the sorted order.
@Test
func tableSelectionFollowsRowAcrossSort(): Unit {
    let ctx = controlTestContext()
    let selected = State<Int64>(0) // original row 0 = "B"
    let columns = [TableColumn("名称", 120.0)]
    let rows = [["B"], ["A"], ["C"]]
    let table = Table(columns, rows, selected, key: "names")
    table.layout(ctx, Rect(0.0, 0.0, 130.0, 200.0))

    @Expect(table.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 40.0, 10.0))) // sort asc: A,B,C
    @Expect(selected.value, Int64(0)) // still the "B" row, now at display position 1

    @Expect(table.handle(ctx, UiEvent.KeyDown(Key.Down, false)))
    @Expect(selected.value, Int64(2)) // "C"
    @Expect(table.handle(ctx, UiEvent.KeyDown(Key.Up, false)))
    @Expect(selected.value, Int64(0)) // back to "B"
    @Expect(table.handle(ctx, UiEvent.KeyDown(Key.Up, false)))
    @Expect(selected.value, Int64(1)) // "A" at the top
}

// A press on a body row selects the row shown there, mapping the display position back through
// the active sort to the original index.
@Test
func tableRowClickSelectsThroughSort(): Unit {
    let ctx = controlTestContext()
    let selected = State<Int64>(-1)
    let columns = [TableColumn("名称", 120.0)]
    let rows = [["B"], ["A"], ["C"]]
    let table = Table(columns, rows, selected, key: "names2")
    table.layout(ctx, Rect(0.0, 0.0, 130.0, 200.0))

    @Expect(table.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 40.0, 10.0))) // sort asc: A,B,C
    // Body starts at y=32 with 28px rows; display pos 0 = "A" (original index 1).
    @Expect(table.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 40.0, 40.0)))
    @Expect(selected.value, Int64(1))
    // Display pos 2 = "C" (original index 2).
    @Expect(table.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 40.0, 100.0)))
    @Expect(selected.value, Int64(2))
}

// A selection moved from outside the list (e.g. app-level key routing) must still scroll into
// view on the next draw, and a redraw with unchanged selection must not move the scroll (no bounce).
@Test
func listViewRevealsExternallyChangedSelectionOnDraw(): Unit {
    let ctx = controlTestContext()
    let selected = State<Int64>(0)
    let scroll = State<Float32>(0.0)
    let list = ListView(["A", "B", "C", "D", "E", "F", "G", "H"], selected, scroll: Some(scroll))
    list.layout(ctx, Rect(0.0, 0.0, 180.0, 90.0))

    list.draw(ctx) // reveals the initial selection (0) — stays at the top
    @Expect(scroll.value, Float32(0.0))

    selected.value = 7 // app moved it directly, bypassing the list's own key handling
    list.draw(ctx)
    @Expect(scroll.value > Float32(0.0)) // last row scrolled into view

    let held = scroll.value
    list.draw(ctx) // unchanged selection — must not re-scroll
    @Expect(scroll.value, held)
}

// From no selection (-1), Down must land on the first row, not skip to the second.
@Test
func tableDownFromNoSelectionSelectsFirstRow(): Unit {
    let ctx = controlTestContext()
    let selected = State<Int64>(-1)
    let columns = [TableColumn("名称", 120.0)]
    let rows = [["B"], ["A"], ["C"]]
    let table = Table(columns, rows, selected, key: "names3")
    table.layout(ctx, Rect(0.0, 0.0, 130.0, 200.0))
    ctx.focus("names3")

    @Expect(table.handle(ctx, UiEvent.KeyDown(Key.Down, false)))
    @Expect(selected.value, Int64(0)) // unsorted display position 0 = original index 0
}

// The sort-order cache must still reflect live cell edits: after sorting, editing a cell so a
// different row sorts first must change the order on the next frame. This guards the cache's
// invalidation — a stale cache would keep the old order and select the wrong row.
@Test
func tableSortCacheReflectsCellEdits(): Unit {
    let ctx = controlTestContext()
    let selected = State<Int64>(-1)
    let columns = [TableColumn("名称", 120.0)]
    let rows = [["B"], ["A"], ["C"]]
    let table = Table(columns, rows, selected, key: "editcache")
    table.layout(ctx, Rect(0.0, 0.0, 130.0, 200.0))

    // Sort ascending: A(1), B(0), C(2). Home selects the first, "A" = original index 1.
    @Expect(table.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 40.0, 10.0)))
    @Expect(table.handle(ctx, UiEvent.KeyDown(Key.Home, false)))
    @Expect(selected.value, Int64(1))

    // Edit the data in place so "A" becomes "Z"; ascending order is now B(0), C(2), Z(1).
    rows[1][0] = "Z"
    @Expect(table.handle(ctx, UiEvent.KeyDown(Key.Home, false)))
    @Expect(selected.value, Int64(0)) // first is now "B" = original index 0, not the stale "A" (1)

    // And End reflects the edit too: largest is now "Z" = original index 1.
    @Expect(table.handle(ctx, UiEvent.KeyDown(Key.End, false)))
    @Expect(selected.value, Int64(1))
}

// A row-count change must invalidate the cached order rather than index past the new bounds.
@Test
func tableSortCacheHandlesRowCountChange(): Unit {
    let ctx = controlTestContext()
    let selected = State<Int64>(-1)
    let columns = [TableColumn("名称", 120.0)]
    let rows = [["B"], ["A"], ["C"], ["D"]]
    let table = Table(columns, rows, selected, key: "countcache")
    table.layout(ctx, Rect(0.0, 0.0, 130.0, 200.0))

    @Expect(table.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 40.0, 10.0))) // sort asc: A,B,C,D
    @Expect(table.handle(ctx, UiEvent.KeyDown(Key.End, false)))
    @Expect(selected.value, Int64(3)) // "D" = original index 3

    // A shorter dataset through the same table id: End must land within the new bounds.
    let shorter = [["B"], ["A"]]
    let table2 = Table(columns, shorter, selected, key: "countcache")
    table2.layout(ctx, Rect(0.0, 0.0, 130.0, 200.0))
    @Expect(table2.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 40.0, 10.0)))
    @Expect(table2.handle(ctx, UiEvent.KeyDown(Key.End, false)))
    @Expect(selected.value, Int64(0)) // sorted A,B -> last is "B" = original index 0
}

struct TestServer {
    let name: String
    let load: Int64

    init(name: String, load: Int64) {
        this.name = name
        this.load = load
    }
}

// `Table.of` builds a table from typed data via per-column value extractors; sorting and selection
// then work exactly as for the raw string form, so no hand-built string matrix is needed.
@Test
func tableOfSortsThroughTypedExtractors(): Unit {
    let ctx = controlTestContext()
    let selected = State<Int64>(-1)
    let servers = [TestServer("B", 10), TestServer("A", 9), TestServer("C", 100)]
    let table = Table.of<TestServer>(servers, [
        DataColumn<TestServer>("名称", 120.0) {s => s.name},
        DataColumn<TestServer>("负载", 80.0, numeric: true) {s => "${s.load}"}
    ], selected, key: "of.table")
    table.layout(ctx, Rect(0.0, 0.0, 220.0, 200.0))

    // Sort by the numeric 负载 column (x in [120, 200)); Home selects the smallest load.
    @Expect(table.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 140.0, 10.0)))
    @Expect(table.handle(ctx, UiEvent.KeyDown(Key.Home, false)))
    @Expect(selected.value, Int64(1)) // "A"/load 9 = original index 1 (numeric, not lexical)
    @Expect(table.handle(ctx, UiEvent.KeyDown(Key.End, false)))
    @Expect(selected.value, Int64(2)) // "C"/load 100 = original index 2
}

// ListView/SegmentedControl/TabView now accept an optional explicit id (previously auto-only, so
// their identity was unaddressable); when given, it becomes the control's focus/state identity.
@Test
func listViewAcceptsOptionalExplicitId(): Unit {
    let ctx = controlTestContext()
    let sel = State<Int64>(-1)
    let list = ListView(["a", "b", "c"], sel, key: "servers")
    list.layout(ctx, Rect(0.0, 0.0, 120.0, 100.0))
    match (list.focusableId()) {
        case Some(fid) => @Expect(fid, "servers")
        case None => @Expect(false, true)
    }
}

// Stepper now accepts range/step in the constructor (aligning with Slider/ProgressBar), clamping the
// initial value into range at construction just as the chained range() does.
@Test
func stepperConstructorBoundsClampInitialValue(): Unit {
    let ctx = controlTestContext()
    let value = State<Int64>(200) // above the ctor upper bound
    let stepper = Stepper(value, key: "age", lower: 0, upper: 100, step: 5)
    stepper.layout(ctx, Rect(0.0, 0.0, 120.0, 32.0))
    @Expect(value.value, Int64(100)) // clamped into [0, 100] by the constructor
}

private class ControlLayoutProbe <: Widget {
    var rect = Rect.zero()

    public func measure(_: UiContext, _: Size): Size {
        Size.zero()
    }

    public func layout(_: UiContext, assigned: Rect): Unit {
        rect = assigned
    }

    public func draw(_: UiContext): Unit {}

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }
}
