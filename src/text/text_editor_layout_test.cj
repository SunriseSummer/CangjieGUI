package cui.text

import sdl.{Key, Rect, Renderer, UiEvent, Size}
import cui.core.{State, Theme, UiContext, TextStyle, TextAlign, Length, LengthUnit, LengthInsets, LengthUnits, graphemeByteBoundaries}

@Test
func editorStyleRejectsInvalidGeometry(): Unit {
    for (value in [Float32.NaN, Float32.Inf, Float32(-1.0), Float32(0.0)]) {
        var rejected = false
        try { let _ = TextInputStyle(lineHeight: Length(value, LengthUnit.Vp)) }
        catch (_: IllegalArgumentException) { rejected = true }
        @Expect(rejected)
        rejected = false
        try { let _ = TextInputStyle(cursorWidth: Length(value, LengthUnit.Vp)) }
        catch (_: IllegalArgumentException) { rejected = true }
        @Expect(rejected)
    }
    for (value in [Float32.NaN, Float32.Inf, Float32(-1.0)]) {
        var rejected = false
        try { let _ = TextInputStyle(padding: LengthInsets(Length(value, LengthUnit.Vp))) }
        catch (_: IllegalArgumentException) { rejected = true }
        @Expect(rejected)
    }
}

@Test
func editorStyleLineHeightInsetsAndAlignmentUseTheSameCaretGeometry(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let appearance = TextInputStyle(lineHeight: 44.vp,
        padding: LengthInsets(top: 10.vp, right: 20.vp, bottom: 14.vp, left: 30.vp), alignment: TextAlign.Center)
    let field = TextField(State<String>("ab"), key: "styled").style(appearance)
    @Expect(field.measure(ctx, Size(250.0, 100.0)).h, Float32(68.0))
    field.layout(ctx, Rect(0.0, 0.0, 250.0, 68.0)); ctx.focus("styled"); field.draw(ctx)
    let caret = ctx.textInputAnchorRect().getOrThrow()
    @Expect(caret.x, 30.0 + (200.0 - 1.5 - ctx.textWidth("ab")) / 2.0 + ctx.textWidth("ab"))
    @Expect(caret.y, 10.0 + (44.0 - ctx.textHeight()) / 2.0)
    ctx.withTextStyle(TextStyle(fontSize: 60.fp)) {
        @Expect(appearance.rowHeight(ctx, multiline: true) >= ctx.textHeight())
        @Expect(field.measure(ctx, Size(250.0, 200.0)).h >= ctx.textHeight() + 24.0)
    }
}

@Test
func editorWrappingPreservesEveryByteAndGraphemeAtEveryWidth(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let sample = "one  two\t中文 e\u{0301} 🎉👩🏽‍💻 🇨🇳\r\n\n尾行\n"
    let boundaries = graphemeByteBoundaries(sample)
    for (width in [Float32(1.0), Float32(25.0), Float32(80.0), Float32(160.0), Float32(1000.0)]) {
        let layout = TextEditorLayoutCache().get(ctx, sample, width, true, true)
        let reconstructed = StringBuilder()
        var next: Int64 = 0
        for (row in layout.rows) {
            @Expect(row.start, next)
            @Expect(boundaries.contains(row.start) && boundaries.contains(row.end) && boundaries.contains(row.next))
            reconstructed.append(sample[row.start..row.next]); next = row.next
        }
        @Expect(reconstructed.toString(), sample)
        @Expect(layout.rows[layout.rows.size - 1].start, sample.size)
    }
}

@Test
func editorLayoutInvalidatesForWidthFontAndWrapMode(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let cache = TextEditorLayoutCache()
    let sample = "abcdefgh"
    @Expect(cache.get(ctx, sample, ctx.textWidth("abcd"), true, true).rows.size, 2)
    @Expect(cache.get(ctx, sample, ctx.textWidth("ab"), true, true).rows.size, 4)
    @Expect(cache.get(ctx, sample, ctx.textWidth("ab"), false, true).rows.size, 1)
    ctx.withTextStyle(TextStyle(fontSize: 30.fp)) {
        @Expect(cache.get(ctx, sample, 33.0, true, true).rows.size, 4)
    }
    @Expect(cache.get(ctx, sample, 33.0, true, true).rows.size, 2)
}

@Test
func editorWrappedNavigationUsesVisualRowsAndKeepsSoftBoundaryAffinity(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let body = State<String>("abcdefghijkl")
    let cursor = State<Int64>(0); let anchor = State<Int64>(0)
    let area = TextArea(body, key: "wrap-nav", cursor: cursor, anchor: anchor).wrap().style(TextInputStyle(lineHeight: 32.vp))
    area.layout(ctx, Rect(0.0, 0.0, 50.5, 80.0)); ctx.focus("wrap-nav")
    @Expect(area.handle(ctx, UiEvent.KeyDown(Key.End, false)))
    @Expect(cursor.value, 4)
    area.draw(ctx)
    @Expect(ctx.textInputAnchorRect().getOrThrow().y, 8.0 + (32.0 - ctx.textHeight()) / 2.0)
    @Expect(area.handle(ctx, UiEvent.KeyDown(Key.Down, false)))
    @Expect(cursor.value, 8)
    @Expect(area.handle(ctx, UiEvent.KeyDown(Key.Home, false)))
    @Expect(cursor.value, 4)
    @Expect(area.handle(ctx, UiEvent.KeyDown(Key.PageDown, false)))
    @Expect(cursor.value, 12)
    @Expect(area.handle(ctx, UiEvent.KeyDown(Key.PageUp, false)))
    @Expect(cursor.value, 0)
    @Expect(body.value, "abcdefghijkl")
}

@Test
func editorWrappedHitTestingHonorsPaddingAlignmentAndLineHeight(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let edit = TextEditState("abcd\nef")
    let view = TextEditorView(ctx, Rect(10.0, 20.0, 180.0, 180.0), TextEditorDisplay(ctx, "hit", edit, true),
        TextEditorLayoutCache(), TextEditorViewState(TextInputStyle(lineHeight: 40.vp,
            padding: LengthInsets(20.vp), alignment: TextAlign.Trailing), multiline: true))
    let x = view.rowX(1) + ctx.textWidth("e")
    @Expect(view.hit(x, 20.0 + 20.0 + 40.0 + 2.0)[0], 6)
    @Expect(view.hit(-100.0, -100.0)[0], 0)
    @Expect(view.hit(1000.0, 1000.0)[0], edit.text.value.size)
}

@Test
func editorAreaRecoversNonFiniteScrollBeforeHitTesting(): Unit {
    for (invalid in [Float32.NaN, Float32.Inf, -Float32.Inf]) {
        let ctx = UiContext(Renderer.headless(), Theme.light())
        let scroll = State<Float32>(invalid)
        let area = TextArea(State<String>("a\nb\nc\nd\ne\nf"), key: "scroll", scroll: scroll)
        area.layout(ctx, Rect(0.0, 0.0, 160.0, 80.0))
        area.draw(ctx)
        @Expect(!scroll.value.isNaN() && !scroll.value.isInf() && scroll.value >= 0.0)
    }
}

@Test
func editorAreaWheelCanKeepCaretOutOfViewWithoutStoppingIme(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let cursor = State<Int64>(0); let anchor = State<Int64>(0); let scroll = State<Float32>(0.0)
    let area = TextArea(State<String>("a\nb\nc\nd\ne\nf\ng\nh"), key: "wheel", scroll: scroll, cursor: cursor, anchor: anchor)
    area.layout(ctx, Rect(0.0, 0.0, 160.0, 80.0)); ctx.focus("wheel"); area.draw(ctx)
    @Expect(area.handle(ctx, UiEvent.MouseWheel(0.0, -2.0, 20.0, 20.0)))
    let expected = scroll.value
    area.draw(ctx)
    @Expect(scroll.value, expected)
    @Expect(ctx.textInputAnchorRect().getOrThrow().y, Float32(8.0))
}

@Test
func editorSoftWrapDoesNotSplitEmojiDuringSelectionUndoOrDelete(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let value = State<String>("A👩🏽‍💻B🎉")
    let area = TextArea(value, key: "emoji-wrap").wrap()
    area.layout(ctx, Rect(0.0, 0.0, 60.0, 90.0)); ctx.focus("emoji-wrap")
    area.selectRange(1, 1 + "👩🏽‍💻".size)
    @Expect(area.replaceSelection("🇨🇳"))
    @Expect(value.value, "A🇨🇳B🎉")
    area.undo(); @Expect(value.value, "A👩🏽‍💻B🎉")
    area.redo(); @Expect(value.value, "A🇨🇳B🎉")
    @Expect(area.handle(ctx, UiEvent.KeyDown(Key.Backspace, false)))
    @Expect(value.value, "AB🎉")
}

@Test
func editorEnablingWrapDiscardsHorizontalShiftBeforeTheNextPointerEvent(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let edit = TextEditState("abcdefghijkl")
    let view = TextEditorView(ctx, Rect(0.0, 0.0, 50.5, 160.0), TextEditorDisplay(ctx, "wrap", edit, true),
        TextEditorLayoutCache(), TextEditorViewState(TextInputStyle(), multiline: true, wrap: true, xShift: 200.0))
    @Expect(view.hit(8.0, 10.0)[0], 0)
    @Expect(view.rowX(0), Float32(8.0))
}
