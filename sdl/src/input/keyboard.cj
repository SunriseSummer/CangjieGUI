/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package sdl.input

import sdl.{SDL_KMOD_CAPS, SDL_KMOD_LALT, SDL_KMOD_LCTRL, SDL_KMOD_LEVEL5, SDL_KMOD_LGUI, SDL_KMOD_LSHIFT}
import sdl.{SDL_KMOD_MODE, SDL_KMOD_NUM, SDL_KMOD_RALT, SDL_KMOD_RCTRL, SDL_KMOD_RGUI, SDL_KMOD_RSHIFT, SDL_KMOD_SCROLL}

public struct KeyModifiers {
    public let raw: UInt16
    public let shift: Bool
    public let ctrl: Bool
    public let alt: Bool
    public let gui: Bool
    public let command: Bool
    public let capsLock: Bool
    public let numLock: Bool
    public let mode: Bool
    public let scrollLock: Bool
    public let level5: Bool

    public init(mask: UInt16) {
        this.raw = mask
        this.shift = modifierMaskHas(mask, SDL_KMOD_LSHIFT) || modifierMaskHas(mask, SDL_KMOD_RSHIFT)
        this.ctrl = modifierMaskHas(mask, SDL_KMOD_LCTRL) || modifierMaskHas(mask, SDL_KMOD_RCTRL)
        this.alt = modifierMaskHas(mask, SDL_KMOD_LALT) || modifierMaskHas(mask, SDL_KMOD_RALT)
        this.gui = modifierMaskHas(mask, SDL_KMOD_LGUI) || modifierMaskHas(mask, SDL_KMOD_RGUI)
        this.command = ctrl || gui
        this.capsLock = modifierMaskHas(mask, SDL_KMOD_CAPS)
        this.numLock = modifierMaskHas(mask, SDL_KMOD_NUM)
        this.mode = modifierMaskHas(mask, SDL_KMOD_MODE)
        this.scrollLock = modifierMaskHas(mask, SDL_KMOD_SCROLL)
        this.level5 = modifierMaskHas(mask, SDL_KMOD_LEVEL5)
    }
}

public class Keyboard {
    public static func modifiers(): KeyModifiers {
        KeyModifiers(unsafe { SDL_GetModState() })
    }
}

internal func modifierMaskHas(mask: UInt16, flag: UInt16): Bool {
    (mask & flag) != UInt16(0)
}
