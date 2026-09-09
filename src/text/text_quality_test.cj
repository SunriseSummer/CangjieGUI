package cui.text

import sdl.{Rect, Renderer, UiEvent}
import cui.core.{State, Theme, UiContext}

@Test
func textQualityEditingNeverSplitsCombiningOrEmojiClusters(): Unit {
    for (cluster in ["e\u{0301}", "👩🏽‍💻", "🇨🇳", "\r\n"]) {
        let edit = TextEditState("A" + cluster + "B")
        edit.moveTo(1 + cluster.size)
        edit.moveLeft()
        @Expect(edit.cursor.value, 1)
        edit.deleteForward()
        @Expect(edit.text.value, "AB")
    }
}

@Test
func textQualityReplacingSelectionPublishesOneTextChange(): Unit {
    let body = State<String>("abc")
    let calls = State<Int64>(0)
    let subscription = body.observe({_, _ => calls.value += 1})
    let edit = TextEditState(body)
    edit.moveTo(1)
    edit.extendTo(2)
    edit.insert("X")
    @Expect(body.value, "aXc")
    @Expect(calls.value, 1)
    subscription.close()
}

@Test
func textQualityExternalDocumentReplacementInvalidatesUndo(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let body = State<String>("old")
    let field = TextField(body, key: "external-document")
    field.layout(ctx, Rect(0.0, 0.0, 240.0, 40.0))
    ctx.focus("external-document")
    let _ = field.handle(ctx, UiEvent.TextInput("!"))
    body.value = "new document"
    field.undo()
    @Expect(body.value, "new document")
}

@Test
func textQualityTextInputUsesTheSameSingleLineNormalizationAsPaste(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let body = State<String>("")
    let field = TextField(body, key: "single-line")
    field.layout(ctx, Rect(0.0, 0.0, 240.0, 40.0))
    ctx.focus("single-line")
    let _ = field.handle(ctx, UiEvent.TextInput("one\r\ntwo\rthree"))
    @Expect(body.value, "one two three")
}

@Test
func textQualityLineCacheDoesNotReuseAnUnrelatedValueWithTheSameRevision(): Unit {
    let cache = TextEditorLayoutCache()
    let ctx = UiContext(Renderer.headless(), Theme.light())
    @Expect(cache.get(ctx, "old\nlines", 200.0, false, true).rows.size, 2)
    let lines = cache.get(ctx, "replacement", 200.0, false, true)
    @Expect(lines.rows.size, 1)
    @Expect(lines.text, "replacement")
}

@Test
func textQualityUnhandledTextInputDoesNotClearAnotherEditorsComposition(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    ctx.focus("composing")
    ctx.setImeComposition("composing", "拼", 0, 1)
    let field = TextField(State<String>(""), key: "unfocused")
    @Expect(!field.handle(ctx, UiEvent.TextInput("x")))
    @Expect(ctx.imeComposition("composing").isSome())
}
