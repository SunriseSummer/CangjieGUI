package cui.media

import cui.core.*
import sdl.{Color, Key, MouseButton, Rect, Renderer, SdlWindow, Size, Surface, TextureFlip, UiEvent, WindowSpec}
import sdl.system.FileSystem

private func testIconSource(): IconSource {
    IconSource.memory(("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"16\" height=\"16\">" +
        "<path fill=\"#000000\" d=\"M0 0h8v16H0z\"/><path fill=\"#f00000\" fill-opacity=\"0.5\" d=\"M8 0h8v16H8z\"/></svg>").toArray())
}

private func iconPixel(surface: Surface, x: Int32, y: Int32): Color {
    let size = surface.size()
    surface.readPixel(Int32(Float32(x) * size.w / 96.0), Int32(Float32(y) * size.h / 24.0))
}

@Test
func iconMeasurementIsConstrainedStableAndDoesNotDecode(): Unit {
    clearImageCache()
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let icon = Icon("__missing_measure.svg").iconSize(32.vp)
    let size = icon.measure(ctx, Size(19.0, 40.0))
    @Expect(size.w, Float32(19))
    @Expect(size.h, Float32(19))
    @Expect(icon.measure(ctx, Size(0.0, 100.0)).h, Float32(0))
    @Expect(imageCacheStats().misses, UInt64(0))
    ctx.displayScale = 2.0
    icon.iconSize(24.px)
    @Expect(icon.measure(ctx, Size(100.0, 100.0)).w, Float32(12))
    icon.iconSize(0.vp)
    icon.layout(ctx, Rect(0.0, 0.0, 50.0, 50.0))
    icon.draw(ctx)
    @Expect(imageCacheStats().misses, UInt64(0))
}

@Test
func iconSourcesValidateVariantsAndRetainCopiedTables(): Unit {
    let small = ImageSource("small.png")
    let large = ImageSource("large.png")
    let table = [IconVariant(large, 48), IconVariant(small, 24)]
    let source = IconSource.variants(table)
    table[0] = IconVariant("changed.png", 96)
    @Expect(source.select(1).identity, small.identity)
    @Expect(source.select(24).identity, small.identity)
    @Expect(source.select(25).identity, large.identity)
    @Expect(source.select(96).identity, large.identity)
    @Expect(source.withRenderingMode(IconRenderingMode.Original).select(48).identity, large.identity)
    var failures = 0
    try { let _ = IconVariant(small, 0) } catch (_: IllegalArgumentException) { failures += 1 }
    try { let _ = IconSource.variants([]) } catch (_: IllegalArgumentException) { failures += 1 }
    try { let _ = IconSource.variants([IconVariant(small, 24), IconVariant(large, 24)]) }
        catch (_: IllegalArgumentException) { failures += 1 }
    try { Icon("bad\0path") } catch (_: IllegalArgumentException) { failures += 1 }
    try { IconStyle(size: Length(-1.0, LengthUnit.Vp)) } catch (_: IllegalArgumentException) { failures += 1 }
    try { IconStyle(opacity: 1.1) } catch (_: IllegalArgumentException) { failures += 1 }
    try { IconStyle(opacity: Float32.NaN) } catch (_: IllegalArgumentException) { failures += 1 }
    @Expect(failures, 7)
}

@Test
func iconRasterSizeUsesActualRendererScaleAndClampsBeforeConversion(): Unit {
    let renderer = Renderer.headless()
    renderer.setScale(1.5)
    @Expect(iconPixels(renderer, 18.0), Int32(27))
    @Expect(iconPixels(renderer, 1.0), Int32(2))
    @Expect(iconPixels(renderer, Float32.Max), Int32(2048))
    @Expect(iconPixels(renderer, Float32.NaN), Int32(1))
}

@Test
func iconNegativeResolutionSurvivesEvictionAndExplicitInvalidationRetries(): Unit {
    clearImageCache()
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let source = IconSource("__missing_icon.svg")
    let icon = Icon(source)
    icon.layout(ctx, Rect(0.0, 0.0, 18.0, 18.0))
    icon.draw(ctx)
    for (index in 0..600) { let _ = sharedTexture(ctx.renderer, "__icon-pressure-${index}.png") }
    let misses = imageCacheStats().misses
    icon.draw(ctx)
    @Expect(imageCacheStats().misses, misses)
    @Expect(icon.loadError().isSome())
    invalidateIcon(source)
    @Expect(icon.loadError().isNone())
    icon.draw(ctx)
    @Expect(imageCacheStats().misses, misses + UInt64(1))
    icon.close()
    icon.draw(ctx)
    @Expect(icon.isClosed())
    @Expect(icon.loadError().isNone())
    @Expect(match (icon.status()) { case ImageStatus.Closed => true; case _ => false })
    clearImageCache()
}

@Test
func iconTemplateOriginalAndOpacityHaveIndependentPixelsAndSharedMasks(): Unit {
    clearImageCache()
    let path = "__icon_color_test.bmp"
    try (window = SdlWindow(WindowSpec("Icon color contract", 96, 24, supersample: 1, vsync: false), hidden: true)) {
        let ctx = UiContext(window.renderer, Theme.light())
        let source = testIconSource()
        let blue = Icon(source).foregroundColor(Color.rgb(0, 0, 240)).iconSize(16.vp)
        let green = Icon(source).foregroundColor(Color.rgb(0, 240, 0)).iconSize(16.vp)
        let original = Icon(source).renderingMode(IconRenderingMode.Original).foregroundColor(Color.rgb(0, 240, 0)).iconSize(16.vp)
        let faint = Icon(source).foregroundColor(Color.rgb(0, 0, 240)).iconOpacity(0.5).iconSize(16.vp)
        let mirrored = Icon(source, style: IconStyle(size: 16.vp, color: Some(Color.rgb(0, 0, 240)), flip: TextureFlip.Horizontal))
        let views = [blue, green, original, faint, mirrored]
        window.renderer.beginScene(96.0, 24.0, Color.rgb(0, 0, 0))
        for (i in 0..views.size) {
            views[i].layout(ctx, Rect(Float32(i * 18), 0.0, 16.0, 16.0))
            views[i].draw(ctx)
        }
        window.renderer.endScene()
        window.renderer.captureBmp(path)
        try (pixels = Surface.loadBmp(path)) {
            @Expect(iconPixel(pixels, 3, 5).b, UInt8(240))
            @Expect(iconPixel(pixels, 21, 5).g, UInt8(240))
            @Expect(iconPixel(pixels, 39, 5).g, UInt8(0)) // black stays black in Original
            @Expect(iconPixel(pixels, 48, 5).r >= UInt8(118))
            @Expect(iconPixel(pixels, 48, 5).r <= UInt8(121))
            @Expect(iconPixel(pixels, 57, 5).b >= UInt8(118))
            @Expect(iconPixel(pixels, 57, 5).b <= UInt8(121))
            @Expect(iconPixel(pixels, 75, 5).b < UInt8(125)) // flip moved half coverage to left
            @Expect(iconPixel(pixels, 84, 5).b, UInt8(240))
        }
        @Expect(imageCacheStats().misses, UInt64(2)) // one mask, one original; colors never key a texture
        @Expect(preloadIcon(window.renderer, source, pixels: 16))
        invalidateImage(source.image)
        @Expect(imageCacheStats().entries, Int64(0)) // both mask and original variants
        clearImageCache()
    }
    if (FileSystem.exists(path)) { FileSystem.remove(path) }
}

@Test
func iconFallbackKeepsPrimaryFailureAndReplaysRecordedTexture(): Unit {
    clearImageCache()
    try (window = SdlWindow(WindowSpec("Icon fallback recording", 80, 60, supersample: 1), hidden: true)) {
        let ctx = UiContext(window.renderer, Theme.light())
        let view = Icon("__missing_fallback_icon.svg").fallback(testIconSource())
        view.layout(ctx, Rect(10.0, 10.0, 18.0, 18.0))
        window.renderer.beginScene(80.0, 60.0, ctx.theme.bg)
        let recorded = window.renderer.recordCommands {=> view.draw(ctx)}
        @Expect(recorded.replay(window.renderer))
        @Expect(view.loadError().isSome())
        @Expect(match (view.status()) { case ImageStatus.Failed => true; case _ => false })
        clearImageCache()
        @Expect(!recorded.replay(window.renderer))
        window.renderer.endScene()
    }
}

@Test
func iconUsesEveryEnabledStaticDecoderInBothColorModes(): Unit {
    clearImageCache()
    try (window = SdlWindow(WindowSpec("Icon format matrix", 80, 60), hidden: true)) {
        for (extension in ["png", "bmp", "jpg", "gif", "qoi", "tga", "ico", "pcx", "ppm", "xpm", "svg"]) {
            let source = IconSource("../CangjieSDL/.dev/fixtures/images/quad.${extension}")
            @Expect(preloadIcon(window.renderer, source, pixels: 24))
            @Expect(preloadIcon(window.renderer, source.withRenderingMode(IconRenderingMode.Original), pixels: 24))
        }
        @Expect(imageCacheStats().loadFailures, UInt64(0))
        clearImageCache()
    }
}

@Test
func iconButtonUsesIconSizeTextScaleAndSemanticActivation(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let clicks = State<Int64>(0)
    let button = IconButton("__button.svg", onClick: {=> clicks.value += 1}).iconSize(32.vp).accessibilityLabel("Search").key("search")
    @Expect(button.measure(ctx, Size(200.0, 200.0)).h, Float32(52))
    @Expect(button.measure(ctx, Size(20.0, 20.0)).h, Float32(20))
    button.layout(ctx, Rect(0.0, 0.0, 52.0, 52.0))
    @Expect(ctx.performSemanticsAction("search", SemanticsAction.Activate))
    @Expect(clicks.value, 1)
    let node = ctx.semanticsSnapshot()[0]
    @Expect(node.properties.label, "Search")
    ctx.focus("search")
    @Expect(button.handle(ctx, UiEvent.KeyDown(Key.Space, false)))
    @Expect(clicks.value, 2)
    @Expect(button.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 10.0, 10.0)))
    @Expect(button.handle(ctx, UiEvent.MouseUp(MouseButton.Left, 80.0, 80.0)))
    @Expect(clicks.value, 2)
    let decorative = Icon("__decorative.svg")
    decorative.layout(ctx, Rect.zero())
    @Expect(ctx.semanticsSnapshot().size, 1)
}
