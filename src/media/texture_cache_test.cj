package cui.media

import sdl.{Color, Renderer, SdlWindow, Surface, WindowSpec}
import sdl.system.FileSystem

@Test
func imageTextureCacheReusesAndClosesLoadedTexture(): Unit {
    let window = SdlWindow(WindowSpec("Image cache texture test", 80, 60, vsync: false, supersample: 1))
    let cache = ImageTextureCache(maxEntries: 2, maxBytes: UInt64(16 * 1024 * 1024))
    let path = "__cui_image_cache_texture_test.bmp"
    try {
        try (surface = Surface.create(4, 3)) {
            surface.clear(Color.rgb(40, 120, 220))
            surface.saveBmp(path)
        }
        let firstResult = cache.texture(window.renderer, path)
        @Assert(firstResult.isSome())
        let first = firstResult.getOrThrow() // the successful load is asserted immediately above
        let secondResult = cache.texture(window.renderer, path)
        @Assert(secondResult.isSome())
        let second = secondResult.getOrThrow() // the cache hit is asserted immediately above

        @Expect(refEq(first, second))
        @Expect(cache.stats().hits, UInt64(1))
        @Expect(cache.stats().misses, UInt64(1))
        @Expect(cache.stats().loadFailures, UInt64(0))
        @Expect(cache.stats().estimatedBytes > UInt64(0))

        @Expect(cache.invalidate(path))
        @Expect(first.isClosed())
        @Expect(cache.stats().entries, Int64(0))
    } finally {
        cache.clearEntries()
        if (FileSystem.exists(path)) {
            FileSystem.remove(path)
        }
        window.close()
    }
}

@Test
func imageTextureCacheCachesFailuresAndInvalidationRetries(): Unit {
    let cache = ImageTextureCache(maxEntries: 2, maxBytes: UInt64(1024))
    let renderer = Renderer.headless()
    let path = "__cui_missing_image_cache_retry__.bmp"

    @Expect(cache.texture(renderer, path).isNone())
    @Expect(cache.texture(renderer, path).isNone())
    let warm = cache.stats()
    @Expect(warm.hits, UInt64(1))
    @Expect(warm.misses, UInt64(1))
    @Expect(warm.loadFailures, UInt64(1))
    @Expect(warm.entries, Int64(1))
    @Expect(warm.estimatedBytes > UInt64(0))

    @Expect(cache.invalidate(path))
    @Expect(cache.stats().entries, Int64(0))
    @Expect(cache.texture(renderer, path).isNone())
    @Expect(cache.stats().misses, UInt64(2))
    @Expect(cache.stats().loadFailures, UInt64(2))
}

@Test
func imageTextureCacheSeparatesRendererLifetimes(): Unit {
    let cache = ImageTextureCache()
    let first = Renderer.headless()
    let second = Renderer.headless()
    let path = "__cui_missing_image_cache_renderer__.bmp"

    @Expect(cache.texture(first, path).isNone())
    @Expect(cache.texture(second, path).isNone())

    let stats = cache.stats()
    @Expect(stats.hits, UInt64(0))
    @Expect(stats.misses, UInt64(2))
    @Expect(stats.loadFailures, UInt64(2))
    @Expect(stats.rendererChanges, UInt64(1))
    @Expect(stats.entries, Int64(1))
}

@Test
func publicImageCacheIsThreadLocalAndClearResetsStatistics(): Unit {
    clearImageCache()
    let mainRenderer = Renderer.headless()
    let mainPath = "__cui_missing_image_cache_main_thread__.bmp"
    @Expect(sharedTexture(mainRenderer, mainPath).isNone())
    @Expect(imageCacheStats().misses, UInt64(1))

    let worker = spawn {
        =>
            clearImageCache()
            let workerRenderer = Renderer.headless()
            let workerPath = "__cui_missing_image_cache_worker_thread__.bmp"
            let _ = sharedTexture(workerRenderer, workerPath)
            let _ = sharedTexture(workerRenderer, workerPath)
            let stats = imageCacheStats()
            clearImageCache()
            stats
    }
    let workerStats = worker.get()

    @Expect(workerStats.misses, UInt64(1))
    @Expect(workerStats.hits, UInt64(1))
    @Expect(imageCacheStats().misses, UInt64(1))
    @Expect(imageCacheStats().hits, UInt64(0))

    invalidateImage(mainPath)
    @Expect(imageCacheStats().entries, Int64(0))
    clearImageCache()
    let cleared = imageCacheStats()
    @Expect(cleared.hits, UInt64(0))
    @Expect(cleared.misses, UInt64(0))
    @Expect(cleared.loadFailures, UInt64(0))
    @Expect(cleared.entries, Int64(0))
    @Expect(cleared.maxEntries, Int64(256))
    @Expect(cleared.maxBytes, UInt64(128 * 1024 * 1024))
}
