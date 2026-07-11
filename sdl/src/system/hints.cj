/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package sdl.system

public enum HintPriority {
    | Default
    | Normal
    | Override
}

public enum SdlHint {
    | AppId
    | AppName
    | FileDialogDriver
    | ImeImplementedUi
    | MouseFocusClickthrough
    | RenderVSync
    | ReturnKeyHidesIme
    | VideoAllowScreensaver
    | VideoDriver
    | WindowsCloseOnAltF4
    | CustomHint(String)
}

public struct SdlHintSetting {
    public let hint: SdlHint
    public let value: String
    public let priority: HintPriority

    public init(hint: SdlHint, value: String, priority!: HintPriority = HintPriority.Normal) {
        this.hint = hint
        this.value = value
        this.priority = priority
    }
}

public class SdlHints {
    /**
     * Throws `CuiException` when SDL rejects the hint.
     */
    public static func set(hint: SdlHint, value: String): Unit {
        withHintStrings(hint, value, HintPriority.Normal)
    }

    /**
     * Throws `CuiException` when SDL rejects the hint.
     */
    public static func set(setting: SdlHintSetting): Unit {
        withHintStrings(setting.hint, setting.value, setting.priority)
    }

    /**
     * Throws `CuiException` when SDL rejects the hint.
     */
    public static func setBool(
        hint: SdlHint,
        value: Bool,
        priority!: HintPriority = HintPriority.Normal
    ): Unit {
        withHintStrings(hint, boolHintValue(value), priority)
    }

    /**
     * Throws `CuiException` when SDL rejects one of the hints.
     */
    public static func apply(settings: Array<SdlHintSetting>): Unit {
        for (setting in settings) {
            SdlHints.set(setting)
        }
    }

    /**
     * Throws `CuiException` when the hint name is empty.
     */
    public static func get(hint: SdlHint): ?String {
        let cName = unsafe { LibC.mallocCString(checkedHintName(hint)) }
        var result: ?String = None<String>
        try (nameResource = cName.asResource()) {
            let value = unsafe { SDL_GetHint(nameResource.value) }
            if (value.isNull()) {
                result = None<String>
            } else {
                result = Some(value.toString())
            }
        }
        result
    }

    /**
     * Throws `CuiException` when the hint name is empty.
     */
    public static func getBool(hint: SdlHint, defaultValue: Bool): Bool {
        let cName = unsafe { LibC.mallocCString(checkedHintName(hint)) }
        var result = defaultValue
        try (nameResource = cName.asResource()) {
            result = unsafe { SDL_GetHintBoolean(nameResource.value, defaultValue) }
        }
        result
    }

    /**
     * Returns whether SDL reset a hint value after validating the hint name.
     */
    public static func reset(hint: SdlHint): Bool {
        let cName = unsafe { LibC.mallocCString(checkedHintName(hint)) }
        var changed = false
        try (nameResource = cName.asResource()) {
            changed = unsafe { SDL_ResetHint(nameResource.value) }
        }
        changed
    }

    public static func resetAll(): Unit {
        unsafe { SDL_ResetHints() }
    }
}
