/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package cui.controls

import sdl.{Key, MouseButton, Rect, Renderer, Size, UiEvent}
import cui.core.{Spacer, State, Theme, UiContext, Widget, emit}

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
func sliderMouseAndKeyboardEventsUpdateState(): Unit {
    let ctx = controlTestContext()
    let value = State<Float32>(0.0)
    let slider = Slider("volume", value, lower: 0.0, upper: 10.0)

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
func segmentedControlSelectsClickedSegment(): Unit {
    let ctx = controlTestContext()
    let selected = State<Int64>(0)
    let control = SegmentedControl(["One", "Two", "Three"], selected)

    control.layout(ctx, Rect(0.0, 0.0, 300.0, 38.0))
    @Expect(control.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 250.0, 12.0)))
    @Expect(selected.value, Int64(2))
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
