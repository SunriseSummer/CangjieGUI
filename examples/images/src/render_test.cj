package cui_images

import cui.*
import std.fs.{Directory, File, exists, remove}

@Test
func studioRendersEverySourceAndFitWithAccessibleDescriptions(): Unit {
    clearImageCache()
    try (window = SdlWindow(WindowSpec("Image studio regression", 940, 750, supersample: 1), hidden: true)) {
        let model = ImagesModel()
        let host = WidgetTestHost(renderer: window.renderer)
        let view = {=> imagesView(model)}
        try {
            for (format in 0..FORMATS.size) {
                model.format.value = format
                for (fit in 0..FITS.size) {
                    model.fit.value = fit
                    window.renderer.beginScene(940.0, 750.0, Color.rgb(248, 249, 250))
                    let _ = host.frame(Rect(0.0, 0.0, 940.0, 750.0), body: view)
                    window.renderer.endScene()
                }
            }
            // The deliberately missing placeholder card is the only failed source in the studio.
            @Expect(imageCacheStats().loadFailures, UInt64(1))
            var described = false
            for (node in host.context.semanticsSnapshot()) {
                if (node.properties.label == "晨光中的高山、松林与湖面上的小舟") { described = true }
            }
            @Expect(described)
        } finally {
            host.reset()
            clearImageCache()
        }
    }
}

@Test
func retainedImageRefreshRecoversAnInitiallyMissingFileWithoutRebuilding(): Unit {
    let directory = Directory.createTemp("target").toString()
    let path = directory + "/created-later.png"
    clearImageCache()
    try {
        try (window = SdlWindow(WindowSpec("Retained image refresh", 120, 90, supersample: 1), hidden: true)) {
            let host = WidgetTestHost(renderer: window.renderer)
            let probe = ImageRefreshProbe()
            let view: () -> Unit = {=>
                VStack {
                    let image = ImageView(path).size(80.vp, 60.vp).intrinsicSize().alt("延迟图片")
                    probe.latest = Some(image)
                    probe.builds += 1
                }.crossAxisAlignment(CrossAxisAlignment.Start)
            }
            try {
                let _ = host.frame(Rect(0.0, 0.0, 120.0, 90.0), body: view)
                @Expect(probe.latest.getOrThrow().loadError().isSome())
                let before = probe.builds
                // Retained empty commands can outlive the failed cache entry they observed.
                for (index in 0..600) {
                    let _ = preloadImage(window.renderer, directory + "/missing-${index}.png")
                }
                @Expect(imageCacheStats().evictions > UInt64(256))
                @Expect(match (probe.latest.getOrThrow().status()) { case ImageStatus.Failed => true; case _ => false })
                try (surface = Surface.create(8, 6)) {
                    surface.clear(Color.rgb(30, 160, 100))
                    surface.savePng(path)
                }
                invalidateImage(path)
                let _ = host.frame(Rect(0.0, 0.0, 120.0, 90.0), body: view)
                @Expect(match (probe.latest.getOrThrow().status()) { case ImageStatus.Ready => true; case _ => false })
                @Expect(probe.latest.getOrThrow().loadError().isNone())
                @Expect(probe.builds, before)
                var found = false
                for (node in host.context.semanticsSnapshot()) {
                    if (node.properties.label == "延迟图片") {
                        found = true
                        @Expect(node.bounds.w, Float32(8.0))
                        @Expect(node.bounds.h, Float32(6.0))
                    }
                }
                @Expect(found)
            } finally { host.reset(); clearImageCache() }
        }
    } finally {
        if (exists(path)) { remove(path) }
        remove(directory)
    }
}

@Test
func imageStyleChangesMatchFullRenderingAtFractionalDpi(): Unit {
    let directory = Directory.createTemp("target").toString()
    let incremental = directory + "/incremental.bmp"
    let full = directory + "/full.bmp"
    try {
        for (sampling in [Int32(1), Int32(2)]) {
            try (window = SdlWindow(WindowSpec("Image paint equivalence", 320, 220, scale: 1.25,
                supersample: sampling), hidden: true)) {
                paintComparison(window.renderer, RetainedTestMode.Incremental, incremental)
                paintComparison(window.renderer, RetainedTestMode.Full, full)
                @Expect(File.readFrom(incremental), File.readFrom(full))
            }
        }
    } finally {
        if (exists(incremental)) { remove(incremental) }
        if (exists(full)) { remove(full) }
        remove(directory)
    }
}

private func paintComparison(renderer: Renderer, mode: RetainedTestMode, path: String): Unit {
    clearImageCache()
    let host = WidgetTestHost(renderer: renderer, retainedMode: mode)
    let opacity = State<Float32>(1.0)
    let view: () -> Unit = {=>
        HStack(spacing: 12.vp) {
            ImageView("assets/alpine.png").size(140.vp, 140.vp).fit(ImageFit.Cover).cornerRadius(32.vp)
                .imageOpacity(opacity.value).imageBackground(Color.rgb(250, 240, 220))
            ImageView("assets/alpine.png").size(140.vp, 140.vp).fit(ImageFit.Cover).cornerRadius(12.vp)
                .tint(Color.rgb(150, 210, 230)).flip(TextureFlip.Horizontal)
        }.hug().padding(10.vp)
    }
    try {
        for (alpha in [Float32(1.0), Float32(0.4)]) {
            opacity.value = alpha
            renderer.beginScene(320.0, 220.0, Color.rgb(248, 249, 250))
            let _ = host.frame(Rect(0.0, 0.0, 320.0, 220.0), body: view)
            renderer.captureBmp(path)
            renderer.endScene()
        }
    } finally { host.reset(); clearImageCache() }
}

private class ImageRefreshProbe {
    var latest: ?ImageView = None
    var builds: Int64 = 0
}

@Test
func cachedImageInvalidationTransfersToAReplacementHost(): Unit {
    let directory = Directory.createTemp("target").toString()
    let path = directory + "/replacement.png"
    clearImageCache()
    try {
        try (window = SdlWindow(WindowSpec("Image observer transfer", 120, 90), hidden: true)) {
            let first = WidgetTestHost(renderer: window.renderer)
            let second = WidgetTestHost(renderer: window.renderer)
            let probe = ImageRefreshProbe()
            let view: () -> Unit = {=>
                VStack {
                    let image = ImageView(path).size(80.vp, 60.vp)
                    probe.latest = Some(image)
                    probe.builds += 1
                }
            }
            try {
                let _ = first.frame(Rect(0.0, 0.0, 120.0, 90.0), body: view)
                first.reset()
                let _ = second.frame(Rect(0.0, 0.0, 120.0, 90.0), body: view)
                let before = probe.builds
                try (surface = Surface.create(8, 6)) {
                    surface.clear(Color.rgb(80, 100, 120))
                    surface.savePng(path)
                }
                invalidateImage(path)
                let _ = second.frame(Rect(0.0, 0.0, 120.0, 90.0), body: view)
                @Expect(probe.builds, before)
                @Expect(match (probe.latest.getOrThrow().status()) { case ImageStatus.Ready => true; case _ => false })
            } finally { second.reset(); first.reset(); clearImageCache() }
        }
    } finally {
        if (exists(path)) { remove(path) }
        remove(directory)
    }
}
