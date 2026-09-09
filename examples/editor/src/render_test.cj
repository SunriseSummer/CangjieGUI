package cui_editor

import std.fs.Directory
import cui.{Rect, SdlWindow, SemanticsAction, UiEvent, WidgetTestHost, WindowSpec}

@Test
func editorMinimumWindowKeepsUsablePaperWithNativeFonts(): Unit {
    let directory = Directory.createTemp("target").toString()
    try (window = SdlWindow(WindowSpec("Editor layout E2E", 560, 420, scale: 1.5,
        supersample: 2, vsync: false), hidden: true)) {
        let bounds = Rect(0.0, 0.0, 560.0, 420.0)
        let renderer = window.renderer
        renderer.prepareTextLayout(bounds.w, bounds.h)
        for (scale in [Float32(1.0), Float32(1.25)]) {
            let model = EditorModel()
            model.steadyCaret.value = true
            let host = WidgetTestHost(theme: editorTheme(), renderer: renderer, fontScale: scale)
            let view = {=> editorView(model)}
            try {
                let _ = host.frame(bounds, body: view)
                let paper = host.context.semanticsTreeSnapshot().node("document").getOrThrow().bounds
                @Expect(paper.h >= 28.0 * scale)
                @Expect(paper.bottom() <= bounds.bottom())
                renderer.captureBmp("${directory}/minimum-${scale}.bmp")
                @Expect(host.context.performSemanticsAction("editor-select-all", SemanticsAction.Activate))
                host.context.focus("document")
                let _ = host.frame(bounds, events: [UiEvent.TextInput("中文与 Emoji 🎉\n新的草稿")], body: view)
                @Expect(model.text.value, "中文与 Emoji 🎉\n新的草稿")
                @Expect(host.context.performSemanticsAction("editor-undo", SemanticsAction.Activate))
                let _ = host.frame(bounds, body: view)
                @Expect(model.text.value, seedText())
            } finally { host.reset() }
        }
    }
    println("@@EDITOR_DESIGN_ARTIFACTS|${directory}")
}
