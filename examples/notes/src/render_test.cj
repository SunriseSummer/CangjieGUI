package cui_notes

import std.fs.Directory
import cui.{Rect, SdlWindow, SemanticsAction, WidgetTestHost, WindowSpec}

@Test
func notesMinimumWindowRendersDocumentDialogAndEmptyState(): Unit {
    let directory = Directory.createTemp("target").toString()
    try (window = SdlWindow(WindowSpec("Notes layout E2E", 640, 480, scale: 1.5,
        supersample: 2, vsync: false), hidden: true)) {
        let bounds = Rect(0.0, 0.0, 640.0, 480.0)
        let renderer = window.renderer
        renderer.prepareTextLayout(bounds.w, bounds.h)
        let host = WidgetTestHost(theme: notesTheme(), renderer: renderer, fontScale: 1.25)
        let model = NotesModel()
        let view = {=> notesView(model)}
        try {
            let _ = host.frame(bounds, body: view)
            let paper = host.context.semanticsTreeSnapshot().node(model.editorId()).getOrThrow().bounds
            @Expect(paper.w >= 240.0 && paper.h >= 150.0)
            renderer.captureBmp("${directory}/minimum.bmp")
            @Expect(host.context.performSemanticsAction("notes-delete", SemanticsAction.Activate))
            let _ = host.frame(bounds, body: view)
            @Expect(host.context.focusedSemanticsNode().getOrThrow().id, "notes-delete-cancel")
            renderer.captureBmp("${directory}/confirm.bmp")
            @Expect(host.context.performSemanticsAction("notes-delete-cancel", SemanticsAction.Activate))
            while (!model.notes.value.isEmpty()) { model.deleteSelected() }
            let _ = host.frame(bounds, body: view)
            @Expect(host.context.semanticsTreeSnapshot().node("notes-new").isSome())
            renderer.captureBmp("${directory}/empty.bmp")
        } finally { host.reset() }
    }
    println("@@NOTES_DESIGN_ARTIFACTS|${directory}")
}
