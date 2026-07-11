/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package cui.text

import cui.core.State

/**
 * Shared text-editing model for cursor-aware text fields and text areas.
 */
public class TextEditState {
    public let text: State<String>
    public let cursor: State<Int64>

    public init(text: State<String>, cursor!: ?State<Int64> = None) {
        this.text = text
        this.cursor = match (cursor) {
            case Some(value) => value
            case None => State<Int64>(text.value.size)
        }
        normalizeCursor()
    }

    public init(value: String) {
        this.text = State<String>(value)
        this.cursor = State<Int64>(value.size)
    }

    public func normalizeCursor(): Unit {
        cursor.value = normalizedTextCursor(text.value, cursor.value)
    }

    public func insert(value: String): Unit {
        let position = normalizedTextCursor(text.value, cursor.value)
        text.value = text.value[0..position] + value + text.value[position..text.value.size]
        cursor.value = position + value.size
    }

    public func backspace(): Unit {
        let end = normalizedTextCursor(text.value, cursor.value)
        let start = previousTextBoundary(text.value, end)
        if (start == end) {
            return
        }
        text.value = text.value[0..start] + text.value[end..text.value.size]
        cursor.value = start
    }

    public func deleteForward(): Unit {
        let start = normalizedTextCursor(text.value, cursor.value)
        let end = nextTextBoundary(text.value, start)
        if (start == end) {
            return
        }
        text.value = text.value[0..start] + text.value[end..text.value.size]
        cursor.value = start
    }

    public func moveLeft(): Unit {
        cursor.value = previousTextBoundary(text.value, cursor.value)
    }

    public func moveRight(): Unit {
        cursor.value = nextTextBoundary(text.value, cursor.value)
    }

    public func moveToStart(): Unit {
        cursor.value = 0
    }

    public func moveToEnd(): Unit {
        cursor.value = text.value.size
    }

    public func moveToLineStart(): Unit {
        cursor.value = lineStartBeforeOrAt(text.value, cursor.value)
    }

    public func moveToLineEnd(): Unit {
        cursor.value = lineEndAfterOrAt(text.value, cursor.value)
    }

    public func moveLineUp(): Unit {
        let current = normalizedTextCursor(text.value, cursor.value)
        let currentStart = lineStartBeforeOrAt(text.value, current)
        if (currentStart <= 0) {
            cursor.value = 0
            return
        }
        let previousEnd = previousTextBoundary(text.value, currentStart)
        let previousStart = lineStartBeforeOrAt(text.value, previousEnd)
        let column = current - currentStart
        cursor.value = advanceTextCursorByBytes(text.value, previousStart, column, previousEnd)
    }

    public func moveLineDown(): Unit {
        let current = normalizedTextCursor(text.value, cursor.value)
        let currentEnd = lineEndAfterOrAt(text.value, current)
        if (currentEnd >= text.value.size) {
            cursor.value = text.value.size
            return
        }
        let nextStart = nextTextBoundary(text.value, currentEnd)
        let nextEnd = lineEndAfterOrAt(text.value, nextStart)
        let column = current - lineStartBeforeOrAt(text.value, current)
        cursor.value = advanceTextCursorByBytes(text.value, nextStart, column, nextEnd)
    }

    public func moveTo(position: Int64): Unit {
        cursor.value = normalizedTextCursor(text.value, position)
    }
}
