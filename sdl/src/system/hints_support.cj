/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package sdl.system

import sdl.{CuiException, ensureSdl, SDL_HINT_APP_ID, SDL_HINT_APP_NAME, SDL_HINT_DEFAULT, SDL_HINT_FILE_DIALOG_DRIVER, 
    SDL_HINT_IME_IMPLEMENTED_UI, SDL_HINT_MOUSE_FOCUS_CLICKTHROUGH, SDL_HINT_NORMAL, SDL_HINT_OVERRIDE, 
    SDL_HINT_RENDER_VSYNC, SDL_HINT_RETURN_KEY_HIDES_IME, SDL_HINT_VIDEO_ALLOW_SCREENSAVER, SDL_HINT_VIDEO_DRIVER, 
    SDL_HINT_WINDOWS_CLOSE_ON_ALT_F4}

internal func hintPriorityCode(priority: HintPriority): Int32 {
    match (priority) {
        case HintPriority.Default => SDL_HINT_DEFAULT
        case HintPriority.Normal => SDL_HINT_NORMAL
        case HintPriority.Override => SDL_HINT_OVERRIDE
    }
}

internal func hintName(hint: SdlHint): String {
    match (hint) {
        case SdlHint.AppId => SDL_HINT_APP_ID
        case SdlHint.AppName => SDL_HINT_APP_NAME
        case SdlHint.FileDialogDriver => SDL_HINT_FILE_DIALOG_DRIVER
        case SdlHint.ImeImplementedUi => SDL_HINT_IME_IMPLEMENTED_UI
        case SdlHint.MouseFocusClickthrough => SDL_HINT_MOUSE_FOCUS_CLICKTHROUGH
        case SdlHint.RenderVSync => SDL_HINT_RENDER_VSYNC
        case SdlHint.ReturnKeyHidesIme => SDL_HINT_RETURN_KEY_HIDES_IME
        case SdlHint.VideoAllowScreensaver => SDL_HINT_VIDEO_ALLOW_SCREENSAVER
        case SdlHint.VideoDriver => SDL_HINT_VIDEO_DRIVER
        case SdlHint.WindowsCloseOnAltF4 => SDL_HINT_WINDOWS_CLOSE_ON_ALT_F4
        case SdlHint.CustomHint(value) => value
    }
}

/**
 * Throws `CuiException` when a custom SDL hint name is empty.
 */
internal func checkedHintName(hint: SdlHint): String {
    let name = hintName(hint)
    if (name.size <= 0) {
        throw CuiException("SDL hint name cannot be empty.")
    }
    name
}

internal func boolHintValue(value: Bool): String {
    if (value) {
        "1"
    } else {
        "0"
    }
}

internal func withHintStrings(hint: SdlHint, value: String, priority: HintPriority): Unit {
    let cName = unsafe { LibC.mallocCString(checkedHintName(hint)) }
    let cValue = unsafe { LibC.mallocCString(value) }
    try {
        ensureSdl(unsafe {
            SDL_SetHintWithPriority(cName, cValue, hintPriorityCode(priority))
        }, "SDL_SetHintWithPriority")
    } finally {
        unsafe {
            LibC.free(cName)
            LibC.free(cValue)
        }
    }
}
