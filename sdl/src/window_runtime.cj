/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package sdl

extend SdlWindow {
    public func title(): String {
        let value = unsafe { SDL_GetWindowTitle(windowPtr) }
        if (value.isNull()) {
            ""
        } else {
            value.toString()
        }
    }

    public func windowFlags(): WindowFlags {
        windowFlagsFromRaw(unsafe { SDL_GetWindowFlags(windowPtr) })
    }

    public func sizeInPixels(): Size {
        var w: Int32 = 0
        var h: Int32 = 0
        ensureSdl(unsafe { SDL_GetWindowSizeInPixels(windowPtr, inout w, inout h) }, "SDL_GetWindowSizeInPixels")
        Size(Float32(w), Float32(h))
    }

    public func safeArea(): Rect {
        var raw = SdlRect()
        ensureSdl(unsafe { SDL_GetWindowSafeArea(windowPtr, inout raw) }, "SDL_GetWindowSafeArea")
        rectFromSdlRect(raw)
    }

    public func minimumSize(): Size {
        var w: Int32 = 0
        var h: Int32 = 0
        ensureSdl(unsafe { SDL_GetWindowMinimumSize(windowPtr, inout w, inout h) }, "SDL_GetWindowMinimumSize")
        windowSizeFromPixels(w, h, scale)
    }

    public func maximumSize(): Size {
        var w: Int32 = 0
        var h: Int32 = 0
        ensureSdl(unsafe { SDL_GetWindowMaximumSize(windowPtr, inout w, inout h) }, "SDL_GetWindowMaximumSize")
        windowSizeFromPixels(w, h, scale)
    }

    public func borderSize(): WindowBorderSize {
        var top: Int32 = 0
        var left: Int32 = 0
        var bottom: Int32 = 0
        var right: Int32 = 0
        ensureSdl(unsafe {
            SDL_GetWindowBordersSize(windowPtr, inout top, inout left, inout bottom, inout right)
        }, "SDL_GetWindowBordersSize")
        WindowBorderSize(top, left, bottom, right)
    }

    public func setAspectRatio(minimum: Float32, maximum: Float32): Unit {
        validateWindowAspectRatio(minimum, maximum)
        ensureSdl(unsafe { SDL_SetWindowAspectRatio(windowPtr, minimum, maximum) }, "SDL_SetWindowAspectRatio")
    }

    public func aspectRatio(): WindowAspectRatio {
        var minimum: Float32 = 0.0
        var maximum: Float32 = 0.0
        ensureSdl(unsafe { SDL_GetWindowAspectRatio(windowPtr, inout minimum, inout maximum) },
            "SDL_GetWindowAspectRatio")
        WindowAspectRatio(minimum, maximum)
    }

    /**
     * Throws `CuiException` when SDL cannot query the window opacity.
     */
    public func opacity(): Float32 {
        let value = unsafe { SDL_GetWindowOpacity(windowPtr) }
        if (value < 0.0) {
            throw CuiException("SDL_GetWindowOpacity failed: ${lastSdlError()}")
        }
        value
    }

    public func pixelDensity(): Float32 {
        positiveWindowFloat(unsafe { SDL_GetWindowPixelDensity(windowPtr) }, "SDL_GetWindowPixelDensity")
    }

    public func displayScale(): Float32 {
        positiveWindowFloat(unsafe { SDL_GetWindowDisplayScale(windowPtr) }, "SDL_GetWindowDisplayScale")
    }

    public func setFillDocument(fill: Bool): Unit {
        ensureSdl(unsafe { SDL_SetWindowFillDocument(windowPtr, fill) }, "SDL_SetWindowFillDocument")
    }

    public func setKeyboardGrab(grabbed: Bool): Unit {
        ensureSdl(unsafe { SDL_SetWindowKeyboardGrab(windowPtr, grabbed) }, "SDL_SetWindowKeyboardGrab")
    }

    public func setMouseGrab(grabbed: Bool): Unit {
        ensureSdl(unsafe { SDL_SetWindowMouseGrab(windowPtr, grabbed) }, "SDL_SetWindowMouseGrab")
    }

    public func keyboardGrabbed(): Bool {
        unsafe { SDL_GetWindowKeyboardGrab(windowPtr) }
    }

    public func mouseGrabbed(): Bool {
        unsafe { SDL_GetWindowMouseGrab(windowPtr) }
    }

    public func setMouseGrabRect(rect: ?Rect): Unit {
        match (rect) {
            case Some(value) =>
                var raw = value.toSdlRect()
                ensureSdl(unsafe { SDL_SetWindowMouseRect(windowPtr, inout raw) }, "SDL_SetWindowMouseRect")
            case None => ensureSdl(unsafe { SDL_SetWindowMouseRect(windowPtr, CPointer<SdlRect>()) },
                "SDL_SetWindowMouseRect")
        }
    }

    public func mouseGrabRect(): ?Rect {
        let raw = unsafe { SDL_GetWindowMouseRect(windowPtr) }
        if (raw.isNull()) {
            None
        } else {
            Some(rectFromSdlRect(unsafe { raw.read() }))
        }
    }

    public func setFocusable(focusable: Bool): Unit {
        ensureSdl(unsafe { SDL_SetWindowFocusable(windowPtr, focusable) }, "SDL_SetWindowFocusable")
    }

    public func showSystemMenu(x: Int32, y: Int32): Unit {
        ensureSdl(unsafe { SDL_ShowWindowSystemMenu(windowPtr, x, y) }, "SDL_ShowWindowSystemMenu")
    }

    public func setProgressState(state: WindowProgressState): Unit {
        ensureSdl(unsafe { SDL_SetWindowProgressState(windowPtr, windowProgressStateCode(state)) },
            "SDL_SetWindowProgressState")
    }

    /**
     * Throws `CuiException` when SDL cannot query the native taskbar progress state.
     */
    public func progressState(): WindowProgressState {
        let code = unsafe { SDL_GetWindowProgressState(windowPtr) }
        match (windowProgressStateFromCode(code)) {
            case Some(state) => state
            case None => throw CuiException("SDL_GetWindowProgressState failed: ${lastSdlError()}")
        }
    }

    public func setProgressValue(value: Float32): Unit {
        ensureSdl(unsafe { SDL_SetWindowProgressValue(windowPtr, clampF32(value, 0.0, 1.0)) },
            "SDL_SetWindowProgressValue")
    }

    /**
     * Throws `CuiException` when SDL cannot query the native taskbar progress value.
     */
    public func progressValue(): Float32 {
        let value = unsafe { SDL_GetWindowProgressValue(windowPtr) }
        if (value < 0.0) {
            throw CuiException("SDL_GetWindowProgressValue failed: ${lastSdlError()}")
        }
        value
    }
}

/**
 * Throws `CuiException` when SDL reports an invalid floating-point window query result.
 */
private func positiveWindowFloat(value: Float32, api: String): Float32 {
    if (value <= 0.0) {
        throw CuiException("${api} failed: ${lastSdlError()}")
    }
    value
}
