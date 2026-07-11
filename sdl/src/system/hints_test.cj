/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package sdl.system

import sdl.{CuiException, SDL_HINT_APP_ID, SDL_HINT_APP_NAME, SDL_HINT_DEFAULT, SDL_HINT_FILE_DIALOG_DRIVER, 
    SDL_HINT_IME_IMPLEMENTED_UI, SDL_HINT_MOUSE_FOCUS_CLICKTHROUGH, SDL_HINT_NORMAL, SDL_HINT_OVERRIDE, 
    SDL_HINT_RENDER_VSYNC, SDL_HINT_RETURN_KEY_HIDES_IME, SDL_HINT_VIDEO_ALLOW_SCREENSAVER, SDL_HINT_VIDEO_DRIVER, 
    SDL_HINT_WINDOWS_CLOSE_ON_ALT_F4}

@Test
func hintPriorityCodesMapSdlValues(): Unit {
    @Expect(hintPriorityCode(HintPriority.Default), SDL_HINT_DEFAULT)
    @Expect(hintPriorityCode(HintPriority.Normal), SDL_HINT_NORMAL)
    @Expect(hintPriorityCode(HintPriority.Override), SDL_HINT_OVERRIDE)
}

@Test
func hintNamesMapCommonDesktopValues(): Unit {
    @Expect(hintName(SdlHint.AppId), SDL_HINT_APP_ID)
    @Expect(hintName(SdlHint.AppName), SDL_HINT_APP_NAME)
    @Expect(hintName(SdlHint.FileDialogDriver), SDL_HINT_FILE_DIALOG_DRIVER)
    @Expect(hintName(SdlHint.ImeImplementedUi), SDL_HINT_IME_IMPLEMENTED_UI)
    @Expect(hintName(SdlHint.MouseFocusClickthrough), SDL_HINT_MOUSE_FOCUS_CLICKTHROUGH)
    @Expect(hintName(SdlHint.RenderVSync), SDL_HINT_RENDER_VSYNC)
    @Expect(hintName(SdlHint.ReturnKeyHidesIme), SDL_HINT_RETURN_KEY_HIDES_IME)
    @Expect(hintName(SdlHint.VideoAllowScreensaver), SDL_HINT_VIDEO_ALLOW_SCREENSAVER)
    @Expect(hintName(SdlHint.VideoDriver), SDL_HINT_VIDEO_DRIVER)
    @Expect(hintName(SdlHint.WindowsCloseOnAltF4), SDL_HINT_WINDOWS_CLOSE_ON_ALT_F4)
    @Expect(hintName(SdlHint.CustomHint("CUI_TEST_HINT")), "CUI_TEST_HINT")
}

@Test
func sdlHintsRoundTripCustomValue(): Unit {
    let hint = SdlHint.CustomHint("CUI_TEST_HINT_ROUND_TRIP")
    let _ = SdlHints.reset(hint)
    SdlHints.set(hint, "1")

    match (SdlHints.get(hint)) {
        case Some(value) => @Expect(value, "1")
        case None => @Fail("Custom hint should round-trip through SDL.")
    }
    @Expect(SdlHints.getBool(hint, false))
    @Expect(SdlHints.reset(hint))
}

@Test
func sdlHintsRejectEmptyCustomName(): Unit {
    @Expect(hintSetFails(SdlHint.CustomHint("")))
}

private func hintSetFails(hint: SdlHint): Bool {
    try {
        SdlHints.set(hint, "value")
        false
    } catch (e: CuiException) {
        true
    }
}
