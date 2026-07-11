/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package sdl

internal let SDL_HINT_DEFAULT: Int32 = 0
internal let SDL_HINT_NORMAL: Int32 = 1
internal let SDL_HINT_OVERRIDE: Int32 = 2
internal let SDL_HINT_APP_ID = "SDL_APP_ID"
internal let SDL_HINT_APP_NAME = "SDL_APP_NAME"
internal let SDL_HINT_FILE_DIALOG_DRIVER = "SDL_FILE_DIALOG_DRIVER"
internal let SDL_HINT_IME_IMPLEMENTED_UI = "SDL_IME_IMPLEMENTED_UI"
internal let SDL_HINT_MOUSE_FOCUS_CLICKTHROUGH = "SDL_MOUSE_FOCUS_CLICKTHROUGH"
internal let SDL_HINT_RENDER_VSYNC = "SDL_RENDER_VSYNC"
internal let SDL_HINT_RETURN_KEY_HIDES_IME = "SDL_RETURN_KEY_HIDES_IME"
internal let SDL_HINT_VIDEO_ALLOW_SCREENSAVER = "SDL_VIDEO_ALLOW_SCREENSAVER"
internal let SDL_HINT_VIDEO_DRIVER = "SDL_VIDEO_DRIVER"
internal let SDL_HINT_WINDOWS_CLOSE_ON_ALT_F4 = "SDL_WINDOWS_CLOSE_ON_ALT_F4"

foreign {
    func SDL_SetHint(name: CString, value: CString): Bool

    func SDL_SetHintWithPriority(name: CString, value: CString, priority: Int32): Bool

    func SDL_ResetHint(name: CString): Bool

    func SDL_ResetHints(): Unit

    func SDL_GetHint(name: CString): CString

    func SDL_GetHintBoolean(name: CString, defaultValue: Bool): Bool
}
