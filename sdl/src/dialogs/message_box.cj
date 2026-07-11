/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package sdl.dialogs

import sdl.{ensureSdl, SdlMessageBoxButtonData, SdlMessageBoxData, SdlWindow}

public enum MessageBoxKind {
    | Error
    | Warning
    | Information
}

public enum MessageBoxButtonOrder {
    | PlatformDefault
    | LeftToRight
    | RightToLeft
}

public struct MessageBoxButton {
    public let id: Int32
    public let label: String
    public let returnKeyDefault: Bool
    public let escapeKeyDefault: Bool

    public init(
        label: String,
        id!: Int32,
        returnKeyDefault!: Bool = false,
        escapeKeyDefault!: Bool = false
    ) {
        this.id = id
        this.label = label
        this.returnKeyDefault = returnKeyDefault
        this.escapeKeyDefault = escapeKeyDefault
    }
}

public struct MessageBoxColor {
    public let r: UInt8
    public let g: UInt8
    public let b: UInt8

    public init(r: UInt8, g: UInt8, b: UInt8) {
        this.r = r
        this.g = g
        this.b = b
    }
}

public struct MessageBoxColorScheme {
    public let background: MessageBoxColor
    public let text: MessageBoxColor
    public let buttonBorder: MessageBoxColor
    public let buttonBackground: MessageBoxColor
    public let buttonSelected: MessageBoxColor

    public init(
        background: MessageBoxColor,
        text: MessageBoxColor,
        buttonBorder: MessageBoxColor,
        buttonBackground: MessageBoxColor,
        buttonSelected: MessageBoxColor
    ) {
        this.background = background
        this.text = text
        this.buttonBorder = buttonBorder
        this.buttonBackground = buttonBackground
        this.buttonSelected = buttonSelected
    }
}

public struct MessageBoxOptions {
    public var title: String
    public var message: String
    public var kind: MessageBoxKind
    public var buttons: Array<MessageBoxButton>
    public var buttonOrder: MessageBoxButtonOrder
    public var colorScheme: ?MessageBoxColorScheme

    public init(title: String, message: String) {
        this.title = title
        this.message = message
        this.kind = MessageBoxKind.Information
        this.buttons = [MessageBoxButton("OK", id: 0, returnKeyDefault: true, escapeKeyDefault: true)]
        this.buttonOrder = MessageBoxButtonOrder.PlatformDefault
        this.colorScheme = None
    }
}

/**
 * Throws `CuiException` when SDL cannot show the native message box.
 */
public func showSimpleMessageBox(
    title: String,
    message: String,
    kind!: MessageBoxKind = MessageBoxKind.Information,
    window!: ?SdlWindow = None
): Unit {
    let cTitle = unsafe { LibC.mallocCString(title) }
    let cMessage = unsafe { LibC.mallocCString(message) }
    try (titleResource = cTitle.asResource()) {
        try (messageResource = cMessage.asResource()) {
            ensureSdl(unsafe {
                SDL_ShowSimpleMessageBox(messageBoxFlag(kind), titleResource.value, messageResource.value,
                    messageBoxWindow(window))
            }, "SDL_ShowSimpleMessageBox")
        }
    }
}

/**
 * Throws `CuiException` when options are invalid or SDL cannot show the native message box.
 */
public func showMessageBox(options: MessageBoxOptions, window!: ?SdlWindow = None): Int32 {
    ensureMessageBoxOptions(options)
    let cTitle = unsafe { LibC.mallocCString(options.title) }
    let cMessage = unsafe { LibC.mallocCString(options.message) }
    let rawButtons = unsafe { LibC.malloc<SdlMessageBoxButtonData>(count: options.buttons.size) }
    let rawColorScheme = allocateRawColorScheme(options.colorScheme)
    let buttonTexts = Array<CString>(options.buttons.size, {_ => nullMessageBoxCString()})
    var selectedButton: Int32 = -1

    try {
        fillRawButtons(rawButtons, buttonTexts, options.buttons)
        var raw = SdlMessageBoxData()
        raw.flags = messageBoxFlags(options.kind, options.buttonOrder)
        raw.window = messageBoxWindow(window)
        raw.title = cTitle
        raw.message = cMessage
        raw.numbuttons = Int32(options.buttons.size)
        raw.buttons = rawButtons
        raw.colorScheme = rawColorScheme
        ensureSdl(unsafe { SDL_ShowMessageBox(inout raw, inout selectedButton) }, "SDL_ShowMessageBox")
    } finally {
        freeButtonTexts(buttonTexts)
        freeRawColorScheme(rawColorScheme)
        unsafe { LibC.free(rawButtons) }
        freeCString(cTitle)
        freeCString(cMessage)
    }

    selectedButton
}
