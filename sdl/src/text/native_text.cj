package sdl.text

import std.collection.ArrayList
import std.math.abs

private let DEFAULT_POINT_SIZE: Float32 = 15.0
private let FONT_SIZE_EPSILON: Float32 = 0.01

protected class NativeTextException <: Exception {
    public init(message: String) {
        super(message)
    }
}

protected struct NativeTextMetrics {
    public let width: Float32
    public let height: Float32

    public init(width: Float32, height: Float32) {
        this.width = width
        this.height = height
    }
}

protected struct NativeTextColor {
    let red: UInt8
    let green: UInt8
    let blue: UInt8
    let alpha: UInt8

    public init(red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8) {
        this.red = red
        this.green = green
        this.blue = blue
        this.alpha = alpha
    }
}

protected class NativeTextRenderer {
    private let engine: CPointer<Unit>
    private let fontPath: String
    private let fonts = ArrayList<NativeFont>()
    private var closed: Bool = false

    /**
     * Throws `NativeTextException` when SDL_ttf cannot initialize the system-font backend.
     */
    public init(renderer: CPointer<Unit>) {
        if (!unsafe { TTF_Init() }) {
            throw NativeTextException("TTF_Init failed: ${lastNativeError()}")
        }
        let opened = tryOpenSystemFont(DEFAULT_POINT_SIZE)
        if (let Some(value) <- opened) {
            this.fontPath = value.path
            fonts.add(value.font)
        } else {
            unsafe { TTF_Quit() }
            throw NativeTextException("No supported system UI font was found: ${lastNativeError()}")
        }
        let createdEngine = unsafe { TTF_CreateRendererTextEngine(renderer) }
        this.engine = createdEngine
        if (createdEngine.isNull()) {
            closeFonts()
            unsafe { TTF_Quit() }
            throw NativeTextException("TTF_CreateRendererTextEngine failed: ${lastNativeError()}")
        }
        try {
            fonts[0].attach(engine)
        } catch (error: NativeTextException) {
            closeFonts()
            unsafe {
                TTF_DestroyRendererTextEngine(engine)
                TTF_Quit()
            }
            throw error
        }
    }

    public func measure(text: String, pointSize: Float32): NativeTextMetrics {
        let font = fontFor(pointSize)
        let cText = unsafe { LibC.mallocCString(text) }
        var metrics = NativeTextMetrics(0.0, 0.0)
        try (textResource = cText.asResource()) {
            var width: Int32 = 0
            var height: Int32 = 0
            ensureNative(unsafe {
                TTF_GetStringSize(font.pointer(), textResource.value, UIntNative(text.size), inout width, inout height)
            }, "TTF_GetStringSize")
            metrics = NativeTextMetrics(Float32(width), Float32(height))
        }
        metrics
    }

    public func draw(
        text: String,
        x: Float32,
        y: Float32,
        pointSize: Float32,
        color: NativeTextColor
    ): Unit {
        if (text.isEmpty()) {
            return
        }
        // The font reuses a cached, already-shaped text object for `text`, so an unchanged string
        // (every visible label during a scroll) is not re-shaped by SDL_ttf — only redrawn.
        fontFor(pointSize).drawText(text, x, y, color)
    }

    /*
     * Total shaping operations across all sizes since the last reset — each is one TTF_CreateText, a
     * shaped-text cache miss. A per-frame text-cost probe: on a warm cache this stays flat while draw
     * calls scale with frames, which is the caching doing its job. Summed on demand over the fonts.
     */
    public func shapeCount(): UInt64 {
        var total: UInt64 = 0
        for (font in fonts) {
            total += font.shapeCount
        }
        total
    }

    public func resetShapeCount(): Unit {
        for (font in fonts) {
            font.shapeCount = 0
        }
    }

    public func familyName(): String {
        let name = unsafe { TTF_GetFontFamilyName(fonts[0].pointer()) }
        if (name.isNull()) {
            "System UI"
        } else {
            name.toString()
        }
    }

    public func path(): String {
        fontPath
    }

    public func close(): Unit {
        if (closed) {
            return
        }
        closed = true
        closeFonts()
        unsafe {
            TTF_DestroyRendererTextEngine(engine)
            TTF_Quit()
        }
    }

    private func fontFor(pointSize: Float32): NativeFont {
        let normalized = normalizePointSize(pointSize)
        for (font in fonts) {
            if (abs(font.pointSize - normalized) < FONT_SIZE_EPSILON) {
                return font
            }
        }
        let font = openFont(fontPath, normalized)
        // Close the freshly opened font if it cannot attach: it is not yet in `fonts`, so closeFonts
        // would never reach it, and there is no finalizer — a failed attach would otherwise leak the
        // native TTF_Font handle. Mirrors the constructor, which closes fonts on an attach failure.
        try {
            font.attach(engine)
        } catch (error: NativeTextException) {
            font.close()
            throw error
        }
        fonts.add(font)
        font
    }

    private func closeFonts(): Unit {
        var index = fonts.size - 1
        while (index >= 0) {
            fonts[index].close()
            index -= 1
        }
        fonts.clear()
    }
}

// One shaped, ready-to-draw text object plus the colour last applied to it, so redrawing the same
// string in the same colour next frame skips even the colour update.
internal class ShapedText {
    let pointer: CPointer<Unit>
    var colorKey: Int64 = -1

    init(pointer: CPointer<Unit>) {
        this.pointer = pointer
    }
}

// Packs an RGBA colour into one Int64 so a text object's current colour compares in a single check.
private func colorKey(color: NativeTextColor): Int64 {
    (Int64(color.red) << 24) | (Int64(color.green) << 16) | (Int64(color.blue) << 8) | Int64(color.alpha)
}

private class NativeFont {
    let pointSize: Float32
    private let font: CPointer<Unit>
    private var engine = CPointer<Unit>()
    // Already-shaped text objects for this size, reused across frames; a miss is the only path that
    // shapes a string. Bounded and self-freeing: an evicted object's TTF_Text is destroyed.
    private let cache: GenerationCache<ShapedText>
    // Shaped-text cache misses (real TTF_CreateText calls) since the last reset. No access modifier
    // so the renderer can total it as a per-frame text-cost probe.
    var shapeCount: UInt64 = 0
    private var closed: Bool = false

    init(font: CPointer<Unit>, pointSize: Float32) {
        this.font = font
        this.pointSize = pointSize
        this.cache = GenerationCache<ShapedText>(SHAPED_TEXT_CACHE_CAP) {
            shaped => if (shaped.pointer.isNotNull()) {
                unsafe { TTF_DestroyText(shaped.pointer) }
            }
        }
    }

    /**
     * Binds this font to the shared text engine and fails fast — as the previous eager text object
     * did — if the engine cannot shape for it. Throws `NativeTextException` on failure.
     */
    func attach(engine: CPointer<Unit>): Unit {
        this.engine = engine
        let probe = unsafe { TTF_CreateText(engine, font, CString(CPointer<UInt8>()), UIntNative(0)) }
        if (probe.isNull()) {
            throw NativeTextException("TTF_CreateText failed: ${lastNativeError()}")
        }
        unsafe { TTF_DestroyText(probe) }
    }

    /**
     * Draws `text` at (x, y) in `color`, reusing a cached shaped-text object so an unchanged string
     * is not re-shaped by SDL_ttf — only a cache miss shapes. Throws `NativeTextException` on failure.
     */
    func drawText(text: String, x: Float32, y: Float32, color: NativeTextColor): Unit {
        let shaped = obtainShaped(text)
        let wanted = colorKey(color)
        // The text object remembers its colour, so only a genuine change touches SDL_ttf again.
        if (shaped.colorKey != wanted) {
            ensureNative(unsafe {
                TTF_SetTextColor(shaped.pointer, color.red, color.green, color.blue, color.alpha)
            }, "TTF_SetTextColor")
            shaped.colorKey = wanted
        }
        ensureNative(unsafe { TTF_DrawRendererText(shaped.pointer, x, y) }, "TTF_DrawRendererText")
    }

    // The shaped text object for `text`, created and cached on first use. Only this miss path calls
    // TTF_CreateText (the shaping cost); repeats hit the cache.
    private func obtainShaped(text: String): ShapedText {
        match (cache.get(text)) {
            case Some(shaped) => return shaped
            case None => ()
        }
        let cText = unsafe { LibC.mallocCString(text) }
        var pointer = CPointer<Unit>()
        try (textResource = cText.asResource()) {
            pointer = unsafe { TTF_CreateText(engine, font, textResource.value, UIntNative(text.size)) }
        }
        if (pointer.isNull()) {
            throw NativeTextException("TTF_CreateText failed: ${lastNativeError()}")
        }
        shapeCount += 1
        let shaped = ShapedText(pointer)
        cache.put(text, shaped)
        shaped
    }

    func pointer(): CPointer<Unit> {
        font
    }

    func close(): Unit {
        if (closed) {
            return
        }
        closed = true
        cache.clear()
        unsafe { TTF_CloseFont(font) }
    }
}

private struct OpenedFont {
    let path: String
    let font: NativeFont

    init(path: String, font: NativeFont) {
        this.path = path
        this.font = font
    }
}

private func tryOpenSystemFont(pointSize: Float32): ?OpenedFont {
    for (path in systemFontCandidates()) {
        let cPath = unsafe { LibC.mallocCString(path) }
        try (pathResource = cPath.asResource()) {
            let pointer = unsafe { TTF_OpenFont(pathResource.value, pointSize) }
            if (pointer.isNotNull()) {
                return Some(OpenedFont(path, NativeFont(pointer, pointSize)))
            }
        }
    }
    None
}

/**
 * Throws `NativeTextException` when SDL_ttf cannot open the selected system font.
 */
private func openFont(path: String, pointSize: Float32): NativeFont {
    let cPath = unsafe { LibC.mallocCString(path) }
    var font = CPointer<Unit>()
    try (pathResource = cPath.asResource()) {
        font = unsafe { TTF_OpenFont(pathResource.value, pointSize) }
        if (font.isNull()) {
            throw NativeTextException("TTF_OpenFont failed: ${lastNativeError()}")
        }
    }
    NativeFont(font, pointSize)
}

private func systemFontCandidates(): Array<String> {
    [
        "C:\\Windows\\Fonts\\msyh.ttc",
        "C:\\Windows\\Fonts\\segoeui.ttf",
        "/System/Library/Fonts/PingFang.ttc",
        "/System/Library/Fonts/SFNS.ttf",
        "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",
        "/usr/share/fonts/truetype/noto/NotoSansCJK-Regular.ttc",
        "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        "/usr/share/fonts/noto-cjk/NotoSansCJK-Light.ttc",
        "/usr/share/fonts/OTF/NotoSansCJKsc-Medium.otf",
        "/usr/share/fonts/adobe-source-han-sans/SourceHanSansCN-Light.otf"
    ]
}

private func normalizePointSize(pointSize: Float32): Float32 {
    if (pointSize <= 0.0) {
        DEFAULT_POINT_SIZE
    } else {
        pointSize
    }
}

/**
 * Throws `NativeTextException` when an SDL_ttf operation reports failure.
 */
private func ensureNative(ok: Bool, api: String): Unit {
    if (!ok) {
        throw NativeTextException("${api} failed: ${lastNativeError()}")
    }
}

private func lastNativeError(): String {
    let error = unsafe { SDL_GetError() }
    if (error.isNull()) {
        "unknown SDL_ttf error"
    } else {
        error.toString()
    }
}
