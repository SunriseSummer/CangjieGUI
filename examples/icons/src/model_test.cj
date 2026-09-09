package cui_icons

import cui.*

@Test
func allDemonstrationArtworkDecodesAtItsIntendedSizes(): Unit {
    clearImageCache()
    try (window = SdlWindow(WindowSpec("Icon assets", 80, 60), hidden: true)) {
        let model = IconsModel()
        for (name in ["document", "folder", "save", "copy", "refresh", "trash", "search", "search-16", "spark", "moon", "check", "arrow-up-right"]) {
            @Expect(preloadIcon(window.renderer, asset(name), pixels: 16))
            @Expect(preloadIcon(window.renderer, asset(name), pixels: 48))
        }
        for (pixels in [24, 48, 72, 96, 144, 192]) {
            @Expect(preloadIcon(window.renderer, model.brand, pixels: Int32(pixels)))
        }
        @Expect(preloadIcon(window.renderer, model.memory, pixels: 32))
        @Expect(preloadIcon(window.renderer, IconSource("assets/icons/pixel-16.png", renderingMode: IconRenderingMode.Original), pixels: 16))
        @Expect(imageCacheStats().loadFailures, UInt64(0))
        clearImageCache()
    }
}

@Test
func iconActionsRemainAccessibleAndDisabledActionDoesNotActivate(): Unit {
    let model = IconsModel()
    let host = WidgetTestHost()
    try {
        let _ = host.frame(Rect(0.0, 0.0, 1060.0, 1020.0), body: {=> iconsView(model)})
        var namedButtons = 0
        for (node in host.context.semanticsSnapshot()) {
            if (node.properties.label == "保存" || node.properties.label == "复制" || node.properties.label == "刷新") {
                @Expect(host.context.performSemanticsAction(node.id, SemanticsAction.Activate))
                namedButtons += 1
            }
            if (node.properties.label == "删除") {
                @Expect(!node.properties.enabled)
                @Expect(!host.context.performSemanticsAction(node.id, SemanticsAction.Activate))
            }
        }
        @Expect(namedButtons, 3)
        @Expect(model.clicks.value, 3)
        model.dark.value = true
        let _ = host.frame(Rect(0.0, 0.0, 1060.0, 1020.0), body: {=> iconsView(model)})
    } finally { host.reset(); clearImageCache() }
}
