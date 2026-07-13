package sdl

import std.collection.ArrayList
import sdl.text.{NativeTextColor, NativeTextException, NativeTextMetrics, NativeTextRenderer}

/**
 * Standard text sizes shared by the renderer, widgets, and applications.
 */
public struct FontSizes {
    public static let CAPTION: Float32 = 13.0
    public static let BODY: Float32 = 15.0
    public static let CONTROL: Float32 = 15.0
    public static let TITLE: Float32 = 20.0
    public static let DISPLAY: Float32 = 32.0
}

/*
 * Supersampling factor. The whole frame is drawn into an offscreen target this many times
 * larger than the window in each axis, then linearly downscaled on present. That single
 * step anti-aliases every primitive — rounded corners, diagonal strokes, circles — on the
 * GPU, with no per-widget cost. 2x (4 samples per pixel) is the sweet spot for desktop UI.
 */
private let SUPERSAMPLE: Int32 = 2

public class Renderer {
    internal let ptr: CPointer<Unit>
    private let contentScale: Float32
    private var ssTarget: CPointer<Unit> = CPointer<Unit>()
    private var ssWidth: Int32 = 0
    private var ssHeight: Int32 = 0
    private var ssEnabled: Bool
    // The live drawing scale (render coordinates -> target pixels), mirrored from every
    // SDL_SetRenderScale call. Geometry draws through the GPU scale; TEXT rasterizes at
    // this scale and draws 1:1 on the pixel grid instead (see `text`), because stretching
    // small glyph bitmaps through the render scale is what blurs it.
    private var scaleX: Float32 = 1.0
    private var scaleY: Float32 = 1.0
    private let geometry = GeometryBatch()
    private let textBackend: ?NativeTextRenderer
    private let clipStack = ArrayList<Rect>()
    // Counts text measurements since the last reset — a per-frame cost probe. Text measurement is a
    // per-frame choke point (each measure shapes the string and, with a real backend, calls
    // SDL_ttf), so benchmarks reset this at a frame boundary to see how many a tree performs.
    private var measureCount: UInt64 = 0

    internal init(ptr: CPointer<Unit>, contentScale!: Float32 = 1.0) {
        this.ptr = ptr
        this.contentScale = contentScale
        this.ssEnabled = ptr.isNotNull() && SUPERSAMPLE > 1
        this.textBackend = createTextBackend(ptr)
    }

    /**
     * A renderer backed by no SDL device. Drawing becomes a no-op, which makes it useful
     * for headless widget tests that exercise layout and event handling without a window.
     */
    public static func headless(): Renderer {
        Renderer(CPointer<Unit>())
    }

    /**
     * Begins a frame. When supersampling is available the scene is redirected into a
     * high-resolution offscreen target sized to `logicalWidth`/`logicalHeight`; otherwise
     * it draws straight to the window. Either way the target is cleared to `clearColor`.
     */
    public func beginScene(logicalWidth: Float32, logicalHeight: Float32, clearColor: Color): Unit {
        // Balanced pushClip/popClip pairs leave the stack empty between frames; clearing
        // here keeps one leaked push from clipping every later frame.
        clipStack.clear()
        if (ptr.isNull()) {
            return
        }
        if (!ssEnabled) {
            drawDirect(clearColor)
            return
        }
        var outW: Int32 = 0
        var outH: Int32 = 0
        if (!unsafe { SDL_GetRenderOutputSize(ptr, inout outW, inout outH) } || outW <= 0 || outH <= 0) {
            ssEnabled = false
            drawDirect(clearColor)
            return
        }
        let targetWidth = outW * SUPERSAMPLE
        let targetHeight = outH * SUPERSAMPLE
        if (ssTarget.isNull() || targetWidth != ssWidth || targetHeight != ssHeight) {
            allocateTarget(targetWidth, targetHeight)
        }
        if (!ssEnabled) {
            drawDirect(clearColor)
            return
        }
        ensureSdl(unsafe { SDL_SetRenderTarget(ptr, ssTarget) }, "SDL_SetRenderTarget")
        let sx = Float32(targetWidth) / max(1.0, logicalWidth)
        let sy = Float32(targetHeight) / max(1.0, logicalHeight)
        ensureSdl(unsafe { SDL_SetRenderScale(ptr, sx, sy) }, "SDL_SetRenderScale")
        scaleX = sx
        scaleY = sy
        clear(clearColor)
    }

    /**
     * Ends a frame. With supersampling active this resolves the offscreen target back onto
     * the window with linear filtering (the actual anti-aliasing step); otherwise a no-op.
     */
    public func endScene(): Unit {
        if (ptr.isNull() || !ssEnabled || ssTarget.isNull()) {
            return
        }
        ensureSdl(unsafe { SDL_SetRenderTarget(ptr, CPointer<Unit>()) }, "SDL_SetRenderTarget")
        let _ = unsafe { SDL_SetRenderScale(ptr, 1.0, 1.0) }
        scaleX = 1.0
        scaleY = 1.0
        var outW: Int32 = 0
        var outH: Int32 = 0
        let _ = unsafe { SDL_GetRenderOutputSize(ptr, inout outW, inout outH) }
        var dst = SdlFRect()
        dst.x = 0.0
        dst.y = 0.0
        dst.w = Float32(outW)
        dst.h = Float32(outH)
        let _ = unsafe { SDL_RenderTexture(ptr, ssTarget, CPointer<SdlFRect>(), inout dst) }
    }

    private func drawDirect(clearColor: Color): Unit {
        let _ = unsafe { SDL_SetRenderScale(ptr, contentScale, contentScale) }
        scaleX = contentScale
        scaleY = contentScale
        clear(clearColor)
    }

    /**
     * Releases resources the renderer owns beyond the SDL renderer itself — the
     * supersampling target and the geometry buffers. The owning window calls this on
     * close, just before destroying the SDL renderer; safe to call more than once.
     */
    internal func releaseResources(): Unit {
        if (ssTarget.isNotNull()) {
            unsafe { SDL_DestroyTexture(ssTarget) }
            ssTarget = CPointer<Unit>()
        }
        match (textBackend) {
            case Some(value) => value.close()
            case None => ()
        }
        geometry.dispose()
    }

    private func allocateTarget(width: Int32, height: Int32): Unit {
        if (ssTarget.isNotNull()) {
            unsafe { SDL_DestroyTexture(ssTarget) }
            ssTarget = CPointer<Unit>()
        }
        let tex = unsafe { SDL_CreateTexture(ptr, SDL_PIXELFORMAT_RGBA8888, SDL_TEXTUREACCESS_TARGET, width, height) }
        if (tex.isNull()) {
            ssEnabled = false
            return
        }
        let _ = unsafe { SDL_SetTextureScaleMode(tex, SDL_SCALEMODE_LINEAR) }
        let _ = unsafe { SDL_SetTextureBlendMode(tex, SDL_BLENDMODE_NONE) }
        ssTarget = tex
        ssWidth = width
        ssHeight = height
    }

    /**
     * Throws `CuiException` when SDL rejects the renderer draw color update.
     */
    public func setColor(color: Color): Unit {
        // A headless renderer (null ptr, used by widget unit tests) draws nothing rather than
        // throwing, so draw() can be exercised off-screen. The geometry paths already no-op this way.
        if (ptr.isNull()) {
            return
        }
        if (!unsafe { SDL_SetRenderDrawColor(ptr, color.r, color.g, color.b, color.a) }) {
            throw CuiException("SDL_SetRenderDrawColor failed: ${lastSdlError()}")
        }
    }

    /**
     * Throws `CuiException` when SDL cannot clear the current render target.
     */
    public func clear(color: Color): Unit {
        // Headless renderers no-op like every other draw entry point, so canvas or shell
        // code that clears explicitly stays testable off-screen.
        if (ptr.isNull()) {
            return
        }
        setColor(color)
        if (!unsafe { SDL_RenderClear(ptr) }) {
            throw CuiException("SDL_RenderClear failed: ${lastSdlError()}")
        }
    }

    public func present(): Unit {
        if (ptr.isNull()) {
            return // headless renderer: nothing to present
        }
        ensureSdl(unsafe { SDL_RenderPresent(ptr) }, "SDL_RenderPresent")
    }

    /**
     * Throws `CuiException` when the scale is invalid or SDL rejects the renderer scale.
     * Headless: the logical scale is still recorded, so text metrics stay consistent.
     */
    public func setScale(scale: Float32): Unit {
        if (scale <= 0.0) {
            throw CuiException("Renderer scale must be greater than 0.")
        }
        if (!ptr.isNull()) {
            ensureSdl(unsafe { SDL_SetRenderScale(ptr, scale, scale) }, "SDL_SetRenderScale")
        }
        scaleX = scale
        scaleY = scale
    }

    public func setVSync(vsync: Int32): Unit {
        if (ptr.isNull()) {
            return
        }
        ensureSdl(unsafe { SDL_SetRenderVSync(ptr, vsync) }, "SDL_SetRenderVSync")
    }

    public func vsync(): Int32 {
        if (ptr.isNull()) {
            return 0
        }
        var value: Int32 = 0
        ensureSdl(unsafe { SDL_GetRenderVSync(ptr, inout value) }, "SDL_GetRenderVSync")
        value
    }

    public func setViewport(rect: Rect): Unit {
        if (ptr.isNull()) {
            return
        }
        var raw = rect.toSdlRect()
        ensureSdl(unsafe { SDL_SetRenderViewport(ptr, inout raw) }, "SDL_SetRenderViewport")
    }

    public func resetViewport(): Unit {
        if (ptr.isNull()) {
            return
        }
        ensureSdl(unsafe { SDL_SetRenderViewport(ptr, CPointer<SdlRect>()) }, "SDL_SetRenderViewport")
    }

    public func viewport(): Rect {
        if (ptr.isNull()) {
            return Rect(0.0, 0.0, 0.0, 0.0)
        }
        var raw = SdlRect()
        ensureSdl(unsafe { SDL_GetRenderViewport(ptr, inout raw) }, "SDL_GetRenderViewport")
        rectFromSdl(raw)
    }

    /**
     * Narrows the active clip to the intersection of `rect` and the current clip, so nested
     * scrollports and fields clip within their ancestors. Pair every call with `popClip`.
     */
    public func pushClip(rect: Rect): Unit {
        let effective = match (currentClip()) {
            case Some(top) => top.intersection(rect)
            case None => rect
        }
        clipStack.add(effective)
        applyClip()
    }

    /** Restores the clip that was active before the matching `pushClip`. */
    public func popClip(): Unit {
        if (!clipStack.isEmpty()) {
            clipStack.remove(at: clipStack.size - 1)
        }
        applyClip()
    }

    /** The clip in effect right now, or `None` when drawing is unclipped. */
    public func currentClip(): ?Rect {
        if (clipStack.isEmpty()) {
            None
        } else {
            Some(clipStack[clipStack.size - 1])
        }
    }

    private func applyClip(): Unit {
        if (ptr.isNull()) {
            return
        }
        match (currentClip()) {
            case Some(rect) => setClip(rect)
            case None => resetClip()
        }
    }

    private func setClip(rect: Rect): Unit {
        var raw = rect.toSdlRect()
        ensureSdl(unsafe { SDL_SetRenderClipRect(ptr, inout raw) }, "SDL_SetRenderClipRect")
    }

    private func resetClip(): Unit {
        ensureSdl(unsafe { SDL_SetRenderClipRect(ptr, CPointer<SdlRect>()) }, "SDL_SetRenderClipRect")
    }

    // Headless, the logical clip stack still answers: the top entry (or a zero rect).
    public func clipRect(): Rect {
        if (ptr.isNull()) {
            return match (currentClip()) {
                case Some(rect) => rect
                case None => Rect(0.0, 0.0, 0.0, 0.0)
            }
        }
        var raw = SdlRect()
        ensureSdl(unsafe { SDL_GetRenderClipRect(ptr, inout raw) }, "SDL_GetRenderClipRect")
        rectFromSdl(raw)
    }

    public func clipEnabled(): Bool {
        if (ptr.isNull()) {
            return !clipStack.isEmpty()
        }
        unsafe { SDL_RenderClipEnabled(ptr) }
    }

    public func setColorScale(scale: Float32): Unit {
        if (ptr.isNull()) {
            return
        }
        ensureSdl(unsafe { SDL_SetRenderColorScale(ptr, scale) }, "SDL_SetRenderColorScale")
    }

    public func colorScale(): Float32 {
        if (ptr.isNull()) {
            return 1.0
        }
        var value: Float32 = 1.0
        ensureSdl(unsafe { SDL_GetRenderColorScale(ptr, inout value) }, "SDL_GetRenderColorScale")
        value
    }

    public func setColorFloat(r: Float32, g: Float32, b: Float32, a: Float32): Unit {
        if (ptr.isNull()) {
            return
        }
        ensureSdl(unsafe {
            SDL_SetRenderDrawColorFloat(ptr, clamp01(r), clamp01(g), clamp01(b), clamp01(a))
        }, "SDL_SetRenderDrawColorFloat")
    }

    public func point(x: Float32, y: Float32, color: Color): Unit {
        setColor(color)
        let _ = unsafe { SDL_RenderPoint(ptr, x, y) }
    }

    public func line(x1: Float32, y1: Float32, x2: Float32, y2: Float32, color: Color): Unit {
        setColor(color)
        let _ = unsafe { SDL_RenderLine(ptr, x1, y1, x2, y2) }
    }

    public func rect(rect: Rect, color: Color): Unit {
        setColor(color)
        var raw = rect.toSdlFRect()
        let _ = unsafe { SDL_RenderRect(ptr, inout raw) }
    }

    public func fill(rect: Rect, color: Color): Unit {
        setColor(color)
        var raw = rect.toSdlFRect()
        let _ = unsafe { SDL_RenderFillRect(ptr, inout raw) }
    }

    /**
     * A thick, round-capped line drawn as one anti-aliased stadium mesh, so strokes stay
     * smooth at any angle and consecutive polyline segments join without notches.
     */
    public func strokeLine(x1: Float32, y1: Float32, x2: Float32, y2: Float32, pen: Pen): Unit {
        geometry.strokeSegment(ptr, Point(x1, y1), Point(x2, y2), pen)
    }

    /**
     * A rectangle outline with lightly rounded joins, stroked as one anti-aliased ring.
     */
    public func strokeRect(rect: Rect, pen: Pen): Unit {
        strokeRoundedRect(rect, pen.width * 0.6, pen)
    }

    /**
     * A rounded-rectangle outline stroked as one anti-aliased ring centred on the path.
     */
    public func strokeRoundedRect(rect: Rect, radius: Float32, pen: Pen): Unit {
        geometry.strokeRoundedRect(ptr, rect, roundedRadius(rect, radius), pen)
    }

    public func fillRoundedRect(rect: Rect, radius: Float32, color: Color): Unit {
        let r = roundedRadius(rect, radius)
        if (r <= 0.5) {
            fill(rect, color)
            return
        }
        geometry.fillRoundedRect(ptr, rect, r, color)
    }

    /**
     * A rounded rectangle whose edge fades out across `feather` pixels — a single-pass
     * gradient halo, which is how soft drop shadows and focus glows are drawn banding-free.
     */
    public func fillRoundedRectSoft(rect: Rect, radius: Float32, color: Color, feather!: Float32): Unit {
        geometry.fillRoundedRectSoft(ptr, rect, roundedRadius(rect, radius), color, feather)
    }

    public func circle(cx: Float32, cy: Float32, radius: Float32, color: Color, segments!: Int64 = 0): Unit {
        geometry.strokeCircle(ptr, Point(cx, cy), radius, Pen(width: 1.0, color: color), segments)
    }

    /**
     * A circle outline drawn with the given pen. `segments` is a minimum tessellation
     * hint; arcs are always sampled finely enough to stay smooth for their radius.
     */
    public func strokeCircle(cx: Float32, cy: Float32, radius: Float32, pen: Pen, segments!: Int64 = 0): Unit {
        geometry.strokeCircle(ptr, Point(cx, cy), radius, pen, segments)
    }

    public func fillCircle(cx: Float32, cy: Float32, radius: Float32, color: Color): Unit {
        geometry.fillCircle(ptr, Point(cx, cy), radius, color)
    }

    /**
     * Draws a textured triangle strip for skinned or deformable sprites: `points` holds
     * consecutive (left, right) vertex pairs along the strip in draw coordinates, and
     * `texPoints` holds matching texture coordinates in source-image pixels. `alphas`
     * optionally gives one opacity per vertex, letting overlapping parts cross-fade.
     * All provided lists need the same even size of at least four; invalid sizes draw
     * nothing.
     *
     * Throws `CuiException` when the texture is closed.
     */
    public func texturedStrip(
        texture: Texture,
        points: ArrayList<Point>,
        texPoints: ArrayList<Point>,
        alphas!: ?ArrayList<Float32> = None
    ): Unit {
        if (texture.isClosed()) {
            throw CuiException("Cannot render a closed texture.")
        }
        geometry.texturedStrip(ptr, texture.ptr, points, texPoints, alphas, texture.width, texture.height)
    }

    /**
     * Draws UTF-8 text with the platform UI font through SDL3_ttf.
     *
     * Text takes a dedicated path through the render scale: glyphs are rasterized by
     * FreeType at the EFFECTIVE pixel size (`pointSize` x the live scale) and drawn with
     * the GPU scale reset to 1:1 at snapped target-pixel positions. Rasterizing at the
     * logical size and letting the render scale stretch the small bitmaps — as geometry
     * does — resamples every glyph twice and is what made text visibly softer and fainter
     * than the vector primitives around it. Under supersampling, positions snap to
     * multiples of `SUPERSAMPLE` so the resolve lands glyph origins on whole physical
     * pixels.
     */
    public func text(
        text: String,
        x: Float32,
        y: Float32,
        color: Color,
        pointSize!: Float32 = FontSizes.BODY
    ): Unit {
        match (textBackend) {
            case Some(value) =>
                let native = NativeTextColor(color.r, color.g, color.b, color.a)
                if (scaleX == 1.0 && scaleY == 1.0) {
                    value.draw(text, snapPixel(x, 1.0), snapPixel(y, 1.0), pointSize, native)
                    return
                }
                let step: Float32 = if (ssEnabled) {
                    Float32(SUPERSAMPLE)
                } else {
                    1.0
                }
                let px = snapPixel(x * scaleX, step)
                let py = snapPixel(y * scaleY, step)
                let _ = unsafe { SDL_SetRenderScale(ptr, 1.0, 1.0) }
                applyClipForTextPass()
                value.draw(text, px, py, pointSize * scaleY, native)
                let _ = unsafe { SDL_SetRenderScale(ptr, scaleX, scaleY) }
                applyClip()
            case None => ()
        }
    }

    /**
     * Measures UTF-8 text using the same font and point size used for drawing.
     */
    public func textWidth(text: String, pointSize!: Float32 = FontSizes.BODY): Float32 {
        textMetrics(text, pointSize).width
    }

    /**
     * Returns the standard line height for the requested point size.
     */
    public func textHeight(pointSize!: Float32 = FontSizes.BODY): Float32 {
        textMetrics("国Ag", pointSize).height
    }

    /**
     * Draws UTF-8 text centered within a rectangle.
     */
    public func textCenter(
        text: String,
        rect: Rect,
        color: Color,
        pointSize!: Float32 = FontSizes.BODY
    ): Unit {
        let metrics = textMetrics(text, pointSize)
        let tx = rect.centerX() - metrics.width / 2.0
        let ty = rect.centerY() - metrics.height / 2.0
        this.text(text, tx, ty, color, pointSize: pointSize)
    }

    /** Text measurements performed since the last reset — a per-frame text-cost probe. */
    public func textMeasureCount(): UInt64 {
        measureCount
    }

    /** Resets the text-measurement counter; call at a frame boundary to sample a single frame. */
    public func resetTextMeasureCount(): Unit {
        measureCount = 0
    }

    private func textMetrics(text: String, pointSize: Float32): NativeTextMetrics {
        measureCount += 1
        match (textBackend) {
            case Some(value) =>
                if (scaleX == 1.0 && scaleY == 1.0) {
                    return value.measure(text, pointSize)
                }
                // Measure the same scaled rasterization the text pass draws, mapped back to
                // logical units — carets, selection bands and ellipsis decisions computed
                // from these metrics then line up with the pixels actually painted.
                let scaled = value.measure(text, pointSize * scaleY)
                NativeTextMetrics(scaled.width / scaleX, scaled.height / scaleY)
            case None => NativeTextMetrics(Float32(text.size) * pointSize * 0.55, pointSize * 1.3)
        }
    }

    // While the text pass draws with the GPU scale reset to 1:1, the active clip must be
    // re-expressed in target pixels: SDL clip rectangles live in the current scaled space.
    private func applyClipForTextPass(): Unit {
        match (currentClip()) {
            case Some(rect) => setClip(Rect(rect.x * scaleX, rect.y * scaleY, rect.w * scaleX, rect.h * scaleY))
            case None => ()
        }
    }

    /**
     * Reads back the current render target and writes it to a BMP file. Useful for
     * automated visual snapshots and documentation thumbnails. Headless it is a no-op —
     * there are no pixels to read.
     *
     * Throws `CuiException` when SDL cannot read the pixels or save the file.
     */
    public func captureBmp(path: String): Unit {
        if (ptr.isNull()) {
            return
        }
        let surface = unsafe { SDL_RenderReadPixels(ptr, CPointer<SdlRect>()) }
        if (surface.isNull()) {
            throw CuiException("SDL_RenderReadPixels failed: ${lastSdlError()}")
        }
        let cPath = unsafe { LibC.mallocCString(path) }
        try (pathResource = cPath.asResource()) {
            let saved = unsafe { SDL_SaveBMP(surface, pathResource.value) }
            unsafe { SDL_DestroySurface(surface) }
            if (!saved) {
                throw CuiException("SDL_SaveBMP failed: ${lastSdlError()}")
            }
        }
    }
}

private func rectFromSdl(raw: SdlRect): Rect {
    Rect(Float32(raw.x), Float32(raw.y), Float32(raw.w), Float32(raw.h))
}

/*
 * Rounds a target-pixel coordinate to the nearest multiple of `step` (1 = whole pixels;
 * the supersample factor = positions that resolve onto whole physical pixels). Glyphs
 * drawn between pixels get smeared across two columns by the linear filter, which reads
 * as blur — snapping is what keeps stems solid.
 */
private func snapPixel(value: Float32, step: Float32): Float32 {
    let units = value / step
    let snapped = if (units >= 0.0) {
        Float32(Int64(units + 0.5))
    } else {
        -Float32(Int64(-units + 0.5))
    }
    snapped * step
}

private func clamp01(value: Float32): Float32 {
    clampF32(value, 0.0, 1.0)
}

private func roundedRadius(rect: Rect, radius: Float32): Float32 {
    clampF32(radius, 0.0, min(rect.w, rect.h) / 2.0)
}

/**
 * Throws `CuiException` when the system-font backend cannot initialize.
 */
private func createTextBackend(renderer: CPointer<Unit>): ?NativeTextRenderer {
    if (renderer.isNull()) {
        return None
    }
    try {
        Some(NativeTextRenderer(renderer))
    } catch (error: NativeTextException) {
        throw CuiException("System UI font initialization failed: ${error.message}")
    }
}
