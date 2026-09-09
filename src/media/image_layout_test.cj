package cui.media

import sdl.{Color, Rect, Renderer, Size}
import cui.core.{Alignment, LengthUnits, Theme, UiContext}

@Test
func imageCoverAlignmentCropsTheCorrectSourcePixels(): Unit {
    let source = Rect(10.0, 20.0, 200.0, 100.0)
    let frame = Rect(5.0, 7.0, 100.0, 100.0)
    let left = placeImage(source, frame, ImageFit.Cover, Alignment.Leading)
    let right = placeImage(source, frame, ImageFit.Cover, Alignment.Trailing)
    let center = placeImage(source, frame, ImageFit.Cover, Alignment.Center)
    @Expect(left.source.x, Float32(10.0))
    @Expect(right.source.x, Float32(110.0))
    @Expect(center.source.x, Float32(60.0))
    @Expect(center.source.w, Float32(100.0))
    @Expect(center.destination.x, frame.x)
    @Expect(center.destination.w, frame.w)
}

@Test
func imageFitModesHandleLetterboxOriginalSizeAndEmptyRegions(): Unit {
    let source = Rect(0.0, 0.0, 40.0, 20.0)
    let frame = Rect(10.0, 10.0, 100.0, 100.0)
    let contain = placeImage(source, frame, ImageFit.Contain, Alignment.Bottom)
    @Expect(contain.destination.y, Float32(60.0))
    @Expect(contain.destination.h, Float32(50.0))
    let small = placeImage(source, frame, ImageFit.ScaleDown, Alignment.TopTrailing)
    @Expect(small.destination.x, Float32(70.0))
    @Expect(small.destination.w, Float32(40.0))
    let native = placeImage(source, Rect(0.0, 0.0, 10.0, 10.0), ImageFit.Original, Alignment.Center)
    @Expect(native.source.x, Float32(15.0))
    @Expect(native.source.y, Float32(5.0))
    let empty = placeImage(Rect.zero(), frame, ImageFit.Cover, Alignment.Center)
    @Expect(empty.destination.w, Float32(0.0))
    let stretch = placeImage(source, frame, ImageFit.Stretch, Alignment.Center)
    @Expect(stretch.source.w, Float32(40.0))
    @Expect(stretch.destination.h, Float32(100.0))
}

@Test
func imageConvenientSizingAvoidsDecodeDuringMeasurement(): Unit {
    clearImageCache()
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let view = ImageView("missing.png").size(240.vp, 100.vp).cornerRadius(12.vp)
    @Expect(view.measure(ctx, Size(500.0, 500.0)).w, Float32(240.0))
    @Expect(view.measure(ctx, Size(500.0, 500.0)).h, Float32(100.0))
    view.aspectRatio(2.0)
    @Expect(view.measure(ctx, Size(500.0, 500.0)).h, Float32(120.0))
    @Expect(imageCacheStats().misses, UInt64(0))
    @Expect(view.paintOutset().left, Float32(0.0))
    view.imageBackground(Color.rgb(20, 30, 40))
    @Expect(view.paintOutset().left >= Float32(0.5))
    @Expect(view.paintOutset().right >= Float32(0.5))
    let bordered = ImageView("missing.png").imageBorder(Color.rgb(50, 60, 70))
    @Expect(bordered.paintOutset().top >= Float32(0.5))
    @Expect(bordered.paintOutset().bottom >= Float32(0.5))
}

@Test
func imageViewRejectsInvalidStyleAndCropArguments(): Unit {
    let view = ImageView("missing.png")
    var rejected = 0
    try { view.aspectRatio(0.0) } catch (_: IllegalArgumentException) { rejected += 1 }
    try { view.imageOpacity(2.0) } catch (_: IllegalArgumentException) { rejected += 1 }
    try { view.cornerRadius((-1).vp) } catch (_: IllegalArgumentException) { rejected += 1 }
    try { view.decodeSize(-1) } catch (_: IllegalArgumentException) { rejected += 1 }
    try { view.sourceRect(Rect(0.0, 0.0, -1.0, 20.0)) } catch (_: IllegalArgumentException) { rejected += 1 }
    try { view.imageBorder(Color.rgb(0, 0, 0), width: -1.0) } catch (_: IllegalArgumentException) { rejected += 1 }
    try { let _ = ImageSource("bad\0path") } catch (_: IllegalArgumentException) { rejected += 1 }
    @Expect(rejected, 7)
}
