/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package cui.text

private let UTF8_CONTINUATION_LOW: UInt8 = UInt8(128)
private let UTF8_CONTINUATION_HIGH: UInt8 = UInt8(192)
private let NEWLINE_BYTE: UInt8 = UInt8(10)

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

internal func textCursorAtLineColumn(text: String, lineIndex: Int64, columnBytes: Int64): Int64 {
    let lineStart = startOfTextLine(text, max(Int64(0), lineIndex))
    let lineEnd = lineEndAfterOrAt(text, lineStart)
    advanceTextCursorByBytes(text, lineStart, columnBytes, lineEnd)
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

private func startOfTextLine(text: String, lineIndex: Int64): Int64 {
    var line: Int64 = 0
    var current: Int64 = 0
    while (line < lineIndex && current < text.size) {
        if (text[current] == NEWLINE_BYTE) {
            line += 1
            current = nextTextBoundary(text, current)
        } else {
            current = nextTextBoundary(text, current)
        }
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
