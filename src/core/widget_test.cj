/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package cui.core

import sdl.{Color, FrameInfo, IconName, Insets, MouseButton, Rect, Renderer, Size, SurfaceStyle, UiEvent}

internal func testContext(): UiContext {
    UiContext(Renderer.headless(), Theme.light())
}

@Test
func uiContextTracksFocusAndDrag(): Unit {
    let ctx = testContext()

    ctx.focus("input")
    ctx.beginDrag("slider")

    @Expect(ctx.hasFocus("input"))
    @Expect(ctx.isDragging("slider"))

    ctx.clearDrag()
    @Expect(!ctx.isDragging("slider"))
}

@Test
func frameHandlerReceivesFrameInfo(): Unit {
    let ctx = testContext()
    let count = State<Int64>(0)
    let handler = FrameHandler(onFrame: {
        info => if (info.deltaMs == UInt64(16)) {
            count.value += 1
        }
    }) {
        Spacer()
    }

    @Expect(!handler.handle(ctx, UiEvent.Frame(FrameInfo(UInt64(100), UInt64(16)))))
    @Expect(count.value, Int64(1))
}

@Test
func stackBroadcastsFrameEventsToAllChildren(): Unit {
    let ctx = testContext()
    let first = State<Int64>(0)
    let second = State<Int64>(0)
    let stack = VStack {
        FrameHandler(onFrame: {_ => first.value += 1}) {
            Spacer()
        }
        FrameHandler(onFrame: {_ => second.value += 1}) {
            Spacer()
        }
    }

    @Expect(!stack.handle(ctx, UiEvent.Frame(FrameInfo(UInt64(100), UInt64(16)))))
    @Expect(first.value, Int64(1))
    @Expect(second.value, Int64(1))
}

@Test
func stackBuildersSupportTrailingLambdaSyntax(): Unit {
    let ctx = testContext()
    let pressed = State<Bool>(false)
    let view = VStack(padding: Insets(2.0)) {
        Label("Title")
        HStack(spacing: 0.0) {
            Button("Run", {=> pressed.value = true})
            Spacer()
        }
    }

    view.layout(ctx, Rect(0.0, 0.0, 240.0, 120.0))

    @Expect(view.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 10.0, 44.0)))
    @Expect(pressed.value)
}

@Test
func panelSupportsStyledTrailingLambdaContent(): Unit {
    let ctx = testContext()
    let pressed = State<Bool>(false)
    let panel = Panel(
        padding: Insets(6.0),
        style: Some(SurfaceStyle(Color.rgb(250, 250, 250), border: Color.rgb(120, 130, 140), radius: 10.0))
    ) {
        Button("Go", {=> pressed.value = true})
    }

    panel.layout(ctx, Rect(0.0, 0.0, 120.0, 60.0))

    @Expect(panel.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 12.0, 12.0)))
    @Expect(pressed.value)
}

@Test
func iconButtonSupportsTrailingLambdaAction(): Unit {
    let ctx = testContext()
    let pressed = State<Bool>(false)
    let button = IconButton(IconName.Save, label: Some("Save"), role: ButtonRole.Primary) {
        => pressed.value = true
    }

    button.layout(ctx, Rect(0.0, 0.0, 100.0, 34.0))

    @Expect(button.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 12.0, 12.0)))
    @Expect(pressed.value)
}

@Test
func scrollWheelClampsOffsetWithinContent(): Unit {
    @Expect(scrollOffsetAfterWheel(0.0, -1.0, 240.0, 96.0), Float32(72.0))
    @Expect(scrollOffsetAfterWheel(140.0, -1.0, 240.0, 96.0), Float32(144.0))
    @Expect(scrollOffsetAfterWheel(20.0, 1.0, 240.0, 96.0), Float32(0.0))
}

@Test
func eventHandlerConsumesMatchingEvents(): Unit {
    let ctx = testContext()
    let handler = EventHandler(onEvent: {
        event => match (event) {
            case UiEvent.DropFile(path, _, _) => path == "note.txt"
            case _ => false
        }
    }) {
        Spacer()
    }

    @Expect(handler.handle(ctx, UiEvent.DropFile("note.txt", 0.0, 0.0)))
    @Expect(!handler.handle(ctx, UiEvent.DropText("text", 0.0, 0.0)))
}

// Records the rect a stack hands it, so layout math can be asserted directly.
class LayoutProbe <: Widget {
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

@Test
func flexibleWeightSpansColumnsExactly(): Unit {
    let ctx = testContext()
    let zero = LayoutProbe()
    let dot = LayoutProbe()
    let equals = LayoutProbe()
    let row = HStack(spacing: 10.0) {
        Flexible(weight: 2.0) {
            emit(zero)
        }
        Flexible {
            emit(dot)
        }
        Flexible {
            emit(equals)
        }
    }

    row.layout(ctx, Rect(0.0, 0.0, 430.0, 40.0))

    // unit = (430 - two gaps - one absorbed gap) / 4 weights = 100; the weight-2 cell
    // spans two units plus the gap between them, exactly two single columns wide.
    @Expect(zero.rect.w, Float32(210.0))
    @Expect(dot.rect.x, Float32(220.0))
    @Expect(dot.rect.w, Float32(100.0))
    @Expect(equals.rect.x, Float32(330.0))
}

@Test
func flexibleWeightRowsAlignWithUniformRows(): Unit {
    let ctx = testContext()
    let third = LayoutProbe()
    let uniform = HStack(spacing: 10.0) {
        Flexible {
            Spacer()
        }
        Flexible {
            Spacer()
        }
        Flexible {
            emit(third)
        }
        Flexible {
            Spacer()
        }
    }
    let dot = LayoutProbe()
    let weighted = HStack(spacing: 10.0) {
        Flexible(weight: 2.0) {
            Spacer()
        }
        Flexible {
            emit(dot)
        }
        Flexible {
            Spacer()
        }
    }

    uniform.layout(ctx, Rect(0.0, 0.0, 430.0, 40.0))
    weighted.layout(ctx, Rect(0.0, 0.0, 430.0, 40.0))

    // The cell after a weight-2 span starts exactly where the third uniform column does.
    @Expect(dot.rect.x, third.rect.x)
    @Expect(dot.rect.w, third.rect.w)
}
