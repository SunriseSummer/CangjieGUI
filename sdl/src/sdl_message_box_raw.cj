/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package sdl

internal let SDL_MESSAGEBOX_ERROR: UInt32 = UInt32(0x00000010)
internal let SDL_MESSAGEBOX_WARNING: UInt32 = UInt32(0x00000020)
internal let SDL_MESSAGEBOX_INFORMATION: UInt32 = UInt32(0x00000040)
internal let SDL_MESSAGEBOX_BUTTONS_LEFT_TO_RIGHT: UInt32 = UInt32(0x00000080)
internal let SDL_MESSAGEBOX_BUTTONS_RIGHT_TO_LEFT: UInt32 = UInt32(0x00000100)
internal let SDL_MESSAGEBOX_BUTTON_RETURNKEY_DEFAULT: UInt32 = UInt32(0x00000001)
internal let SDL_MESSAGEBOX_BUTTON_ESCAPEKEY_DEFAULT: UInt32 = UInt32(0x00000002)
internal let SDL_MESSAGEBOX_COLOR_BACKGROUND: Int64 = 0
internal let SDL_MESSAGEBOX_COLOR_TEXT: Int64 = 1
internal let SDL_MESSAGEBOX_COLOR_BUTTON_BORDER: Int64 = 2
internal let SDL_MESSAGEBOX_COLOR_BUTTON_BACKGROUND: Int64 = 3
internal let SDL_MESSAGEBOX_COLOR_BUTTON_SELECTED: Int64 = 4

@C
internal struct SdlMessageBoxButtonData {
    var flags: UInt32 = UInt32(0)
    var buttonID: Int32 = 0
    var text = CString(CPointer<UInt8>())
}

@C
internal struct SdlMessageBoxColor {
    var r: UInt8 = UInt8(0)
    var g: UInt8 = UInt8(0)
    var b: UInt8 = UInt8(0)
}

@C
internal struct SdlMessageBoxColorScheme {
    var colors = VArray<SdlMessageBoxColor, $5>(repeat: SdlMessageBoxColor())
}

@C
internal struct SdlMessageBoxData {
    var flags: UInt32 = UInt32(0)
    var window = CPointer<Unit>()
    var title = CString(CPointer<UInt8>())
    var message = CString(CPointer<UInt8>())
    var numbuttons: Int32 = 0
    var buttons = CPointer<SdlMessageBoxButtonData>()
    var colorScheme = CPointer<SdlMessageBoxColorScheme>()
}

foreign {
    func SDL_ShowMessageBox(messageboxdata: CPointer<SdlMessageBoxData>, buttonid: CPointer<Int32>): Bool

    func SDL_ShowSimpleMessageBox(flags: UInt32, title: CString, message: CString, window: CPointer<Unit>): Bool
}
