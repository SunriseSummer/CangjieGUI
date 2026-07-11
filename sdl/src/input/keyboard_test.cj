/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package sdl.input

import sdl.{SDL_KMOD_CAPS, SDL_KMOD_LALT, SDL_KMOD_LCTRL, SDL_KMOD_RGUI, SDL_KMOD_RSHIFT}

@Test
func keyModifiersMapSdlMasks(): Unit {
    let modifiers = KeyModifiers(SDL_KMOD_LCTRL | SDL_KMOD_RSHIFT | SDL_KMOD_LALT | SDL_KMOD_CAPS)

    @Expect(modifiers.ctrl)
    @Expect(modifiers.shift)
    @Expect(modifiers.alt)
    @Expect(!modifiers.gui)
    @Expect(modifiers.command)
    @Expect(modifiers.capsLock)
    @Expect(!modifiers.scrollLock)
}

@Test
func keyModifiersTreatGuiAsCommand(): Unit {
    let modifiers = KeyModifiers(SDL_KMOD_RGUI)

    @Expect(modifiers.gui)
    @Expect(modifiers.command)
    @Expect(!modifiers.ctrl)
}
