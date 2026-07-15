package cui.text

import sdl.{FrameInfo, Key, Rect, Renderer, UiEvent}
import cui.core.{State, Theme, UiContext}

private func historyTestContext(): UiContext {
    UiContext(Renderer.headless(), Theme.light())
}

@Test
func undoHistoryCoalescesRapidEditsButSeparatesPausedOnes(): Unit {
    // Two edits within the coalesce window collapse into one undo step.
    let rapid = UndoHistory()
    rapid.commit(TextSnapshot("", 0, 0), UInt64(0))
    rapid.commit(TextSnapshot("a", 1, 1), UInt64(100))
    let firstUndo = rapid.undo(TextSnapshot("ab", 2, 2))
    @Expect(firstUndo.getOrThrow().text, "")
    @Expect(!rapid.canUndo()) // only one group existed

    // A paused second edit forms its own step.
    let paused = UndoHistory()
    paused.commit(TextSnapshot("", 0, 0), UInt64(0))
    paused.commit(TextSnapshot("a", 1, 1), UInt64(1000))
    @Expect(paused.undo(TextSnapshot("ab", 2, 2)).getOrThrow().text, "a")
    @Expect(paused.undo(TextSnapshot("a", 1, 1)).getOrThrow().text, "")
    @Expect(!paused.canUndo())
}

@Test
func undoThenRedoRestoresAndNewEditClearsRedo(): Unit {
    let history = UndoHistory()
    history.commit(TextSnapshot("", 0, 0), UInt64(0))

    @Expect(history.undo(TextSnapshot("a", 1, 1)).getOrThrow().text, "")
    @Expect(history.canRedo())
    @Expect(history.redo(TextSnapshot("", 0, 0)).getOrThrow().text, "a")
    @Expect(!history.canRedo())

    let _ = history.undo(TextSnapshot("a", 1, 1))
    @Expect(history.canRedo())
    history.commit(TextSnapshot("", 0, 0), UInt64(5000)) // a fresh edit invalidates redo
    @Expect(!history.canRedo())
}

@Test
func textFieldUndoRedoRevertsAndReappliesTyping(): Unit {
    let ctx = historyTestContext()
    let body = State<String>("")
    let field = TextField(body, key: "f")
    field.layout(ctx, Rect(0.0, 0.0, 200.0, 32.0))
    ctx.focus("f")

    // Default frame time is 0 for both, so the two keystrokes coalesce into one undo step.
    let _ = field.handle(ctx, UiEvent.TextInput("h"))
    let _ = field.handle(ctx, UiEvent.TextInput("i"))
    @Expect(body.value, "hi")

    field.undo()
    @Expect(body.value, "")
    field.redo()
    @Expect(body.value, "hi")
}

@Test
func textAreaUndoRevertsMultiLineEdit(): Unit {
    let ctx = historyTestContext()
    let body = State<String>("start")
    let area = TextArea(body, key: "a")
    area.layout(ctx, Rect(0.0, 0.0, 200.0, 120.0))
    ctx.focus("a")

    let _ = area.handle(ctx, UiEvent.TextInput("X"))
    @Expect(body.value != "start")
    area.undo()
    @Expect(body.value, "start")
    area.redo()
    @Expect(body.value != "start")
}

@Test
func autofocusClaimsFocusOnceOnFirstFrame(): Unit {
    let ctx = historyTestContext()
    let body = State<String>("")
    let field = TextField(body, key: "s").autofocus()
    field.layout(ctx, Rect(0.0, 0.0, 200.0, 32.0))
    @Expect(!ctx.hasFocus("s"))

    let _ = field.handle(ctx, UiEvent.Frame(FrameInfo(UInt64(0), UInt64(0))))
    @Expect(ctx.hasFocus("s")) // claimed on the first frame

    // It is one-time: once focus has moved away, later frames do not re-grab it.
    ctx.clearFocus()
    let _ = field.handle(ctx, UiEvent.Frame(FrameInfo(UInt64(16), UInt64(16))))
    @Expect(!ctx.hasFocus("s"))
}

// TextArea gained the same one-time autofocus as TextField (feature parity between the two text
// controls) — it claims focus on the first frame and does not re-grab it afterwards.
@Test
func textAreaAutofocusClaimsFocusOnceOnFirstFrame(): Unit {
    let ctx = historyTestContext()
    let body = State<String>("")
    let area = TextArea(body, key: "ta").autofocus()
    area.layout(ctx, Rect(0.0, 0.0, 200.0, 100.0))
    @Expect(!ctx.hasFocus("ta"))

    let _ = area.handle(ctx, UiEvent.Frame(FrameInfo(UInt64(0), UInt64(0))))
    @Expect(ctx.hasFocus("ta")) // claimed on the first frame

    ctx.clearFocus()
    let _ = area.handle(ctx, UiEvent.Frame(FrameInfo(UInt64(16), UInt64(16))))
    @Expect(!ctx.hasFocus("ta")) // one-time
}

// A read-only TextField ignores editing input even while focused (feature parity with TextArea's
// `editable` flag), while an editable field still edits — proving the gate is editability, not focus.
@Test
func readOnlyTextFieldIgnoresEdits(): Unit {
    let ctx = historyTestContext()
    let locked = State<String>("locked")
    let field = TextField(locked, key: "ro", editable: false)
    field.layout(ctx, Rect(0.0, 0.0, 200.0, 32.0))
    ctx.focus("ro") // force focus so the only remaining gate is editability

    let _ = field.handle(ctx, UiEvent.TextInput("X"))
    @Expect(locked.value, "locked") // insertion ignored
    let _ = field.handle(ctx, UiEvent.KeyDown(Key.Backspace, false))
    @Expect(locked.value, "locked") // backspace ignored

    let editable = State<String>("ab")
    let writable = TextField(editable, key: "rw")
    writable.layout(ctx, Rect(0.0, 0.0, 200.0, 32.0))
    ctx.focus("rw")
    let _ = writable.handle(ctx, UiEvent.TextInput("c"))
    @Expect(editable.value != "ab", true) // editable field still takes the edit
}

@Test
func undoWithNothingRecordedIsSafeNoOp(): Unit {
    let ctx = historyTestContext()
    let body = State<String>("keep")
    let field = TextField(body, key: "f")
    field.layout(ctx, Rect(0.0, 0.0, 200.0, 32.0))

    field.undo() // nothing recorded yet
    field.redo()
    @Expect(body.value, "keep")
}

// A caret jump (arrow navigation or a click) starts a new undo group even inside the time
// window: "type, move, type" must undo as two steps, not one spanning both positions.
@Test
func caretJumpBreaksUndoCoalescing(): Unit {
    let ctx = historyTestContext()
    let body = State<String>("")
    let field = TextField(body, key: "f")
    field.layout(ctx, Rect(0.0, 0.0, 200.0, 32.0))
    ctx.focus("f")

    ctx.frame = FrameInfo(UInt64(100), UInt64(16))
    let _ = field.handle(ctx, UiEvent.TextInput("a"))
    // 50ms later — well inside the 500ms coalescing window — but with a caret jump between.
    ctx.frame = FrameInfo(UInt64(150), UInt64(16))
    let _ = field.handle(ctx, UiEvent.KeyDown(Key.Left, false))
    let _ = field.handle(ctx, UiEvent.TextInput("b"))
    @Expect(body.value, "ba")

    field.undo()
    @Expect(body.value, "a") // only the edit after the jump reverted
    field.undo()
    @Expect(body.value, "") // the first group is separate
}
