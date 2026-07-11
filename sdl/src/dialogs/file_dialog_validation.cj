/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package sdl.dialogs

import sdl.{CuiException}

/**
 * Throws `CuiException` when file dialog options cannot be safely passed to SDL.
 */
internal func ensureFileDialogOptions(options: FileDialogOptions): Unit {
    let count = options.filters.size
    if (count > FILE_DIALOG_MAX_FILTERS) {
        throw CuiException("File dialog supports at most ${FILE_DIALOG_MAX_FILTERS} filters.")
    }
    for (filter in options.filters) {
        ensureFileDialogFilter(filter)
    }
}

internal func isValidDialogFilterPattern(pattern: String): Bool {
    if (pattern == "*") {
        return true
    }
    if (pattern.size <= 0) {
        return false
    }

    var segmentHasText = false
    for (i in 0..pattern.size) {
        let byte = pattern[i]
        if (byte == UInt8(59)) {
            if (!segmentHasText) {
                return false
            }
            segmentHasText = false
        } else if (isDialogFilterPatternByte(byte)) {
            segmentHasText = true
        } else {
            return false
        }
    }
    segmentHasText
}

/**
 * Throws `CuiException` when a filter name is empty or its extension pattern is invalid.
 */
private func ensureFileDialogFilter(filter: FileDialogFilter): Unit {
    if (filter.name.size <= 0) {
        throw CuiException("File dialog filter name cannot be empty.")
    }
    if (!isValidDialogFilterPattern(filter.pattern)) {
        throw CuiException("File dialog filter pattern is invalid.")
    }
}

private func isDialogFilterPatternByte(byte: UInt8): Bool {
    isAsciiDigit(byte) || isAsciiLetter(byte) || byte == UInt8(45) || byte == UInt8(46) || byte == UInt8(95)
}

private func isAsciiDigit(byte: UInt8): Bool {
    byte >= UInt8(48) && byte <= UInt8(57)
}

private func isAsciiLetter(byte: UInt8): Bool {
    (byte >= UInt8(65) && byte <= UInt8(90)) || (byte >= UInt8(97) && byte <= UInt8(122))
}
