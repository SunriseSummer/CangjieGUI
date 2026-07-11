/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package sdl

import sdl.ffi.{NativeTextColor, NativeTextMetrics, NativeTextRenderer, SdlFfiException}

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
    private let geometry = GeometryBatch()
    private let textBackend: ?NativeTextRenderer

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
        if (!unsafe { SDL_SetRenderDrawColor(ptr, color.r, color.g, color.b, color.a) }) {
            throw CuiException("SDL_SetRenderDrawColor failed: ${lastSdlError()}")
        }
    }

    /**
     * Throws `CuiException` when SDL cannot clear the current render target.
     */
    public func clear(color: Color): Unit {
        setColor(color)
        if (!unsafe { SDL_RenderClear(ptr) }) {
            throw CuiException("SDL_RenderClear failed: ${lastSdlError()}")
        }
    }

    public func present(): Unit {
        ensureSdl(unsafe { SDL_RenderPresent(ptr) }, "SDL_RenderPresent")
    }

    /**
     * Throws `CuiException` when the scale is invalid or SDL rejects the renderer scale.
     */
    public func setScale(scale: Float32): Unit {
        if (scale <= 0.0) {
            throw CuiException("Renderer scale must be greater than 0.")
        }
        ensureSdl(unsafe { SDL_SetRenderScale(ptr, scale, scale) }, "SDL_SetRenderScale")
    }

    public func setVSync(vsync: Int32): Unit {
        ensureSdl(unsafe { SDL_SetRenderVSync(ptr, vsync) }, "SDL_SetRenderVSync")
    }

    public func vsync(): Int32 {
        var value: Int32 = 0
        ensureSdl(unsafe { SDL_GetRenderVSync(ptr, inout value) }, "SDL_GetRenderVSync")
        value
    }

    public func setViewport(rect: Rect): Unit {
        var raw = rect.toSdlRect()
        ensureSdl(unsafe { SDL_SetRenderViewport(ptr, inout raw) }, "SDL_SetRenderViewport")
    }

    public func resetViewport(): Unit {
        ensureSdl(unsafe { SDL_SetRenderViewport(ptr, CPointer<SdlRect>()) }, "SDL_SetRenderViewport")
    }

    public func viewport(): Rect {
        var raw = SdlRect()
        ensureSdl(unsafe { SDL_GetRenderViewport(ptr, inout raw) }, "SDL_GetRenderViewport")
        rectFromSdl(raw)
    }

    public func setClip(rect: Rect): Unit {
        var raw = rect.toSdlRect()
        ensureSdl(unsafe { SDL_SetRenderClipRect(ptr, inout raw) }, "SDL_SetRenderClipRect")
    }

    public func resetClip(): Unit {
        ensureSdl(unsafe { SDL_SetRenderClipRect(ptr, CPointer<SdlRect>()) }, "SDL_SetRenderClipRect")
    }

    public func clipRect(): Rect {
        var raw = SdlRect()
        ensureSdl(unsafe { SDL_GetRenderClipRect(ptr, inout raw) }, "SDL_GetRenderClipRect")
        rectFromSdl(raw)
    }

    public func clipEnabled(): Bool {
        unsafe { SDL_RenderClipEnabled(ptr) }
    }

    public func setColorScale(scale: Float32): Unit {
        ensureSdl(unsafe { SDL_SetRenderColorScale(ptr, scale) }, "SDL_SetRenderColorScale")
    }

    public func colorScale(): Float32 {
        var value: Float32 = 1.0
        ensureSdl(unsafe { SDL_GetRenderColorScale(ptr, inout value) }, "SDL_GetRenderColorScale")
        value
    }

    public func setColorFloat(r: Float32, g: Float32, b: Float32, a: Float32): Unit {
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
     * Draws UTF-8 text with the platform UI font through SDL3_ttf.
     */
    public func text(
        text: String,
        x: Float32,
        y: Float32,
        color: Color,
        pointSize!: Float32 = FontSizes.BODY
    ): Unit {
        match (textBackend) {
            case Some(value) => value.draw(text, x, y, pointSize, NativeTextColor(color.r, color.g, color.b, color.a))
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

    private func textMetrics(text: String, pointSize: Float32): NativeTextMetrics {
        match (textBackend) {
            case Some(value) => value.measure(text, pointSize)
            case None => NativeTextMetrics(Float32(text.size) * pointSize * 0.55, pointSize * 1.3)
        }
    }

    /**
     * Reads back the current render target and writes it to a BMP file. Useful for
     * automated visual snapshots and documentation thumbnails.
     *
     * Throws `CuiException` when SDL cannot read the pixels or save the file.
     */
    public func captureBmp(path: String): Unit {
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

private func clamp01(value: Float32): Float32 {
    clampF32(value, 0.0, 1.0)
}

private func roundedRadius(rect: Rect, radius: Float32): Float32 {
    clampF32(radius, 0.0, min(rect.w, rect.h) / 2.0)
}

private func createTextBackend(renderer: CPointer<Unit>): ?NativeTextRenderer {
    if (renderer.isNull()) {
        return None
    }
    try {
        Some(NativeTextRenderer(renderer))
    } catch (error: SdlFfiException) {
        throw CuiException("System UI font initialization failed: ${error.message}")
    }
}
