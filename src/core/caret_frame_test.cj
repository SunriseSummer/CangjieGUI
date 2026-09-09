package cui.core

import sdl.{Rect, Renderer}

@Test
func caretDamageScheduleDoesNotHideOtherTimersOrImmediateWork(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    ctx.requestCaretFrameAt(UInt64(530), Rect(10.0, 20.0, 4.0, 24.0))
    let caret = ctx.takeFrameSchedule()
    @Expect(!caret.isDue(UInt64(529)))
    @Expect(caret.isCaretOnlyDue(UInt64(530)))
    @Expect(caret.caretRegion().getOrThrow().w, Float32(4.0))
    ctx.requestCaretFrameAt(UInt64(530), Rect(10.0, 20.0, 4.0, 24.0))
    ctx.requestFrameAt(UInt64(800))
    let mixed = ctx.takeFrameSchedule()
    @Expect(mixed.deadlineMs.getOrThrow(), UInt64(530))
    @Expect(!mixed.isCaretOnlyDue(UInt64(530)))
    ctx.requestCaretFrameAt(UInt64(530), Rect(10.0, 20.0, 4.0, 24.0))
    ctx.requestFrame()
    @Expect(!ctx.takeFrameSchedule().isCaretOnlyDue(UInt64(530)))
    @Expect(!ctx.takeFrameSchedule().hasPending())
    ctx.requestCaretFrameAt(UInt64(530), Rect(Float32.NaN, 0.0, 2.0, 20.0))
    @Expect(!ctx.takeFrameSchedule().hasPending())
}
