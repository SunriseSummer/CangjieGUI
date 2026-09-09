package cui.text

import sdl.{FrameInfo, Rect, Renderer}
import cui.core.{Length, LengthUnit, LengthUnits, TextStyle, Theme, UiContext}

private func qualityView(ctx: UiContext, edit: TextEditState, style!: TextInputStyle = TextInputStyle()): TextEditorView {
    TextEditorView(ctx, Rect(0.0, 0.0, 320.0, 220.0), TextEditorDisplay(ctx, "quality", edit, true),
        TextEditorLayoutCache(), TextEditorViewState(style, multiline: true))
}

@Test
func editorContentSelectionEndsAtTextAndKeepsEmptyBreaksVisible(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let edit = TextEditState("abc  \r\n\r\ndef")
    edit.selectAll()
    let view = qualityView(ctx, edit)
    @Expect(view.selectionRect(0).getOrThrow().right(), view.rowX(0) + ctx.textWidth("abc  "))
    @Expect(view.selectionRect(1).getOrThrow().w, view.caretWidth)
    @Expect(view.selectionRect(2).getOrThrow().right(), view.rowX(2) + ctx.textWidth("def"))
    let full = qualityView(ctx, edit, style: TextInputStyle(selectionWidth: TextSelectionWidth.Viewport))
    @Expect(full.selectionRect(0).getOrThrow().right(), full.viewport.right())
    edit.moveTo(1); edit.extendTo(2)
    let partial = qualityView(ctx, edit)
    @Expect(partial.selectionRect(0).getOrThrow().w, ctx.textWidth("b"))
    @Expect(partial.selectionRect(1).isNone())
}

@Test
func editorCaretHeightIsCenteredAndValidatesLengths(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let edit = TextEditState("abc")
    ctx.fontScale = 1.5
    ctx.withTextStyle(TextStyle(fontSize: 18.fp)) {
        let view = qualityView(ctx, edit, style: TextInputStyle(lineHeight: 50.fp, cursorHeight: 12.fp))
        let caret = view.caretRect()
        @Expect(caret.h, Float32(18.0))
        @Expect(caret.centerY(), view.textY(0) + view.textHeight / 2.0)
    }
    for (value in [Float32(0.0), Float32(-1.0), Float32.NaN, Float32.Inf]) {
        var failed = false
        try { let _ = TextInputStyle(cursorHeight: Length(value, LengthUnit.Vp)) }
        catch (_: IllegalArgumentException) { failed = true }
        @Expect(failed)
    }
}

@Test
func editorSteadyCaretAndFocusOrRevisionChangesResetBlink(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let edit = TextEditState("abc")
    let blink = TextCursorState()
    ctx.focus("quality")
    ctx.frame = FrameInfo(UInt64(800), UInt64(0))
    let _ = blink.observe(ctx, "quality", edit, true)
    @Expect(blink.epoch, UInt64(800))
    ctx.frame = FrameInfo(UInt64(850), UInt64(0))
    let _ = blink.observe(ctx, "quality", edit, true)
    @Expect(blink.epoch, UInt64(800))
    edit.text.value = "xyz"
    let _ = blink.observe(ctx, "quality", edit, true)
    @Expect(blink.epoch, UInt64(850))
    ctx.setTextWindowActive(value: false)
    let _ = blink.observe(ctx, "quality", edit, true)
    ctx.setTextWindowActive(value: true)
    ctx.frame = FrameInfo(UInt64(1900), UInt64(0))
    let _ = blink.observe(ctx, "quality", edit, true)
    @Expect(blink.epoch, UInt64(1900))
    let view = qualityView(ctx, edit, style: TextInputStyle(cursorBlinkIntervalMs: UInt64(0)))
    let _ = ctx.takeFrameSchedule()
    view.draw(Rect(0.0, 0.0, 320.0, 220.0), "quality", true, "", blink.epoch)
    @Expect(!ctx.takeFrameSchedule().hasPending())
}
