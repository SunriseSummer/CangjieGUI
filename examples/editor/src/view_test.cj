package cui_editor

import cui.{Rect, SemanticsAction, UiEvent, WidgetTestHost}

@Test
func checkpointDirtyStateReflectsActualText(): Unit {
    let model = EditorModel()
    let original = model.text.value
    @Expect(!model.dirty.value)
    model.text.value = "changed"
    @Expect(model.dirty.value)
    model.text.value = original
    @Expect(!model.dirty.value)
    model.text.value = "new checkpoint"
    model.save()
    @Expect(!model.dirty.value)
}

@Test
func editorToolbarRetainsUndoAndHonorsReadOnly(): Unit {
    let host = WidgetTestHost(theme: editorTheme())
    let model = EditorModel()
    model.text.value = ""
    let bounds = Rect(0.0, 0.0, 760.0, 560.0)
    let build = {=> editorView(model)}
    try {
        let _ = host.frame(bounds, body: build)
        host.context.focus("document")
        let _ = host.frame(bounds, events: [UiEvent.TextInput("Hello 🎉")], body: build)
        @Expect(model.text.value, "Hello 🎉")
        @Expect(host.context.performSemanticsAction("editor-undo", SemanticsAction.Activate))
        let _ = host.frame(bounds, body: build)
        @Expect(model.text.value, "")
        @Expect(host.context.performSemanticsAction("editor-redo", SemanticsAction.Activate))
        model.readOnly.value = true
        let _ = host.frame(bounds, body: build)
        @Expect(!host.context.performSemanticsAction("editor-paste", SemanticsAction.Activate))
        @Expect(!host.context.performSemanticsAction("editor-undo", SemanticsAction.Activate))
        @Expect(model.text.value, "Hello 🎉")
    } finally { host.reset() }
}

@Test
func editorCommandsFitMinimumWindowWithLargerText(): Unit {
    for (scale in [Float32(1.0), Float32(1.25)]) {
        let host = WidgetTestHost(theme: editorTheme(), fontScale: scale)
        let model = EditorModel()
        let bounds = Rect(0.0, 0.0, 560.0, 420.0)
        try {
            let _ = host.frame(bounds, body: {=> editorView(model)})
            for (id in ["document", "editor-checkpoint", "editor-select-all", "editor-redo"]) {
                let node = host.context.semanticsTreeSnapshot().node(id).getOrThrow()
                if (node.bounds.w <= 0.0 || node.bounds.h <= 0.0) {
                    println("invalid editor layout: ${id}, scale=${scale}, y=${node.bounds.y}, h=${node.bounds.h}, w=${node.bounds.w}")
                }
                @Expect(node.bounds.w > 0.0 && node.bounds.h > 0.0)
                @Expect(node.bounds.x >= 0.0 && node.bounds.y >= 0.0)
                @Expect(node.bounds.right() <= bounds.right() && node.bounds.bottom() <= bounds.bottom())
            }
        } finally { host.reset() }
    }
}
