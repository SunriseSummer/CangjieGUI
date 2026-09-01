package cui.media

import sdl.{Renderer, Size}
import cui.core.{LengthUnits, Theme, UiContext}

@Test
func imageViewMeasuresAndClosesWithoutLoadingTexture(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let image = ImageView("missing.bmp", preferredHeight: 96.vp)

    let measured = image.measure(ctx, Size(240.0, 40.0))
    image.close()
    image.close()

    @Expect(measured.w, Float32(240.0))
    @Expect(measured.h, Float32(40.0))
    @Expect(image.isClosed())
}

@Test
func imageViewDrawUsesCachedFailureAndClosedViewStopsLookingUp(): Unit {
    clearImageCache()
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let first = ImageView("__cui_missing_image_view_draw__.bmp")
    let second = ImageView("__cui_missing_image_view_draw__.bmp")

    first.draw(ctx)
    first.draw(ctx)
    @Expect(imageCacheStats().hits, UInt64(0))
    second.draw(ctx)
    let warm = imageCacheStats()
    first.close()
    first.draw(ctx)

    @Expect(warm.misses, UInt64(1))
    @Expect(warm.hits, UInt64(1))
    @Expect(warm.loadFailures, UInt64(1))
    @Expect(imageCacheStats().hits, UInt64(1))
    second.close()
    clearImageCache()
}
