/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package sdl.ffi

import std.collection.ArrayList
import std.math.abs

private let DEFAULT_POINT_SIZE: Float32 = 15.0
private let FONT_SIZE_EPSILON: Float32 = 0.01

protected class SdlFfiException <: Exception {
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

    public init(renderer: CPointer<Unit>) {
        if (!unsafe { TTF_Init() }) {
            throw SdlFfiException("TTF_Init failed: ${lastNativeError()}")
        }
        let opened = tryOpenSystemFont(DEFAULT_POINT_SIZE)
        if (let Some(value) <- opened) {
            this.fontPath = value.path
            fonts.add(value.font)
        } else {
            unsafe { TTF_Quit() }
            throw SdlFfiException("No supported system UI font was found: ${lastNativeError()}")
        }
        let createdEngine = unsafe { TTF_CreateRendererTextEngine(renderer) }
        this.engine = createdEngine
        if (createdEngine.isNull()) {
            closeFonts()
            unsafe { TTF_Quit() }
            throw SdlFfiException("TTF_CreateRendererTextEngine failed: ${lastNativeError()}")
        }
        try {
            fonts[0].attach(engine)
        } catch (error: SdlFfiException) {
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
        let font = fontFor(pointSize)
        let cText = unsafe { LibC.mallocCString(text) }
        try (textResource = cText.asResource()) {
            ensureNative(unsafe {
                TTF_SetTextString(font.textPointer(), textResource.value, UIntNative(text.size))
            }, "TTF_SetTextString")
            ensureNative(unsafe {
                TTF_SetTextColor(font.textPointer(), color.red, color.green, color.blue, color.alpha)
            }, "TTF_SetTextColor")
            ensureNative(unsafe { TTF_DrawRendererText(font.textPointer(), x, y) }, "TTF_DrawRendererText")
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
        font.attach(engine)
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

private class NativeFont {
    let pointSize: Float32
    private let font: CPointer<Unit>
    private var text = CPointer<Unit>()
    private var closed: Bool = false

    init(font: CPointer<Unit>, pointSize: Float32) {
        this.font = font
        this.pointSize = pointSize
    }

    func attach(engine: CPointer<Unit>): Unit {
        let createdText = unsafe {
            TTF_CreateText(engine, font, CString(CPointer<UInt8>()), UIntNative(0))
        }
        if (createdText.isNull()) {
            throw SdlFfiException("TTF_CreateText failed: ${lastNativeError()}")
        }
        text = createdText
    }

    func pointer(): CPointer<Unit> {
        font
    }

    func textPointer(): CPointer<Unit> {
        text
    }

    func close(): Unit {
        if (closed) {
            return
        }
        closed = true
        unsafe {
            if (text.isNotNull()) {
                TTF_DestroyText(text)
            }
            TTF_CloseFont(font)
        }
        text = CPointer<Unit>()
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

private func openFont(path: String, pointSize: Float32): NativeFont {
    let cPath = unsafe { LibC.mallocCString(path) }
    var font = CPointer<Unit>()
    try (pathResource = cPath.asResource()) {
        font = unsafe { TTF_OpenFont(pathResource.value, pointSize) }
        if (font.isNull()) {
            throw SdlFfiException("TTF_OpenFont failed: ${lastNativeError()}")
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
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
    ]
}

private func normalizePointSize(pointSize: Float32): Float32 {
    if (pointSize <= 0.0) {
        DEFAULT_POINT_SIZE
    } else {
        pointSize
    }
}

private func ensureNative(ok: Bool, api: String): Unit {
    if (!ok) {
        throw SdlFfiException("${api} failed: ${lastNativeError()}")
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
