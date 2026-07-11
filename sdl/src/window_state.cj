/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package sdl

public enum WindowProgressState {
    | Inactive
    | Indeterminate
    | Normal
    | Paused
    | Error
}

public struct WindowAspectRatio {
    public let minimum: Float32
    public let maximum: Float32

    public init(minimum: Float32, maximum: Float32) {
        this.minimum = minimum
        this.maximum = maximum
    }
}

public struct WindowBorderSize {
    public let top: Int32
    public let left: Int32
    public let bottom: Int32
    public let right: Int32

    public init(top: Int32, left: Int32, bottom: Int32, right: Int32) {
        this.top = top
        this.left = left
        this.bottom = bottom
        this.right = right
    }
}

public struct WindowFlags {
    public let raw: UInt64
    public let fullscreen: Bool
    public let opengl: Bool
    public let occluded: Bool
    public let hidden: Bool
    public let borderless: Bool
    public let resizable: Bool
    public let minimized: Bool
    public let maximized: Bool
    public let mouseGrabbed: Bool
    public let inputFocus: Bool
    public let mouseFocus: Bool
    public let external: Bool
    public let modal: Bool
    public let highPixelDensity: Bool
    public let mouseCaptured: Bool
    public let relativeMouseMode: Bool
    public let alwaysOnTop: Bool
    public let utility: Bool
    public let tooltip: Bool
    public let popupMenu: Bool
    public let keyboardGrabbed: Bool
    public let fillDocument: Bool
    public let vulkan: Bool
    public let metal: Bool
    public let transparent: Bool
    public let notFocusable: Bool

    public init(raw: UInt64) {
        this.raw = raw
        this.fullscreen = hasWindowFlag(raw, SDL_WINDOW_FULLSCREEN)
        this.opengl = hasWindowFlag(raw, SDL_WINDOW_OPENGL)
        this.occluded = hasWindowFlag(raw, SDL_WINDOW_OCCLUDED)
        this.hidden = hasWindowFlag(raw, SDL_WINDOW_HIDDEN)
        this.borderless = hasWindowFlag(raw, SDL_WINDOW_BORDERLESS)
        this.resizable = hasWindowFlag(raw, SDL_WINDOW_RESIZABLE)
        this.minimized = hasWindowFlag(raw, SDL_WINDOW_MINIMIZED)
        this.maximized = hasWindowFlag(raw, SDL_WINDOW_MAXIMIZED)
        this.mouseGrabbed = hasWindowFlag(raw, SDL_WINDOW_MOUSE_GRABBED)
        this.inputFocus = hasWindowFlag(raw, SDL_WINDOW_INPUT_FOCUS)
        this.mouseFocus = hasWindowFlag(raw, SDL_WINDOW_MOUSE_FOCUS)
        this.external = hasWindowFlag(raw, SDL_WINDOW_EXTERNAL)
        this.modal = hasWindowFlag(raw, SDL_WINDOW_MODAL)
        this.highPixelDensity = hasWindowFlag(raw, SDL_WINDOW_HIGH_PIXEL_DENSITY)
        this.mouseCaptured = hasWindowFlag(raw, SDL_WINDOW_MOUSE_CAPTURE)
        this.relativeMouseMode = hasWindowFlag(raw, SDL_WINDOW_MOUSE_RELATIVE_MODE)
        this.alwaysOnTop = hasWindowFlag(raw, SDL_WINDOW_ALWAYS_ON_TOP)
        this.utility = hasWindowFlag(raw, SDL_WINDOW_UTILITY)
        this.tooltip = hasWindowFlag(raw, SDL_WINDOW_TOOLTIP)
        this.popupMenu = hasWindowFlag(raw, SDL_WINDOW_POPUP_MENU)
        this.keyboardGrabbed = hasWindowFlag(raw, SDL_WINDOW_KEYBOARD_GRABBED)
        this.fillDocument = hasWindowFlag(raw, SDL_WINDOW_FILL_DOCUMENT)
        this.vulkan = hasWindowFlag(raw, SDL_WINDOW_VULKAN)
        this.metal = hasWindowFlag(raw, SDL_WINDOW_METAL)
        this.transparent = hasWindowFlag(raw, SDL_WINDOW_TRANSPARENT)
        this.notFocusable = hasWindowFlag(raw, SDL_WINDOW_NOT_FOCUSABLE)
    }
}

internal func windowFlagsFromRaw(raw: UInt64): WindowFlags {
    WindowFlags(raw)
}

internal func windowSizeFromPixels(w: Int32, h: Int32, scale: Float32): Size {
    let safeScale = normalizedScale(scale)
    Size(Float32(w) / safeScale, Float32(h) / safeScale)
}

internal func rectFromSdlRect(raw: SdlRect): Rect {
    Rect(Float32(raw.x), Float32(raw.y), Float32(raw.w), Float32(raw.h))
}

internal func windowProgressStateFromCode(code: Int32): ?WindowProgressState {
    if (code == SDL_PROGRESS_STATE_NONE) {
        Some(WindowProgressState.Inactive)
    } else if (code == SDL_PROGRESS_STATE_INDETERMINATE) {
        Some(WindowProgressState.Indeterminate)
    } else if (code == SDL_PROGRESS_STATE_NORMAL) {
        Some(WindowProgressState.Normal)
    } else if (code == SDL_PROGRESS_STATE_PAUSED) {
        Some(WindowProgressState.Paused)
    } else if (code == SDL_PROGRESS_STATE_ERROR) {
        Some(WindowProgressState.Error)
    } else if (code == SDL_PROGRESS_STATE_INVALID) {
        None
    } else {
        None
    }
}

internal func windowProgressStateCode(state: WindowProgressState): Int32 {
    match (state) {
        case WindowProgressState.Inactive => SDL_PROGRESS_STATE_NONE
        case WindowProgressState.Indeterminate => SDL_PROGRESS_STATE_INDETERMINATE
        case WindowProgressState.Normal => SDL_PROGRESS_STATE_NORMAL
        case WindowProgressState.Paused => SDL_PROGRESS_STATE_PAUSED
        case WindowProgressState.Error => SDL_PROGRESS_STATE_ERROR
    }
}

/**
 * Throws `CuiException` when the aspect ratio bounds cannot be passed safely to SDL.
 */
internal func validateWindowAspectRatio(minimum: Float32, maximum: Float32): Unit {
    if (minimum < 0.0 || maximum < 0.0) {
        throw CuiException("Window aspect ratio bounds cannot be negative.")
    }
    if (minimum > 0.0 && maximum > 0.0 && minimum > maximum) {
        throw CuiException("Window minimum aspect ratio cannot exceed maximum aspect ratio.")
    }
}

private func hasWindowFlag(raw: UInt64, flag: UInt64): Bool {
    (raw & flag) != UInt64(0)
}
