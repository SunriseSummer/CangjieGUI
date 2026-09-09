package cui_notepad

import std.fs.Directory
import cui.{Label, Rect, WidgetTestHost}

@Test
func savedTextTracksUndoBackToOriginalAndNewDocument(): Unit {
    let model = NotepadModel()
    let original = model.body.value
    model.markSaved()
    @Expect(!model.dirty.value)
    model.body.value = "修改"
    @Expect(model.dirty.value)
    model.body.value = original
    @Expect(!model.dirty.value)
    newFile(model)
    @Expect(!model.confirmingNew.value)
    @Expect(model.body.value.isEmpty())
    @Expect(!model.dirty.value)
    model.body.value = "尚未保存"
    newFile(model)
    @Expect(model.confirmingNew.value)
    cancelNewFile(model)
    @Expect(model.body.value, "尚未保存")
    newFile(model)
    @Expect(model.confirmingNew.value)
    model.markSaved()
    @Expect(!model.confirmingNew.value)
    newFile(model)
    @Expect(model.body.value.isEmpty())
}

@Test
func fileRoundTripAndFailuresPreserveUnsavedChanges(): Unit {
    let directory = Directory.createTemp("target").toString()
    let path = directory + "/note.txt"
    let model = NotepadModel()
    model.body.value = "中文 🎉\n草稿"
    saveFileToPath(model, path, "saved")
    @Expect(!model.dirty.value)
    @Expect(model.currentPath.value, path)
    model.body.value = "keep this edit"
    // A directory cannot be used as a document file; failed I/O must not mark this edit saved.
    saveFileToPath(model, directory, "unexpected")
    loadFile(model, directory + "/missing.txt", "unexpected")
    @Expect(model.dirty.value)
    @Expect(model.body.value, "keep this edit")
    @Expect(model.currentPath.value, path)
    loadFile(model, path, "loaded")
    @Expect(!model.dirty.value)
    @Expect(model.body.value, "中文 🎉\n草稿")
    @Expect(model.bodyCursor.value, model.bodyAnchor.value)
    @Expect(model.bodyCursor.value, model.body.value.size)
}

@Test
func idleNotepadDoesNotSubscribeToEveryFrame(): Unit {
    let model = NotepadModel()
    let host = WidgetTestHost()
    try {
        let frame = host.frame(Rect(0.0, 0.0, 300.0, 80.0)) {
            subscribeNotepadDialogs(model)
            Label(model.status.value)
        }
        @Expect(frame.metrics.frameSubscribers, 0)
        @Expect(!model.hasDialog())
    } finally { host.reset() }
}

@Test
func documentNameSupportsBothPathSeparators(): Unit {
    let model = NotepadModel()
    @Expect(documentName(model), "未命名文档")
    model.currentPath.value = "C:\\Documents\\会议.txt"
    @Expect(documentName(model), "会议.txt")
    model.currentPath.value = "/home/demo/notes.txt"
    @Expect(documentName(model), "notes.txt")
}
