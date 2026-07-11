/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package sdl.dialogs

import sdl.{CuiException, SDL_MESSAGEBOX_BUTTON_ESCAPEKEY_DEFAULT, SDL_MESSAGEBOX_BUTTON_RETURNKEY_DEFAULT, 
    SDL_MESSAGEBOX_BUTTONS_LEFT_TO_RIGHT, SDL_MESSAGEBOX_BUTTONS_RIGHT_TO_LEFT, SDL_MESSAGEBOX_COLOR_BACKGROUND, 
    SDL_MESSAGEBOX_COLOR_BUTTON_BACKGROUND, SDL_MESSAGEBOX_COLOR_BUTTON_BORDER, SDL_MESSAGEBOX_COLOR_BUTTON_SELECTED, 
    SDL_MESSAGEBOX_COLOR_TEXT, SDL_MESSAGEBOX_ERROR, SDL_MESSAGEBOX_INFORMATION, SDL_MESSAGEBOX_WARNING, 
    SdlMessageBoxButtonData, SdlMessageBoxColor, SdlMessageBoxColorScheme, SdlWindow}

private let MESSAGE_BOX_MAX_BUTTONS: Int64 = 32

internal func messageBoxFlag(kind: MessageBoxKind): UInt32 {
    match (kind) {
        case MessageBoxKind.Error => SDL_MESSAGEBOX_ERROR
        case MessageBoxKind.Warning => SDL_MESSAGEBOX_WARNING
        case MessageBoxKind.Information => SDL_MESSAGEBOX_INFORMATION
    }
}

internal func messageBoxOrderFlag(order: MessageBoxButtonOrder): UInt32 {
    match (order) {
        case MessageBoxButtonOrder.PlatformDefault => UInt32(0)
        case MessageBoxButtonOrder.LeftToRight => SDL_MESSAGEBOX_BUTTONS_LEFT_TO_RIGHT
        case MessageBoxButtonOrder.RightToLeft => SDL_MESSAGEBOX_BUTTONS_RIGHT_TO_LEFT
    }
}

internal func messageBoxButtonFlag(button: MessageBoxButton): UInt32 {
    var flags = UInt32(0)
    if (button.returnKeyDefault) {
        flags = flags | SDL_MESSAGEBOX_BUTTON_RETURNKEY_DEFAULT
    }
    if (button.escapeKeyDefault) {
        flags = flags | SDL_MESSAGEBOX_BUTTON_ESCAPEKEY_DEFAULT
    }
    flags
}

internal func messageBoxFlags(kind: MessageBoxKind, order: MessageBoxButtonOrder): UInt32 {
    messageBoxFlag(kind) | messageBoxOrderFlag(order)
}

internal func rawMessageBoxButton(button: MessageBoxButton, text: CString): SdlMessageBoxButtonData {
    var raw = SdlMessageBoxButtonData()
    raw.flags = messageBoxButtonFlag(button)
    raw.buttonID = button.id
    raw.text = text
    raw
}

internal func rawMessageBoxColor(color: MessageBoxColor): SdlMessageBoxColor {
    var raw = SdlMessageBoxColor()
    raw.r = color.r
    raw.g = color.g
    raw.b = color.b
    raw
}

internal func rawMessageBoxColorScheme(scheme: MessageBoxColorScheme): SdlMessageBoxColorScheme {
    var raw = SdlMessageBoxColorScheme()
    raw.colors[SDL_MESSAGEBOX_COLOR_BACKGROUND] = rawMessageBoxColor(scheme.background)
    raw.colors[SDL_MESSAGEBOX_COLOR_TEXT] = rawMessageBoxColor(scheme.text)
    raw.colors[SDL_MESSAGEBOX_COLOR_BUTTON_BORDER] = rawMessageBoxColor(scheme.buttonBorder)
    raw.colors[SDL_MESSAGEBOX_COLOR_BUTTON_BACKGROUND] = rawMessageBoxColor(scheme.buttonBackground)
    raw.colors[SDL_MESSAGEBOX_COLOR_BUTTON_SELECTED] = rawMessageBoxColor(scheme.buttonSelected)
    raw
}

/**
 * Throws `CuiException` when message box buttons are empty, too many, unlabeled, or duplicated.
 */
internal func ensureMessageBoxOptions(options: MessageBoxOptions): Unit {
    let count = options.buttons.size
    if (count <= 0) {
        throw CuiException("Message box requires at least one button.")
    }
    if (count > MESSAGE_BOX_MAX_BUTTONS) {
        throw CuiException("Message box supports at most ${MESSAGE_BOX_MAX_BUTTONS} buttons.")
    }
    for (i in 0..count) {
        ensureMessageBoxButton(options.buttons[i])
        ensureUniqueButtonId(options.buttons, i)
    }
}

internal func messageBoxWindow(window: ?SdlWindow): CPointer<Unit> {
    match (window) {
        case Some(parent) => parent.windowPtr
        case None => CPointer<Unit>()
    }
}

internal func nullMessageBoxCString(): CString {
    CString(CPointer<UInt8>())
}

internal func freeCString(value: CString): Unit {
    if (!value.isNull()) {
        unsafe { LibC.free(value) }
    }
}

internal func allocateRawColorScheme(scheme: ?MessageBoxColorScheme): CPointer<SdlMessageBoxColorScheme> {
    match (scheme) {
        case Some(value) =>
            let raw = unsafe { LibC.malloc<SdlMessageBoxColorScheme>() }
            unsafe { raw.write(rawMessageBoxColorScheme(value)) }
            raw
        case None => CPointer<SdlMessageBoxColorScheme>()
    }
}

internal func freeRawColorScheme(raw: CPointer<SdlMessageBoxColorScheme>): Unit {
    if (raw.isNotNull()) {
        unsafe { LibC.free(raw) }
    }
}

internal func fillRawButtons(
    rawButtons: CPointer<SdlMessageBoxButtonData>,
    buttonTexts: Array<CString>,
    buttons: Array<MessageBoxButton>
): Unit {
    for (i in 0..buttons.size) {
        let cText = unsafe { LibC.mallocCString(buttons[i].label) }
        buttonTexts[i] = cText
        unsafe { rawButtons.write(i, rawMessageBoxButton(buttons[i], cText)) }
    }
}

internal func freeButtonTexts(buttonTexts: Array<CString>): Unit {
    for (text in buttonTexts) {
        freeCString(text)
    }
}

/**
 * Throws `CuiException` when a button cannot be safely passed to SDL.
 */
private func ensureMessageBoxButton(button: MessageBoxButton): Unit {
    if (button.label.size <= 0) {
        throw CuiException("Message box button label cannot be empty.")
    }
}

/**
 * Throws `CuiException` when two message box buttons would report the same id.
 */
private func ensureUniqueButtonId(buttons: Array<MessageBoxButton>, index: Int64): Unit {
    for (i in 0..index) {
        if (buttons[i].id == buttons[index].id) {
            throw CuiException("Message box button ids must be unique.")
        }
    }
}
