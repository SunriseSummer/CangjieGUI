package cui.text

import std.unicode.UnicodeRuneExtension

private let UTF8_CONTINUATION_LOW: UInt8 = UInt8(128)
private let UTF8_CONTINUATION_HIGH: UInt8 = UInt8(192)
private let NEWLINE_BYTE: UInt8 = UInt8(10)
private let TAB_BYTE: UInt8 = UInt8(9)
private let CR_BYTE: UInt8 = UInt8(13)
private let SPACE_BYTE: UInt8 = UInt8(32)
private let UNDERSCORE_BYTE: UInt8 = UInt8(95)

// Character class of the rune beginning at `index`, used to grow a double-click selection:
// 0 letters/numbers/underscore, 1 whitespace, 2 punctuation/symbols. This is a
// word-run editing convention, not dictionary-based segmentation for CJK or Thai.
// Decode only one rune so scanning a long Unicode word never copies growing suffixes.
internal func charClassAt(text: String, index: Int64): Int64 {
    let byte = text[index]
    if (byte >= UTF8_CONTINUATION_LOW) {
        let rune = match (text[index..nextTextBoundary(text, index)].runes().next()) {
            case Some(value) => value
            case None => throw IllegalStateException("Non-empty UTF-8 character has no rune")
        }
        if (rune.isWhiteSpace()) {
            return 1
        }
        return if (rune.isLetter() || rune.isNumber()) {
            0
        } else {
            2
        }
    }
    if (isAsciiWordByte(byte)) {
        return 0
    }
    if (byte == SPACE_BYTE || byte == TAB_BYTE || byte == NEWLINE_BYTE || byte == CR_BYTE) {
        return 1
    }
    2
}

private func isAsciiWordByte(byte: UInt8): Bool {
    (byte >= UInt8(48) && byte <= UInt8(57)) || // 0-9
        (byte >= UInt8(65) && byte <= UInt8(90)) || // A-Z
        (byte >= UInt8(97) &&
        byte <= UInt8(122)) || // a-z
            byte == UNDERSCORE_BYTE
}

internal func normalizedTextCursor(text: String, cursor: Int64): Int64 {
    var current = clampTextCursor(text, cursor)
    while (current > 0 && current < text.size) {
        if (!isUtf8Continuation(text[current])) {
            break
        }
        current -= 1
    }
    if (current > 0 && current < text.size && text[current] == NEWLINE_BYTE && text[current - 1] == CR_BYTE) {
        current -= 1
    }
    current
}

internal func previousTextBoundary(text: String, cursor: Int64): Int64 {
    var current = normalizedTextCursor(text, cursor)
    if (current <= 0) {
        return 0
    }
    current -= 1
    while (current > 0) {
        if (!isUtf8Continuation(text[current])) {
            break
        }
        current -= 1
    }
    if (current > 0 && text[current] == NEWLINE_BYTE && text[current - 1] == CR_BYTE) {
        current -= 1
    }
    current
}

internal func nextTextBoundary(text: String, cursor: Int64): Int64 {
    var current = normalizedTextCursor(text, cursor)
    if (current >= text.size) {
        return text.size
    }
    if (text[current] == CR_BYTE && current + 1 < text.size && text[current + 1] == NEWLINE_BYTE) {
        return current + 2
    }
    current += 1
    while (current < text.size) {
        if (!isUtf8Continuation(text[current])) {
            break
        }
        current += 1
    }
    current
}

internal func lineStartBeforeOrAt(text: String, cursor: Int64): Int64 {
    var current = normalizedTextCursor(text, cursor)
    while (current > 0) {
        let previous = previousTextBoundary(text, current)
        if (text[previous] == NEWLINE_BYTE || text[previous] == CR_BYTE) {
            return current
        }
        current = previous
    }
    0
}

internal func lineEndAfterOrAt(text: String, cursor: Int64): Int64 {
    var current = normalizedTextCursor(text, cursor)
    while (current < text.size && text[current] != NEWLINE_BYTE && text[current] != CR_BYTE) {
        current = nextTextBoundary(text, current)
    }
    current
}

private func clampTextCursor(text: String, cursor: Int64): Int64 {
    if (cursor < 0) {
        0
    } else if (cursor > text.size) {
        text.size
    } else {
        cursor
    }
}

private func isUtf8Continuation(byte: UInt8): Bool {
    byte >= UTF8_CONTINUATION_LOW && byte < UTF8_CONTINUATION_HIGH
}
