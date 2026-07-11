/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package sdl

extend SdlWindow {
    public func setPosition(x: Int32, y: Int32): Unit {
        ensureSdl(unsafe { SDL_SetWindowPosition(windowPtr, x, y) }, "SDL_SetWindowPosition")
    }

    public func position(): WindowPosition {
        var x: Int32 = 0
        var y: Int32 = 0
        ensureSdl(unsafe { SDL_GetWindowPosition(windowPtr, inout x, inout y) }, "SDL_GetWindowPosition")
        WindowPosition(x, y)
    }

    public func setMinimumSize(width: Int32, height: Int32): Unit {
        ensureSdl(unsafe {
            SDL_SetWindowMinimumSize(windowPtr, scaledDimension(width, scale), scaledDimension(height, scale))
        }, "SDL_SetWindowMinimumSize")
    }

    public func setMaximumSize(width: Int32, height: Int32): Unit {
        ensureSdl(unsafe {
            SDL_SetWindowMaximumSize(windowPtr, scaledDimension(width, scale), scaledDimension(height, scale))
        }, "SDL_SetWindowMaximumSize")
    }

    public func setBordered(bordered: Bool): Unit {
        ensureSdl(unsafe { SDL_SetWindowBordered(windowPtr, bordered) }, "SDL_SetWindowBordered")
    }

    public func setResizable(resizable: Bool): Unit {
        ensureSdl(unsafe { SDL_SetWindowResizable(windowPtr, resizable) }, "SDL_SetWindowResizable")
    }

    public func setAlwaysOnTop(onTop: Bool): Unit {
        ensureSdl(unsafe { SDL_SetWindowAlwaysOnTop(windowPtr, onTop) }, "SDL_SetWindowAlwaysOnTop")
    }

    public func setOpacity(opacity: Float32): Unit {
        let value = clampF32(opacity, 0.0, 1.0)
        ensureSdl(unsafe { SDL_SetWindowOpacity(windowPtr, value) }, "SDL_SetWindowOpacity")
    }

    public func show(): Unit {
        ensureSdl(unsafe { SDL_ShowWindow(windowPtr) }, "SDL_ShowWindow")
    }

    public func hide(): Unit {
        ensureSdl(unsafe { SDL_HideWindow(windowPtr) }, "SDL_HideWindow")
    }

    public func raiseWindow(): Unit {
        ensureSdl(unsafe { SDL_RaiseWindow(windowPtr) }, "SDL_RaiseWindow")
    }

    public func maximize(): Unit {
        ensureSdl(unsafe { SDL_MaximizeWindow(windowPtr) }, "SDL_MaximizeWindow")
    }

    public func minimize(): Unit {
        ensureSdl(unsafe { SDL_MinimizeWindow(windowPtr) }, "SDL_MinimizeWindow")
    }

    public func restore(): Unit {
        ensureSdl(unsafe { SDL_RestoreWindow(windowPtr) }, "SDL_RestoreWindow")
    }

    public func setFullscreen(fullscreen: Bool): Unit {
        ensureSdl(unsafe { SDL_SetWindowFullscreen(windowPtr, fullscreen) }, "SDL_SetWindowFullscreen")
    }

    public func sync(): Unit {
        ensureSdl(unsafe { SDL_SyncWindow(windowPtr) }, "SDL_SyncWindow")
    }

    public func flash(operation!: WindowFlash = WindowFlash.Briefly): Unit {
        ensureSdl(unsafe { SDL_FlashWindow(windowPtr, flashCode(operation)) }, "SDL_FlashWindow")
    }

    public func setRelativeMouseMode(enabled: Bool): Unit {
        ensureSdl(unsafe { SDL_SetWindowRelativeMouseMode(windowPtr, enabled) }, "SDL_SetWindowRelativeMouseMode")
    }
}

private func flashCode(operation: WindowFlash): Int32 {
    match (operation) {
        case WindowFlash.Cancel => 0
        case WindowFlash.Briefly => 1
        case WindowFlash.UntilFocused => 2
    }
}
