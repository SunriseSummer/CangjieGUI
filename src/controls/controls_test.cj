package cui.controls

import sdl.{Key, MouseButton, Rect, Renderer, Size, UiEvent}
import cui.core.{Button, Spacer, State, StateStore, Theme, UiContext, Widget, buildRoot, emit}

private func controlTestContext(): UiContext {
    UiContext(Renderer.headless(), Theme.light())
}

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

@Test
func stepperConstructorRejectsNonPositiveIncrement(): Unit {
    let value = State<Int64>(0)
    var rejected = false
    try {
        let _ = Stepper(value, key: "invalid-step", step: 0)
    } catch (error: IllegalArgumentException) {
        rejected = error.message == "Stepper step must be greater than zero"
    }
    @Expect(rejected)
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
