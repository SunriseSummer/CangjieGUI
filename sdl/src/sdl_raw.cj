/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package sdl

internal let SDL_INIT_VIDEO: UInt32 = UInt32(0x00000020)
internal let SDL_WINDOW_FULLSCREEN: UInt64 = UInt64(0x0000000000000001)
internal let SDL_WINDOW_OPENGL: UInt64 = UInt64(0x0000000000000002)
internal let SDL_WINDOW_OCCLUDED: UInt64 = UInt64(0x0000000000000004)
internal let SDL_WINDOW_HIDDEN: UInt64 = UInt64(0x0000000000000008)
internal let SDL_WINDOW_BORDERLESS: UInt64 = UInt64(0x0000000000000010)
internal let SDL_WINDOW_RESIZABLE: UInt64 = UInt64(0x0000000000000020)
internal let SDL_WINDOW_MINIMIZED: UInt64 = UInt64(0x0000000000000040)
internal let SDL_WINDOW_MAXIMIZED: UInt64 = UInt64(0x0000000000000080)
internal let SDL_WINDOW_MOUSE_GRABBED: UInt64 = UInt64(0x0000000000000100)
internal let SDL_WINDOW_INPUT_FOCUS: UInt64 = UInt64(0x0000000000000200)
internal let SDL_WINDOW_MOUSE_FOCUS: UInt64 = UInt64(0x0000000000000400)
internal let SDL_WINDOW_EXTERNAL: UInt64 = UInt64(0x0000000000000800)
internal let SDL_WINDOW_MODAL: UInt64 = UInt64(0x0000000000001000)
internal let SDL_WINDOW_HIGH_PIXEL_DENSITY: UInt64 = UInt64(0x0000000000002000)
internal let SDL_WINDOW_MOUSE_CAPTURE: UInt64 = UInt64(0x0000000000004000)
internal let SDL_WINDOW_MOUSE_RELATIVE_MODE: UInt64 = UInt64(0x0000000000008000)
internal let SDL_WINDOW_ALWAYS_ON_TOP: UInt64 = UInt64(0x0000000000010000)
internal let SDL_WINDOW_UTILITY: UInt64 = UInt64(0x0000000000020000)
internal let SDL_WINDOW_TOOLTIP: UInt64 = UInt64(0x0000000000040000)
internal let SDL_WINDOW_POPUP_MENU: UInt64 = UInt64(0x0000000000080000)
internal let SDL_WINDOW_KEYBOARD_GRABBED: UInt64 = UInt64(0x0000000000100000)
internal let SDL_WINDOW_FILL_DOCUMENT: UInt64 = UInt64(0x0000000000200000)
internal let SDL_WINDOW_VULKAN: UInt64 = UInt64(0x0000000010000000)
internal let SDL_WINDOW_METAL: UInt64 = UInt64(0x0000000020000000)
internal let SDL_WINDOW_TRANSPARENT: UInt64 = UInt64(0x0000000040000000)
internal let SDL_WINDOW_NOT_FOCUSABLE: UInt64 = UInt64(0x0000000080000000)
internal let SDL_EVENT_QUIT: UInt32 = UInt32(0x100)
internal let SDL_EVENT_WINDOW_RESIZED: UInt32 = UInt32(0x206)
internal let SDL_EVENT_KEY_DOWN: UInt32 = UInt32(0x300)
internal let SDL_EVENT_KEY_UP: UInt32 = UInt32(0x301)
internal let SDL_EVENT_TEXT_INPUT: UInt32 = UInt32(0x303)
internal let SDL_EVENT_MOUSE_MOTION: UInt32 = UInt32(0x400)
internal let SDL_EVENT_MOUSE_BUTTON_DOWN: UInt32 = UInt32(0x401)
internal let SDL_EVENT_MOUSE_BUTTON_UP: UInt32 = UInt32(0x402)
internal let SDL_EVENT_MOUSE_WHEEL: UInt32 = UInt32(0x403)
internal let SDL_EVENT_DROP_FILE: UInt32 = UInt32(0x1000)
internal let SDL_EVENT_DROP_TEXT: UInt32 = UInt32(0x1001)
internal let SDL_EVENT_DROP_BEGIN: UInt32 = UInt32(0x1002)
internal let SDL_EVENT_DROP_COMPLETE: UInt32 = UInt32(0x1003)
internal let SDL_EVENT_DROP_POSITION: UInt32 = UInt32(0x1004)
internal let SDL_SCANCODE_A: Int32 = 4
internal let SDL_SCANCODE_Z: Int32 = 29
internal let SDL_SCANCODE_1: Int32 = 30
internal let SDL_SCANCODE_0: Int32 = 39
internal let SDL_SCANCODE_RETURN: Int32 = 40
internal let SDL_SCANCODE_ESCAPE: Int32 = 41
internal let SDL_SCANCODE_BACKSPACE: Int32 = 42
internal let SDL_SCANCODE_TAB: Int32 = 43
internal let SDL_SCANCODE_SPACE: Int32 = 44
internal let SDL_SCANCODE_HOME: Int32 = 74
internal let SDL_SCANCODE_DELETE: Int32 = 76
internal let SDL_SCANCODE_END: Int32 = 77
internal let SDL_SCANCODE_RIGHT: Int32 = 79
internal let SDL_SCANCODE_LEFT: Int32 = 80
internal let SDL_SCANCODE_DOWN: Int32 = 81
internal let SDL_SCANCODE_UP: Int32 = 82
internal let SDL_BUTTON_LEFT: UInt8 = UInt8(1)
internal let SDL_BUTTON_MIDDLE: UInt8 = UInt8(2)
internal let SDL_BUTTON_RIGHT: UInt8 = UInt8(3)
internal let SDL_BLENDMODE_NONE: UInt32 = UInt32(0)
internal let SDL_BLENDMODE_BLEND: UInt32 = UInt32(1)
internal let SDL_TEXTUREACCESS_TARGET: Int32 = 2
internal let SDL_SCALEMODE_LINEAR: Int32 = 1
internal let SDL_PIXELFORMAT_RGBA8888: UInt32 = 0x16462004
internal let SDL_KMOD_LSHIFT: UInt16 = UInt16(0x0001)
internal let SDL_KMOD_RSHIFT: UInt16 = UInt16(0x0002)
internal let SDL_KMOD_LEVEL5: UInt16 = UInt16(0x0004)
internal let SDL_KMOD_LCTRL: UInt16 = UInt16(0x0040)
internal let SDL_KMOD_RCTRL: UInt16 = UInt16(0x0080)
internal let SDL_KMOD_LALT: UInt16 = UInt16(0x0100)
internal let SDL_KMOD_RALT: UInt16 = UInt16(0x0200)
internal let SDL_KMOD_LGUI: UInt16 = UInt16(0x0400)
internal let SDL_KMOD_RGUI: UInt16 = UInt16(0x0800)
internal let SDL_KMOD_NUM: UInt16 = UInt16(0x1000)
internal let SDL_KMOD_CAPS: UInt16 = UInt16(0x2000)
internal let SDL_KMOD_MODE: UInt16 = UInt16(0x4000)
internal let SDL_KMOD_SCROLL: UInt16 = UInt16(0x8000)
internal let SDL_ORIENTATION_UNKNOWN: Int32 = 0
internal let SDL_ORIENTATION_LANDSCAPE: Int32 = 1
internal let SDL_ORIENTATION_LANDSCAPE_FLIPPED: Int32 = 2
internal let SDL_ORIENTATION_PORTRAIT: Int32 = 3
internal let SDL_ORIENTATION_PORTRAIT_FLIPPED: Int32 = 4
internal let SDL_PROGRESS_STATE_INVALID: Int32 = -1
internal let SDL_PROGRESS_STATE_NONE: Int32 = 0
internal let SDL_PROGRESS_STATE_INDETERMINATE: Int32 = 1
internal let SDL_PROGRESS_STATE_NORMAL: Int32 = 2
internal let SDL_PROGRESS_STATE_PAUSED: Int32 = 3
internal let SDL_PROGRESS_STATE_ERROR: Int32 = 4

@C
internal struct SdlRect {
    var x: Int32 = 0
    var y: Int32 = 0
    var w: Int32 = 0
    var h: Int32 = 0
}

@C
internal struct SdlFRect {
    var x: Float32 = 0.0
    var y: Float32 = 0.0
    var w: Float32 = 0.0
    var h: Float32 = 0.0
}

@C
internal struct SdlFPoint {
    var x: Float32 = 0.0
    var y: Float32 = 0.0
}

@C
internal struct SdlPoint {
    var x: Int32 = 0
    var y: Int32 = 0
}

@C
internal struct SdlDisplayMode {
    var displayId: UInt32 = 0
    var pixelFormat: UInt32 = 0
    var w: Int32 = 0
    var h: Int32 = 0
    var pixelDensity: Float32 = 0.0
    var refreshRate: Float32 = 0.0
    var refreshRateNumerator: Int32 = 0
    var refreshRateDenominator: Int32 = 0
    var internalData = CPointer<Unit>()
}

@C
internal struct SdlEvent {
    var padding = VArray<UInt8, $128>(repeat: 0)
}

@C
internal struct SdlCommonEvent {
    var eventType: UInt32 = 0
}

@C
internal struct SdlWindowEvent {
    var eventType: UInt32 = 0
    var reserved: UInt32 = 0
    var timestamp: UInt64 = 0
    var windowID: UInt32 = 0
    var data1: Int32 = 0
    var data2: Int32 = 0
}

@C
internal struct SdlKeyboardEvent {
    var eventType: UInt32 = 0
    var reserved: UInt32 = 0
    var timestamp: UInt64 = 0
    var windowID: UInt32 = 0
    var which: UInt32 = 0
    var scancode: Int32 = 0
    var key: UInt32 = 0
    var mod: UInt16 = 0
    var raw: UInt16 = 0
    var down: Bool = false
    var repeat: Bool = false
}

@C
internal struct SdlTextInputEvent {
    var eventType: UInt32 = 0
    var reserved: UInt32 = 0
    var timestamp: UInt64 = 0
    var windowID: UInt32 = 0
    var text = CPointer<UInt8>()
}

@C
internal struct SdlMouseMotionEvent {
    var eventType: UInt32 = 0
    var reserved: UInt32 = 0
    var timestamp: UInt64 = 0
    var windowID: UInt32 = 0
    var which: UInt32 = 0
    var state: UInt32 = 0
    var x: Float32 = 0.0
    var y: Float32 = 0.0
    var xrel: Float32 = 0.0
    var yrel: Float32 = 0.0
}

@C
internal struct SdlMouseButtonEvent {
    var eventType: UInt32 = 0
    var reserved: UInt32 = 0
    var timestamp: UInt64 = 0
    var windowID: UInt32 = 0
    var which: UInt32 = 0
    var button: UInt8 = 0
    var down: Bool = false
    var clicks: UInt8 = 0
    var padding: UInt8 = 0
    var x: Float32 = 0.0
    var y: Float32 = 0.0
}

@C
internal struct SdlMouseWheelEvent {
    var eventType: UInt32 = 0
    var reserved: UInt32 = 0
    var timestamp: UInt64 = 0
    var windowID: UInt32 = 0
    var which: UInt32 = 0
    var x: Float32 = 0.0
    var y: Float32 = 0.0
    var direction: UInt32 = 0
    var mouseX: Float32 = 0.0
    var mouseY: Float32 = 0.0
    var integerX: Int32 = 0
    var integerY: Int32 = 0
}

@C
internal struct SdlDropEvent {
    var eventType: UInt32 = 0
    var reserved: UInt32 = 0
    var timestamp: UInt64 = 0
    var windowID: UInt32 = 0
    var x: Float32 = 0.0
    var y: Float32 = 0.0
    var source = CPointer<UInt8>()
    var data = CPointer<UInt8>()
}
