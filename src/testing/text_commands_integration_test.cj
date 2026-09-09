package cui.testing

import sdl.{Rect, UiEvent}
import cui.core.{State, SemanticsAction}
import cui.text.{TextClipboard, TextField, TextArea}

private class ReadOnlyCommandProbe { var field: ?TextField = None }

@Test
func textCommandsReadOnlyRebuildCannotUndoOrPasteButCanCopy(): Unit {
    let host = WidgetTestHost()
    let body = State<String>("text")
    let editable = State<Bool>(true)
    let clipboardText = State<String>("paste")
    let clipboard = TextClipboard(read: {=> clipboardText.value}, write: {value => clipboardText.value = value})
    let probe = ReadOnlyCommandProbe()
    let build = {=> probe.field = Some(TextField(body, key: "readonly", editable: editable.value, clipboard: clipboard)) }
    let _ = host.frame(Rect(0.0, 0.0, 250.0, 40.0), body: build)
    host.context.focus("readonly")
    let _ = probe.field.getOrThrow().handle(host.context, UiEvent.TextInput("!"))
    editable.value = false
    let _ = host.frame(Rect(0.0, 0.0, 250.0, 40.0), body: build)
    let field = probe.field.getOrThrow()
    field.undo()
    field.redo()
    @Expect(body.value, "text!")
    @Expect(!field.canUndo() && !field.canRedo())
    field.selectAll()
    @Expect(field.copy())
    @Expect(clipboardText.value, "text!")
    @Expect(!field.cut() && !field.paste())
    @Expect(field.focusableId().isNone())
    host.reset()
}

@Test
func textAreaSemanticsUsesTheSameValidatedEditingPath(): Unit {
    let host = WidgetTestHost()
    let text = State<String>("old")
    let editable = State<Bool>(true)
    let build: () -> Unit = {=> TextArea(text, key: "semantic-editor", editable: editable.value); () }
    let _ = host.frame(Rect(0.0, 0.0, 300.0, 160.0), body: build)
    @Expect(host.context.performSemanticsAction("semantic-editor", SemanticsAction.SetValue("a\r\nb")))
    @Expect(text.value, "a\nb")
    @Expect(!host.context.performSemanticsAction("semantic-editor", SemanticsAction.SetValue("bad\u{0000}value")))
    editable.value = false
    let _ = host.frame(Rect(0.0, 0.0, 300.0, 160.0), body: build)
    @Expect(!host.context.performSemanticsAction("semantic-editor", SemanticsAction.SetValue("blocked")))
    @Expect(text.value, "a\nb")
    host.reset()
}

