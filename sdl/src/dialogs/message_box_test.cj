/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package sdl.dialogs

import sdl.{CuiException, SDL_MESSAGEBOX_BUTTON_ESCAPEKEY_DEFAULT, SDL_MESSAGEBOX_BUTTON_RETURNKEY_DEFAULT, 
    SDL_MESSAGEBOX_BUTTONS_LEFT_TO_RIGHT, SDL_MESSAGEBOX_BUTTONS_RIGHT_TO_LEFT, SDL_MESSAGEBOX_COLOR_BACKGROUND, 
    SDL_MESSAGEBOX_COLOR_BUTTON_BACKGROUND, SDL_MESSAGEBOX_COLOR_BUTTON_BORDER, SDL_MESSAGEBOX_COLOR_BUTTON_SELECTED, 
    SDL_MESSAGEBOX_COLOR_TEXT, SDL_MESSAGEBOX_ERROR, SDL_MESSAGEBOX_INFORMATION, SDL_MESSAGEBOX_WARNING}

@Test
func messageBoxKindMapsToSdlFlags(): Unit {
    @Expect(messageBoxFlag(MessageBoxKind.Error), SDL_MESSAGEBOX_ERROR)
    @Expect(messageBoxFlag(MessageBoxKind.Warning), SDL_MESSAGEBOX_WARNING)
    @Expect(messageBoxFlag(MessageBoxKind.Information), SDL_MESSAGEBOX_INFORMATION)
}

@Test
func messageBoxOrderMapsToSdlFlags(): Unit {
    @Expect(messageBoxOrderFlag(MessageBoxButtonOrder.PlatformDefault), UInt32(0))
    @Expect(messageBoxOrderFlag(MessageBoxButtonOrder.LeftToRight), SDL_MESSAGEBOX_BUTTONS_LEFT_TO_RIGHT)
    @Expect(messageBoxOrderFlag(MessageBoxButtonOrder.RightToLeft), SDL_MESSAGEBOX_BUTTONS_RIGHT_TO_LEFT)
}

@Test
func messageBoxButtonFlagsCombineKeyboardDefaults(): Unit {
    let normal = MessageBoxButton("Later", id: 10)
    let primary = MessageBoxButton("Save", id: 20, returnKeyDefault: true)
    let cancel = MessageBoxButton("Cancel", id: 30, escapeKeyDefault: true)
    let both = MessageBoxButton("OK", id: 40, returnKeyDefault: true, escapeKeyDefault: true)

    @Expect(messageBoxButtonFlag(normal), UInt32(0))
    @Expect(messageBoxButtonFlag(primary), SDL_MESSAGEBOX_BUTTON_RETURNKEY_DEFAULT)
    @Expect(messageBoxButtonFlag(cancel), SDL_MESSAGEBOX_BUTTON_ESCAPEKEY_DEFAULT)
    @Expect(messageBoxButtonFlag(both),
        SDL_MESSAGEBOX_BUTTON_RETURNKEY_DEFAULT | SDL_MESSAGEBOX_BUTTON_ESCAPEKEY_DEFAULT)
}

@Test
func defaultMessageBoxOptionsCreateOkDialog(): Unit {
    let options = MessageBoxOptions("Title", "Message")

    @Expect(options.title, "Title")
    @Expect(options.message, "Message")
    @Expect(options.buttons.size, Int64(1))
    @Expect(options.buttons[0].id, Int32(0))
    @Expect(options.buttons[0].label, "OK")
    @Expect(options.buttons[0].returnKeyDefault)
    @Expect(options.buttons[0].escapeKeyDefault)
}

@Test
func messageBoxColorSchemeMapsToSdlOrder(): Unit {
    let scheme = MessageBoxColorScheme(
        MessageBoxColor(UInt8(1), UInt8(2), UInt8(3)),
        MessageBoxColor(UInt8(4), UInt8(5), UInt8(6)),
        MessageBoxColor(UInt8(7), UInt8(8), UInt8(9)),
        MessageBoxColor(UInt8(10), UInt8(11), UInt8(12)),
        MessageBoxColor(UInt8(13), UInt8(14), UInt8(15))
    )
    let raw = rawMessageBoxColorScheme(scheme)

    @Expect(raw.colors[SDL_MESSAGEBOX_COLOR_BACKGROUND].r, UInt8(1))
    @Expect(raw.colors[SDL_MESSAGEBOX_COLOR_TEXT].g, UInt8(5))
    @Expect(raw.colors[SDL_MESSAGEBOX_COLOR_BUTTON_BORDER].b, UInt8(9))
    @Expect(raw.colors[SDL_MESSAGEBOX_COLOR_BUTTON_BACKGROUND].r, UInt8(10))
    @Expect(raw.colors[SDL_MESSAGEBOX_COLOR_BUTTON_SELECTED].b, UInt8(15))
}

@Test
func messageBoxOptionsRejectInvalidButtons(): Unit {
    @Expect(messageBoxOptionsFail([]))
    @Expect(messageBoxOptionsFail([MessageBoxButton("", id: 1)]))
    @Expect(messageBoxOptionsFail([MessageBoxButton("A", id: 1), MessageBoxButton("B", id: 1)]))
}

private func messageBoxOptionsFail(buttons: Array<MessageBoxButton>): Bool {
    var options = MessageBoxOptions("Title", "Message")
    options.buttons = buttons
    try {
        ensureMessageBoxOptions(options)
        false
    } catch (e: CuiException) {
        true
    }
}
