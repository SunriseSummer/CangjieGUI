package cui_symbols

import cui.*

@Test
func catalogContainsFortyUniqueReadySources(): Unit {
    let model = SymbolsModel()
    @Expect(model.entries.size, 40)
    for (i in 0..model.entries.size) {
        for (j in 0..i) { @Expect(model.entries[i].name != model.entries[j].name) }
    }
    clearImageCache()
    try (window = SdlWindow(WindowSpec("Symbol catalog", 80, 60), hidden: true)) {
        for (entry in model.entries) { @Expect(preloadIcon(window.renderer, entry.source, pixels: 30)) }
        @Expect(imageCacheStats().loadFailures, UInt64(0))
        clearImageCache()
    }
}

@Test
func catalogActionAndTemporalControlsRemainInteractive(): Unit {
    let model = SymbolsModel()
    let host = WidgetTestHost()
    try {
        let _ = host.frame(Rect(0.0, 0.0, 1180.0, 1100.0), body: {=> symbolsView(model)})
        var actions = 0
        for (node in host.context.semanticsSnapshot()) {
            if (node.properties.label == "喜欢图标集") {
                @Expect(host.context.performSemanticsAction(node.id, SemanticsAction.Activate))
                actions += 1
            }
        }
        @Expect(actions, 1)
        @Expect(model.clicks.value, 1)
        host.context.focus("symbol-date")
        let _ = host.frame(Rect(0.0, 0.0, 1180.0, 1100.0), events: [UiEvent.KeyDown(Key.Enter, false)],
            body: {=> symbolsView(model)})
        @Expect(host.context.overlayCount() > 0)
        let _ = host.frame(Rect(0.0, 0.0, 1180.0, 1100.0), events: [UiEvent.KeyDown(Key.Escape, false)],
            body: {=> symbolsView(model)})
        @Expect(host.context.overlayCount(), 0)
    } finally { host.reset(); clearImageCache() }
}
