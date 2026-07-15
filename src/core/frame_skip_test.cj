package cui.core

import sdl.{FrameInfo, Rect, UiEvent}

/*
 * Dirty-frame skipping (档 0) verification. The desktop loop renders a frame only when there is input,
 * a state change, or a continuous-frame request; these tests cover the load-bearing signals that gate
 * that decision — the state-write generation counter and each animation's requestFrame — so the loop
 * integration (which needs a window and is validated interactively) rests on unit-checked pieces.
 */

@Test
func stateWriteBumpsGlobalGeneration(): Unit {
    let s = State<Int64>(0)
    let before = currentStateGeneration()
    s.value = 5
    // Any write moves the counter off the snapshot; this holds even if another test writes concurrently
    // because the counter only ever advances.
    @Expect(currentStateGeneration() != before)
}

@Test
func frameHandlerRequestsContinuousFrame(): Unit {
    let ctx = testContext()
    let handler = FrameHandler(onFrame: {_ => ()}) {
        Label("x")
    }
    let _ = ctx.takeFrameRequest() // clear any prior request
    let _ = handler.handle(ctx, UiEvent.Frame(FrameInfo(UInt64(0), UInt64(0))))
    @Expect(ctx.takeFrameRequest())
}

@Test
func tooltipRequestsFramesWhileRevealPending(): Unit {
    let ctx = testContext()
    ctx.frame = FrameInfo(UInt64(100), UInt64(0))
    let tip = Tooltip(text: "提示") {
        Label("x")
    }
    tip.layout(ctx, Rect(0.0, 0.0, 50.0, 30.0))
    ctx.mouseX = 25.0
    ctx.mouseY = 15.0

    let _ = ctx.takeFrameRequest()
    tip.draw(ctx) // hover starts (records the start time)
    ctx.frame = FrameInfo(UInt64(200), UInt64(0)) // 100ms into the 500ms delay
    let _ = ctx.takeFrameRequest()
    tip.draw(ctx)
    @Expect(ctx.takeFrameRequest()) // still counting down -> keeps frames coming

    // Pointer leaves: nothing pending, so no continuous frame is requested.
    ctx.mouseX = 500.0
    let _ = ctx.takeFrameRequest()
    tip.draw(ctx)
    @Expect(!ctx.takeFrameRequest())
}

@Test
func staticContentRequestsNoFrame(): Unit {
    // A plain label neither writes state nor animates, so drawing it asks for no further frame — the
    // condition under which the loop is allowed to idle.
    let ctx = testContext()
    let label = Label("static")
    label.layout(ctx, Rect(0.0, 0.0, 100.0, 30.0))
    let _ = ctx.takeFrameRequest()
    label.draw(ctx)
    @Expect(!ctx.takeFrameRequest())
}
