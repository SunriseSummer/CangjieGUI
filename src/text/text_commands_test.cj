package cui.text

import sdl.{EventKeyModifiers, Key, MouseButton, Rect, Renderer, SdlException, UiEvent, UiEventMetadata}
import cui.core.{State, Theme, UiContext, Widget}

private func commandContext(): UiContext { UiContext(Renderer.headless(), Theme.light()) }

@Test
func textCommandsEmojiRepeatedPastePreservesWholeGraphemesAndHistory(): Unit {
    let sample = "👩🏽‍💻"
    let body = State<String>(sample)
    let clipboardText = State<String>("")
    let area = TextArea(body, clipboard: TextClipboard(read: {=> clipboardText.value}, write: {value => clipboardText.value = value}))
    area.selectRange(0, 4)
    @Expect(area.selectedText().isEmpty())
    area.selectAll()
    @Expect(area.copy())
    @Expect(clipboardText.value, sample)
    area.selectRange(sample.size, sample.size)
    var expected = sample
    for (_ in 0..4) {
        expected += sample
        @Expect(area.paste())
        @Expect(body.value, expected)
        area.selectRange(body.value.size - sample.size, body.value.size)
        @Expect(area.selectedText(), sample)
        area.selectRange(body.value.size, body.value.size)
    }
    area.undo()
    @Expect(body.value.size, sample.size * 4)
    area.redo()
    @Expect(body.value, expected)
    area.selectRange(sample.size, sample.size * 2)
    @Expect(area.cut())
    @Expect(clipboardText.value, sample)
    @Expect(body.value.size, sample.size * 4)
    area.undo()
    @Expect(body.value, expected)
}

private func commandKey(ctx: UiContext, widget: Widget, key: Key, modifiers: UInt16): Bool {
    ctx.beginEvent(UiEventMetadata(modifiers: EventKeyModifiers(raw: modifiers)))
    try { widget.handle(ctx, UiEvent.KeyDown(key, false)) } finally { ctx.endEvent() }
}

@Test
func textCommandsClipboardActionsPreserveSelectionAndUndoBoundaries(): Unit {
    let ctx = commandContext()
    let body = State<String>("abc")
    let clipboardText = State<String>("X\r\nY")
    let clipboard = TextClipboard(read: {=> clipboardText.value}, write: {value => clipboardText.value = value})
    let field = TextField(body, key: "commands", clipboard: clipboard)
    field.layout(ctx, Rect(0.0, 0.0, 240.0, 40.0))
    ctx.focus("commands")
    let _ = field.handle(ctx, UiEvent.TextInput("!"))
    field.selectRange(0, 3)
    ctx.clearFocus() // menu/toolbar commands work without stealing the editor's selection
    @Expect(field.paste())
    @Expect(body.value, "X Y!")
    field.undo()
    @Expect(body.value, "abc!")
    @Expect(field.selectedText(), "abc")
    field.undo()
    @Expect(body.value, "abc")
    field.redo()
    field.redo()
    @Expect(body.value, "X Y!")
    field.selectAll()
    @Expect(field.copy())
    @Expect(clipboardText.value, "X Y!")
    @Expect(field.cut())
    @Expect(body.value, "")
    field.undo()
    @Expect(body.value, "X Y!")
}

@Test
func textCommandsFailedOrEmptyClipboardNeverDestroysSelection(): Unit {
    let body = State<String>("keep")
    let failed = TextClipboard(read: {=> throw SdlException("read failed")},
        write: {_ => throw SdlException("write failed")})
    let field = TextField(body, clipboard: failed)
    field.selectAll()
    @Expect(!field.copy())
    @Expect(!field.cut())
    @Expect(!field.paste())
    @Expect(body.value, "keep")
    @Expect(field.selectedText(), "keep")
    @Expect(!field.canUndo())
    for (value in ["", "bad\u{0000}text"]) {
        let clip = TextClipboard(read: {=> value})
        let area = TextArea(body, clipboard: clip)
        area.selectAll()
        @Expect(!area.paste())
        @Expect(area.selectedText(), "keep")
    }
}

@Test
func textCommandsNulCopyIsRejectedBeforeCallingTheHost(): Unit {
    let writes = State<Int64>(0)
    let clipboard = TextClipboard(write: {_ => writes.value += 1})
    let body = State<String>("a\u{0000}b")
    let field = TextField(body, clipboard: clipboard)
    field.selectAll()
    @Expect(!field.cut())
    @Expect(writes.value, 0)
    @Expect(body.value, "a\u{0000}b")
}

@Test
func textCommandsReentrantClipboardWriteCannotCutANewerValue(): Unit {
    let body = State<String>("original")
    let clipboard = TextClipboard(write: {_ => body.value = "replacement"})
    let field = TextField(body, clipboard: clipboard)
    field.selectAll()
    @Expect(!field.cut())
    @Expect(body.value, "replacement")
}

@Test
func textCommandsWordNavigationAndShiftClickRespectGraphemes(): Unit {
    let ctx = commandContext()
    let body = State<String>("one e\u{0301} two")
    let cursor = State<Int64>(body.value.size)
    let field = TextField(body, key: "word", cursor: Some(cursor))
    field.layout(ctx, Rect(0.0, 0.0, 400.0, 40.0))
    ctx.focus("word")
    @Expect(commandKey(ctx, field, Key.Left, UInt16(0x40)))
    @Expect(cursor.value, body.value.size - 3)
    @Expect(commandKey(ctx, field, Key.Left, UInt16(0x41)))
    @Expect(field.selectedText(), "e\u{0301} ")
    @Expect(commandKey(ctx, field, Key.Backspace, UInt16(0x40)))
    @Expect(body.value, "one two")
    field.selectRange(0, 0)
    ctx.beginEvent(UiEventMetadata(modifiers: EventKeyModifiers(raw: UInt16(1))))
    try { let _ = field.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 8.0 + 24.75, 20.0)) }
    finally { ctx.endEvent() }
    @Expect(field.selectedText(), "one")
}

@Test
func textCommandsImeKeepsCommittedTextUntilOneCommit(): Unit {
    let ctx = commandContext()
    let body = State<String>("abc")
    let field = TextField(body, key: "ime")
    field.layout(ctx, Rect(0.0, 0.0, 240.0, 40.0))
    ctx.focus("ime")
    field.selectAll()
    let _ = field.handle(ctx, UiEvent.TextEditing("中", 0, 1))
    let _ = field.handle(ctx, UiEvent.KeyDown(Key.Backspace, false))
    @Expect(body.value, "abc")
    let _ = field.handle(ctx, UiEvent.TextInput("中文"))
    @Expect(body.value, "中文")
    @Expect(ctx.imeComposition("ime").isNone())
    field.undo()
    @Expect(body.value, "abc")
    @Expect(field.selectedText(), "abc")
}

@Test
func textCommandsMultilinePasteNormalizesAndUndoRemainsAtomic(): Unit {
    let body = State<String>("old")
    let area = TextArea(body, clipboard: TextClipboard(read: {=> "a\r\nb\rc"}))
    area.selectAll()
    @Expect(area.paste())
    @Expect(body.value, "a\nb\nc")
    area.undo()
    @Expect(body.value, "old")
    @Expect(area.selectedText(), "old")
}

@Test
func textCommandsHistoryHasAByteBudgetAcrossUndoAndRedo(): Unit {
    let history = UndoHistory(byteBudget: 100)
    for (i in 0..10) { history.commit(TextSnapshot("snapshot${i}", 0, 0), UInt64(i * 1000)) }
    let first = history.undo(TextSnapshot("current", 0, 0)).getOrThrow()
    @Expect(first.text, "snapshot9")
    @Expect(history.undo(first).isSome())
    @Expect(!history.canUndo())
    let oversized = UndoHistory(byteBudget: 1)
    oversized.commit(TextSnapshot("a", 0, 0), UInt64(0))
    @Expect(!oversized.canUndo())
}

@Test
func textCommandsBoundaryCacheReusesRevisionAndHandlesRebinding(): Unit {
    let reads = State<Int64>(0)
    let root = State<String>("e\u{0301}")
    let projected = root.project(get: {value => reads.value += 1; value}, set: {_, value => value})
    let cache = TextEditBoundaryCache()
    cache.prepare(projected)
    let initialReads = reads.value
    for (_ in 0..100) { @Expect(cache.prepare(projected).next(0), 3) }
    @Expect(reads.value, initialReads)
    @Expect(cache.prepare(State<String>("a")).next(0), 1)
}

@Test
func textCommandsProgrammaticReplacementIsUndoableWithoutClipboard(): Unit {
    let body = State<String>("a e\u{0301} b")
    let field = TextField(body)
    field.selectRange(2, 5)
    @Expect(field.replaceSelection(""))
    @Expect(body.value, "a  b")
    field.undo()
    @Expect(field.selectedText(), "e\u{0301}")
    @Expect(field.replaceSelection("X\r\nY"))
    @Expect(body.value, "a X Y b")
}
