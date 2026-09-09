package cui.text

import sdl.{FrameInfo, Rect, Renderer}
import cui.core.{FrameScheduler, State, Theme, UiContext, withFrameScheduler}

@Test
func stableEditorPaintDoesNotInvalidateObservableState(): Unit {
    let scheduler = FrameScheduler()
    withFrameScheduler(scheduler) {
        let ctx = UiContext(Renderer.headless(), Theme.light())
        let area = TextArea(State<String>("one\ntwo"), key: "stable")
        area.layout(ctx, Rect(0.0, 0.0, 300.0, 120.0))
        ctx.focus("stable")
        area.draw(ctx)
        let generation = scheduler.generation
        for (tick in 1..5) {
            ctx.frame = FrameInfo(UInt64(tick * 530), UInt64(530))
            area.draw(ctx)
        }
        @Expect(scheduler.generation, generation)
    }
}

@Test
func selectedOrComposingEditorDoesNotScheduleInvisibleBlinkWork(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let body = State<String>("alpha\nbeta")
    let area = TextArea(body, key: "idle")
    area.layout(ctx, Rect(0.0, 0.0, 300.0, 120.0))
    ctx.focus("idle")
    area.selectAll()
    let _ = ctx.takeFrameSchedule()
    area.draw(ctx)
    @Expect(ctx.textInputAnchorRect().isSome())
    @Expect(!ctx.takeFrameSchedule().hasPending())
    area.selectRange(0, 0)
    ctx.setImeComposition("idle", "🎉", 0, 0)
    let _ = ctx.takeFrameSchedule()
    area.draw(ctx)
    @Expect(!ctx.takeFrameSchedule().hasPending())
}

@Test
func offscreenCaretDoesNotKeepIdleEditorAwake(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let area = TextArea(State<String>("a\nb\nc\nd\ne\nf"), key: "offscreen", cursor: State<Int64>(0),
        anchor: State<Int64>(0), scroll: State<Float32>(50.0))
    area.layout(ctx, Rect(0.0, 0.0, 120.0, 55.0))
    ctx.focus("offscreen")
    ctx.frame = FrameInfo(UInt64(1000), UInt64(0))
    let _ = ctx.takeFrameSchedule()
    area.draw(ctx)
    @Expect(ctx.textInputAnchorRect().isSome())
    @Expect(!ctx.takeFrameSchedule().hasPending())
}
