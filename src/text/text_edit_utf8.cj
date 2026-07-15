package cui.text

private let UTF8_CONTINUATION_LOW: UInt8 = UInt8(128)
private let UTF8_CONTINUATION_HIGH: UInt8 = UInt8(192)
private let NEWLINE_BYTE: UInt8 = UInt8(10)
private let TAB_BYTE: UInt8 = UInt8(9)
private let CR_BYTE: UInt8 = UInt8(13)
private let SPACE_BYTE: UInt8 = UInt8(32)
private let UNDERSCORE_BYTE: UInt8 = UInt8(95)

// Character class of the rune beginning at `index`, used to grow a double-click selection:
// 0 word (ASCII alphanumeric, underscore, or any non-ASCII rune such as CJK), 1 whitespace,
// 2 other (ASCII punctuation and symbols). Reading the leading byte is enough — a multi-byte
// rune is always a non-ASCII "word" character here, and ASCII bytes classify directly.
internal func charClassAt(text: String, index: Int64): Int64 {
    let byte = text[index]
    if (byte >= UTF8_CONTINUATION_LOW) {
        return 0
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
        (byte >= UInt8(97) && byte <= UInt8(122)) || // a-z
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
    current
}

internal func nextTextBoundary(text: String, cursor: Int64): Int64 {
    var current = normalizedTextCursor(text, cursor)
    if (current >= text.size) {
        return text.size
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
        if (text[previous] == NEWLINE_BYTE) {
            return current
        }
        current = previous
    }
    0
}

internal func lineEndAfterOrAt(text: String, cursor: Int64): Int64 {
    var current = normalizedTextCursor(text, cursor)
    while (current < text.size && text[current] != NEWLINE_BYTE) {
        current = nextTextBoundary(text, current)
    }
    current
}

internal func textCursorLineIndex(text: String, cursor: Int64): Int64 {
    let target = normalizedTextCursor(text, cursor)
    var line: Int64 = 0
    var current: Int64 = 0
    while (current < target) {
        if (text[current] == NEWLINE_BYTE) {
            line += 1
        }
        current = nextTextBoundary(text, current)
    }
    line
}

internal func advanceTextCursorByBytes(
    text: String,
    start: Int64,
    columnBytes: Int64,
    limit: Int64
): Int64 {
    let target = start + max(Int64(0), columnBytes)
    var current = normalizedTextCursor(text, start)
    let end = normalizedTextCursor(text, limit)
    while (current < end && current < target) {
        let next = nextTextBoundary(text, current)
        if (next > target) {
            return current
        }
        current = next
    }
    current
}

internal func startOfTextLine(text: String, lineIndex: Int64): Int64 {
    var line: Int64 = 0
    var current: Int64 = 0
    while (line < lineIndex && current < text.size) {
        if (text[current] == NEWLINE_BYTE) {
            line += 1
        }
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
