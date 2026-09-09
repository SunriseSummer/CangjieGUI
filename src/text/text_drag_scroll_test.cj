package cui.text

import sdl.{FrameInfo, Rect, Renderer}
import cui.core.{Theme, UiContext}

@Test
func outsideDragAdvancesWithoutMouseMovesAndStopsAtBounds(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    ctx.focus("drag"); ctx.beginDrag("drag"); ctx.leftMouseDown = true
    let edit = TextEditState("one\ntwo\nthree\nfour\nfive\nsix\nseven\neight")
    edit.moveTo(0)
    let view = TextEditorView(ctx, Rect(0.0, 0.0, 120.0, 60.0), TextEditorDisplay(ctx, "drag", edit, false),
        TextEditorLayoutCache(), TextEditorViewState(TextInputStyle(), multiline: true))
    let drag = TextDragScroll()
    drag.update(ctx, view.viewport, 25.0, 90.0, multiline: true, wrap: false)
    @Expect(drag.active.value)
    let _ = ctx.takeFrameSchedule()
    ctx.frame = FrameInfo(UInt64(32), UInt64(32))
    @Expect(drag.step(ctx, "drag", view))
    let first = view.scroll
    ctx.frame = FrameInfo(UInt64(64), UInt64(32))
    @Expect(drag.step(ctx, "drag", view))
    @Expect(view.scroll > first)
    for (tick in 3..200) {
        ctx.frame = FrameInfo(UInt64(tick * 32), UInt64(32))
        let _ = ctx.takeFrameSchedule()
        let _ = drag.step(ctx, "drag", view)
    }
    @Expect(!drag.active.value)
    @Expect(!ctx.takeFrameSchedule().hasPending())
    @Expect(view.scroll, view.contentHeight() - view.viewport.h)
    drag.update(ctx, view.viewport, 25.0, -30.0, multiline: true, wrap: false)
    ctx.setTextWindowActive(value: false)
    @Expect(!drag.step(ctx, "drag", view))
    @Expect(!drag.active.value)
}

@Test
func horizontalDragClampsSpeedAndRejectsInvalidPointers(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    ctx.focus("drag"); ctx.beginDrag("drag"); ctx.leftMouseDown = true
    let edit = TextEditState("abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyz")
    let view = TextEditorView(ctx, Rect(0.0, 0.0, 100.0, 60.0), TextEditorDisplay(ctx, "drag", edit, true),
        TextEditorLayoutCache(), TextEditorViewState(TextInputStyle(), multiline: false))
    let drag = TextDragScroll()
    drag.update(ctx, view.viewport, 10000.0, 30.0, multiline: false, wrap: false)
    ctx.frame = FrameInfo(UInt64(10000), UInt64(10000))
    @Expect(drag.step(ctx, "drag", view))
    @Expect(view.xShift <= 57.6)
    ctx.leftMouseDown = false
    @Expect(!drag.step(ctx, "drag", view))
    @Expect(!drag.active.value)
    drag.update(ctx, view.viewport, Float32.Inf, 30.0, multiline: false, wrap: false)
    @Expect(!drag.active.value)
    drag.update(ctx, view.viewport, 120.0, 30.0, multiline: true, wrap: true)
    @Expect(!drag.active.value)
}
