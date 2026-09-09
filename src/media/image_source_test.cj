package cui.media

import std.fs.File
import sdl.{ImageLoadOptions, Rect, Renderer, SdlWindow, WindowSpec}
import cui.core.{Theme, UiContext}

private let SOURCE_FIXTURE = "../CangjieSDL/.dev/fixtures/images/quad.png"

@Test
func imageFilePathsCannotAliasMemoryOrSizeVariantCacheKeys(): Unit {
    clearImageCache()
    try (window = SdlWindow(WindowSpec("Image key isolation", 100, 80), hidden: true)) {
        let ctx = UiContext(window.renderer, Theme.light())
        let source = ImageSource.memory(File.readFrom(SOURCE_FIXTURE))
        @Expect(preloadImage(window.renderer, source))
        @Expect(preloadImage(window.renderer, SOURCE_FIXTURE, options: ImageLoadOptions(width: 8)))
        var rejected = 0
        let resizedKey = ImageSource(SOURCE_FIXTURE).cacheKey(ImageLoadOptions(width: 8))
        for (invalidPath in [source.identity, resizedKey]) {
            try { ImageView(invalidPath).draw(ctx) }
            catch (_: IllegalArgumentException) { rejected += 1 }
        }
        @Expect(rejected, 2)
        clearImageCache()
    }
}

@Test
func imageMemorySourceOwnsBytesAndSharesDecodedVariants(): Unit {
    clearImageCache()
    try (window = SdlWindow(WindowSpec("Memory image", 100, 80), hidden: true)) {
        let bytes = File.readFrom(SOURCE_FIXTURE)
        let source = ImageSource.memory(bytes)
        bytes[0] = UInt8(0)
        @Expect(preloadImage(window.renderer, source))
        @Expect(preloadImage(window.renderer, source))
        @Expect(imageCacheStats().misses, UInt64(1))
        @Expect(imageCacheStats().hits, UInt64(1))
        let small = ImageLoadOptions(width: 8)
        @Expect(preloadImage(window.renderer, source, options: small))
        @Expect(imageCacheStats().entries, Int64(2))
        let policy = ImageLoadOptions(width: 4, maxPixels: 200)
        @Expect(preloadImage(window.renderer, source, options: policy))
        let view = ImageView(source).decodeOptions(policy)
        view.draw(UiContext(window.renderer, Theme.light()))
        @Expect(match (view.status()) { case ImageStatus.Ready => true; case _ => false })
        @Expect(imageCacheStats().entries, Int64(3))
        @Expect(imageCacheStats().misses, UInt64(3))
        invalidateImage(source)
        @Expect(imageCacheStats().entries, Int64(0))
        @Expect(preloadImage(window.renderer, source))
        clearImageCache()
    }
}

@Test
func imageViewStatusFailureFallbackAndInvalidationAreObservable(): Unit {
    clearImageCache()
    try (window = SdlWindow(WindowSpec("Image status", 100, 80), hidden: true)) {
        let ctx = UiContext(window.renderer, Theme.light())
        let view = ImageView("__missing_image_status__.png").fallback(ImageSource(SOURCE_FIXTURE))
        @Expect(match (view.status()) { case ImageStatus.Idle => true; case _ => false })
        view.layout(ctx, Rect(0.0, 0.0, 80.0, 60.0))
        window.renderer.beginScene(100.0, 80.0, ctx.theme.bg)
        view.draw(ctx)
        window.renderer.endScene()
        @Expect(view.loadError().isSome())
        @Expect(match (view.status()) { case ImageStatus.Failed => true; case _ => false })
        @Expect(imageCacheStats().entries, Int64(2))
        @Expect(imageCacheStats().loadFailures, UInt64(1))
        invalidateImage("__missing_image_status__.png")
        @Expect(view.loadError().isNone())
        @Expect(match (view.status()) { case ImageStatus.Idle => true; case _ => false })
        view.close()
        @Expect(match (view.status()) { case ImageStatus.Closed => true; case _ => false })
        clearImageCache()
    }
}

@Test
func liveImageViewRetainsNegativeResolutionAcrossCacheEviction(): Unit {
    clearImageCache()
    let renderer = Renderer.headless()
    let ctx = UiContext(renderer, Theme.light())
    let view = ImageView("__live_negative_image__.png")
    view.draw(ctx)
    for (index in 0..600) { let _ = sharedTexture(renderer, "__eviction-${index}__.png") }
    let misses = imageCacheStats().misses
    view.draw(ctx)
    @Expect(imageCacheStats().misses, misses)
    @Expect(view.loadError().isSome())
    @Expect(match (view.status()) { case ImageStatus.Failed => true; case _ => false })
    invalidateImage("__live_negative_image__.png")
    @Expect(view.loadError().isNone())
    view.draw(ctx)
    @Expect(imageCacheStats().misses, misses + UInt64(1))
    clearImageCache()
}

@Test
func imageErrorPainterFailureRestoresTheCallerClip(): Unit {
    clearImageCache()
    try (window = SdlWindow(WindowSpec("Image error painter isolation", 120, 90), hidden: true)) {
        let ctx = UiContext(window.renderer, Theme.light())
        let parent = Rect(0.0, 0.0, 110.0, 80.0)
        let view = ImageView("__error_painter_clip__.png").errorPlaceholder({context, _, _ =>
            context.renderer.pushClip(Rect(15.0, 15.0, 10.0, 10.0))
            throw IllegalStateException("custom painter failed")
        })
        view.layout(ctx, Rect(10.0, 10.0, 60.0, 40.0))
        window.renderer.beginScene(120.0, 90.0, ctx.theme.bg)
        window.renderer.pushClip(parent)
        var failed = false
        try { view.draw(ctx) } catch (_: IllegalStateException) { failed = true }
        @Expect(failed)
        let clip = window.renderer.currentClip().getOrThrow()
        @Expect(clip.x, parent.x)
        @Expect(clip.y, parent.y)
        @Expect(clip.w, parent.w)
        @Expect(clip.h, parent.h)
        window.renderer.popClip()
        window.renderer.endScene()
        clearImageCache()
    }
}
