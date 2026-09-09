package cui_desktop_lifecycle_test

import std.fs.{Directory, File, exists}
import cui.{Color, FontStyle, Key, MouseButton, LengthInsets, LengthUnits, Rect, SdlWindow, State,
    SurfaceStyle, TextAlign, TextArea, TextClipboard, TextField, TextInputStyle, TextStyle, UiEvent, WidgetTestHost, WindowSpec}

private let EDITOR_OUTPUT = "../../../target/dev/fixtures/desktop_lifecycle/"
private let EDITOR_INK = Color.rgb(30, 60, 90)
private let EDITOR_PAPER = Color.rgb(255, 255, 255)

func verifyEditorStyle(): Bool {
    if (!exists(EDITOR_OUTPUT)) { Directory.create(EDITOR_OUTPUT, recursive: true) }
    for (sampling in [Int32(1), Int32(2)]) {
        try (window = SdlWindow(WindowSpec("Editor style E2E", 420, 240, supersample: sampling), hidden: true)) {
            let host = WidgetTestHost(renderer: window.renderer, fontScale: 1.25)
            try {
                if (!verifyEditorFieldPixels(window, host, sampling)) { println("editor field pixels failed: ${sampling}"); return false }
                if (!verifySelectedEditorPixels(window, host, sampling)) { println("editor selection pixels failed: ${sampling}"); return false }
                if (!verifyEditorWrapCommands(window, host, sampling)) { println("editor wrap commands failed: ${sampling}"); return false }
            } finally { host.reset() }
        }
    }
    true
}

// Compare committed input and placeholder against independently drawn text, including colored glyphs.
private func verifyEditorFieldPixels(window: SdlWindow, host: WidgetTestHost, sampling: Int32): Bool {
    let ctx = host.context; let renderer = window.renderer
    let value = State<String>("AB"); let cursor = State<Int64>(1); let anchor = State<Int64>(1)
    let style = TextInputStyle(lineHeight: 56.fp, padding: LengthInsets(16.vp), alignment: TextAlign.Center,
        textColor: EDITOR_INK, placeholderColor: EDITOR_INK, surface: SurfaceStyle(EDITOR_PAPER))
    let field = TextField(value, key: "emoji-input", cursor: cursor, anchor: anchor).style(style).placeholder("🎉 Ready")
    let bounds = Rect(0.0, 0.0, 420.0, 100.0)
    ctx.withTextStyle(TextStyle(fontSize: 32.fp)) {
        var ok = true
        renderer.prepareTextLayout(420.0, 240.0)
        field.layout(ctx, bounds); ctx.focus("emoji-input")
        ok = field.handle(ctx, UiEvent.TextEditing("🎉", 0, 1)) && ok
        renderer.beginScene(420.0, 240.0, EDITOR_PAPER)
        field.draw(ctx)
        if (value.value != "AB" || ctx.textInputAnchorRect().isNone()) { ok = false }
        renderer.captureBmp(EDITOR_OUTPUT + "editor-preedit-${sampling}.bmp")
        renderer.endScene()
        ok = field.handle(ctx, UiEvent.TextInput("🎉")) && ok
        if (value.value != "A🎉B") { ok = false }
        for (empty in [false, true]) {
            if (empty) { value.value = ""; field.selectRange(0, 0) }
            ctx.focus("other")
            let suffix = "${sampling}-${empty}"
            renderer.beginScene(420.0, 240.0, EDITOR_PAPER)
            field.draw(ctx)
            renderer.captureBmp(EDITOR_OUTPUT + "editor-field-${suffix}.bmp")
            renderer.endScene()
            renderer.beginScene(420.0, 240.0, EDITOR_PAPER)
            let text = if (empty) { "🎉 Ready" } else { "A🎉B" }
            let x = 16.0 + (388.0 - 1.5 - ctx.textWidth(text)) / 2.0
            ctx.text(text, x, 50.0 - ctx.textHeight() / 2.0, EDITOR_INK)
            renderer.captureBmp(EDITOR_OUTPUT + "editor-reference-${suffix}.bmp")
            renderer.endScene()
            if (File.readFrom(EDITOR_OUTPUT + "editor-field-${suffix}.bmp") !=
                File.readFrom(EDITOR_OUTPUT + "editor-reference-${suffix}.bmp")) { ok = false }
        }
        ok
    }
}

private func verifyEditorWrapCommands(window: SdlWindow, host: WidgetTestHost, sampling: Int32): Bool {
    let body = State<String>("一行中文 mixed text 🎉 👩🏽‍💻 e\u{0301} 后面还有很长的文字用于验证自动换行和复制。\n尾行")
    let clipboardValue = State<String>("")
    let clipboard = TextClipboard(read: {=> clipboardValue.value}, write: {value => clipboardValue.value = value})
    let wrap = State<Bool>(true); let readonly = State<Bool>(false)
    let cursor = State<Int64>(body.value.size); let anchor = State<Int64>(body.value.size)
    let holder = EditorAreaHolder()
    let bounds = Rect(0.0, 0.0, 420.0, 240.0)
    let view: () -> Unit = {=>
        let area = TextArea(body, key: "styled-wrap", editable: !readonly.value, clipboard: clipboard, cursor: cursor, anchor: anchor)
            .wrap(value: wrap.value).placeholder("输入多行正文 🎉")
            .style(TextInputStyle(lineHeight: 42.fp, padding: LengthInsets(18.vp),
                selectedTextColor: Color.rgb(255, 255, 255), selectionColor: Color.rgb(40, 70, 160)))
        area.textStyle(TextStyle(fontSize: 24.fp, fontStyle: FontStyle(italic: true)))
        holder.area = Some(area)
    }
    let _ = host.frame(bounds, body: view)
    host.context.focus("styled-wrap")
    let area = holder.area.getOrThrow(); let original = body.value
    area.selectAll()
    if (!area.copy() || clipboardValue.value != original) { return false }
    let _ = host.frame(bounds, body: view)
    window.renderer.captureBmp(EDITOR_OUTPUT + "editor-wrap-${sampling}.bmp")
    if (!holder.area.getOrThrow().cut() || !body.value.isEmpty()) { return false }
    if (!holder.area.getOrThrow().paste() || body.value != original) { return false }
    holder.area.getOrThrow().undo(); if (!body.value.isEmpty()) { return false }
    holder.area.getOrThrow().undo(); if (body.value != original) { return false }
    let _ = host.frame(bounds, events: [UiEvent.KeyDown(Key.Home, false), UiEvent.KeyDown(Key.PageUp, false)], body: view)
    let caret = host.context.textInputAnchorRect().getOrThrow()
    if (caret.x < 18.0 || caret.y < 18.0 || caret.bottom() > 222.0) { return false }
    wrap.value = false
    let _ = host.frame(bounds, body: view)
    if (body.value != original) { return false }
    let firstLineEnd = body.value.size - "\n尾行".size
    holder.area.getOrThrow().selectRange(firstLineEnd, firstLineEnd)
    let _ = host.frame(bounds, body: view)
    wrap.value = true
    let _ = host.frame(bounds, events: [UiEvent.MouseDown(MouseButton.Left, 18.0, 20.0),
        UiEvent.MouseUp(MouseButton.Left, 18.0, 20.0)], body: view)
    if (cursor.value != 0) { return false }
    readonly.value = true
    let _ = host.frame(bounds, events: [UiEvent.TextInput("wrong")], body: view)
    body.value == original && host.context.textInputAnchorRect().isNone()
}

private class EditorAreaHolder { var area: ?TextArea = None }

// A selected foreground must replace normal ink, not alpha-blend a second glyph over it.
private func verifySelectedEditorPixels(window: SdlWindow, host: WidgetTestHost, sampling: Int32): Bool {
    let ctx = host.context; let renderer = window.renderer
    let text = "AV office 🎉"
    let foreground = Color.rgba(230, 240, 255, 150)
    let selection = Color.rgb(45, 70, 140)
    let field = TextField(State<String>(text), key: "selected-ink")
        .style(TextInputStyle(padding: LengthInsets(16.vp), textColor: EDITOR_INK,
            inactiveSelectionColor: selection, selectedTextColor: foreground, surface: SurfaceStyle(EDITOR_PAPER)))
    let frame = Rect(0.0, 0.0, 420.0, 100.0)
    ctx.withTextStyle(TextStyle(fontSize: 24.fp)) {
        renderer.prepareTextLayout(420.0, 240.0)
        ctx.focus("other"); field.layout(ctx, frame); field.selectAll()
        renderer.beginScene(420.0, 240.0, EDITOR_PAPER)
        field.draw(ctx)
        renderer.captureBmp(EDITOR_OUTPUT + "editor-selection-${sampling}.bmp")
        renderer.endScene()
        renderer.beginScene(420.0, 240.0, EDITOR_PAPER)
        let y = 50.0 - ctx.textHeight() / 2.0
        let selected = Rect(16.0, y, ctx.textWidth(text), ctx.textHeight())
        renderer.fill(selected, selection)
        renderer.pushClip(selected)
        try { ctx.text(text, 16.0, y, foreground) } finally { renderer.popClip() }
        renderer.captureBmp(EDITOR_OUTPUT + "editor-selection-reference-${sampling}.bmp")
        renderer.endScene()
        File.readFrom(EDITOR_OUTPUT + "editor-selection-${sampling}.bmp") ==
            File.readFrom(EDITOR_OUTPUT + "editor-selection-reference-${sampling}.bmp")
    }
}
