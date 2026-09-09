package cui_notes

import cui.{Key, Rect, SemanticsAction, UiEvent, WidgetTestHost}

@Test
func deletionConfirmationStartsOnTheNonDestructiveAction(): Unit {
    let host = WidgetTestHost(theme: notesTheme())
    let model = NotesModel()
    let bounds = Rect(0.0, 0.0, 640.0, 480.0)
    let build = {=> notesView(model)}
    let before = model.notes.value.size
    try {
        let _ = host.frame(bounds, body: build)
        @Expect(host.context.performSemanticsAction("notes-delete", SemanticsAction.Activate))
        let _ = host.frame(bounds, body: build)
        @Expect(host.context.focusedSemanticsNode().getOrThrow().id, "notes-delete-cancel")
        // cjcheck-ignore: bool-literal-arg # SDL KeyDown 的第二个位置参数固定为 repeat；false 表示首次按下。
        let _ = host.frame(bounds, events: [UiEvent.KeyDown(Key.Enter, false)], body: build)
        @Expect(!model.confirmDelete.value)
        @Expect(model.notes.value.size, before)
    } finally { host.reset() }
}

@Test
func emptyNotesCanStartAgainThroughTheHeaderAction(): Unit {
    let host = WidgetTestHost(theme: notesTheme())
    let model = NotesModel()
    while (!model.notes.value.isEmpty()) { model.deleteSelected() }
    model.deleteSelected()
    model.duplicateSelected()
    let bounds = Rect(0.0, 0.0, 640.0, 480.0)
    try {
        let _ = host.frame(bounds, body: {=> notesView(model)})
        @Expect(host.context.semanticsTreeSnapshot().node("notes-delete").isNone())
        @Expect(host.context.performSemanticsAction("notes-new", SemanticsAction.Activate))
        let _ = host.frame(bounds, body: {=> notesView(model)})
        @Expect(model.notes.value.size, 1)
        @Expect(model.selected.value, 0)
        @Expect(host.context.semanticsTreeSnapshot().node(model.editorId()).isSome())
    } finally { host.reset() }
}
