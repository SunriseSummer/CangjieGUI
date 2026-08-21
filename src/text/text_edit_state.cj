package cui.text

import sdl.input.Clipboard
import cui.core.{Bindable, State}

/**
 * Shared text-editing model for cursor-aware text fields and text areas.
 */
public class TextEditState {
    public let text: Bindable<String>
    public let cursor: State<Int64>
    // The selection is the span between `anchor` and `cursor`. When they coincide there is
    // no selection and editing behaves exactly as a plain caret — this keeps controls that
    // never pass an anchor (a read-only text area) on their original code path.
    public let anchor: State<Int64>

    public init(text: Bindable<String>, cursor!: ?State<Int64> = None, anchor!: ?State<Int64> = None) {
        this.text = text
        this.cursor = match (cursor) {
            case Some(value) => value
            case None => State<Int64>(text.value.size)
        }
        this.anchor = match (anchor) {
            case Some(value) => value
            case None => State<Int64>(this.cursor.value)
        }
        normalizeCursor()
    }

    public init(value: String) {
        this.text = State<String>(value)
        this.cursor = State<Int64>(value.size)
        this.anchor = State<Int64>(value.size)
    }

    /** Clamps caret and anchor onto valid rune boundaries after an external text write. */
    public func normalizeCursor(): Unit {
        // Runs every frame (draw calls it): skip the write when already normalized so callers
        // that own and observe the cursor/anchor are not notified — and revisions not bumped —
        // for a no-op. Behaviour is unchanged; only redundant notifications are avoided.
        let _ = cursor.setIfChanged(normalizedTextCursor(text.value, cursor.value)) // cjcheck-ignore: ignore-result # write-on-change only; whether it changed is irrelevant here
        let _ = anchor.setIfChanged(normalizedTextCursor(text.value, anchor.value)) // cjcheck-ignore: ignore-result # write-on-change only; whether it changed is irrelevant here
    }

    /** Whether a non-empty range is selected. */
    public func hasSelection(): Bool {
        normalizedTextCursor(text.value, anchor.value) != normalizedTextCursor(text.value, cursor.value)
    }

    /** The lower byte offset of the selection (or the caret when nothing is selected). */
    public func selectionStart(): Int64 {
        min(normalizedTextCursor(text.value, anchor.value), normalizedTextCursor(text.value, cursor.value))
    }

    /** The upper byte offset of the selection (or the caret when nothing is selected). */
    public func selectionEnd(): Int64 {
        max(normalizedTextCursor(text.value, anchor.value), normalizedTextCursor(text.value, cursor.value))
    }

    /** The selected substring, empty when nothing is selected. */
    public func selectedText(): String {
        text.value[selectionStart()..selectionEnd()]
    }

    /** Selects the whole value, leaving the caret at the end. */
    public func selectAll(): Unit {
        anchor.value = 0
        cursor.value = text.value.size
    }

    /** Selects the run of same-class characters around `position` (a double-click). */
    public func selectWordAt(position: Int64): Unit {
        let content = text.value
        if (content.size == 0) {
            anchor.value = 0
            cursor.value = 0
            return
        }
        var probe = normalizedTextCursor(content, position)
        if (probe >= content.size) {
            probe = previousTextBoundary(content, content.size)
        }
        let cls = charClassAt(content, probe)
        var start = probe
        while (start > 0) {
            let previous = previousTextBoundary(content, start)
            if (charClassAt(content, previous) != cls) {
                break
            }
            start = previous
        }
        var end = nextTextBoundary(content, probe)
        while (end < content.size) {
            if (charClassAt(content, end) != cls) {
                break
            }
            end = nextTextBoundary(content, end)
        }
        anchor.value = start
        cursor.value = end
    }

    /** Selects the line containing `position`, including its trailing newline (a triple-click). */
    public func selectLineAt(position: Int64): Unit {
        let content = text.value
        let pos = normalizedTextCursor(content, position)
        anchor.value = lineStartBeforeOrAt(content, pos)
        let lineEnd = lineEndAfterOrAt(content, pos)
        cursor.value = if (lineEnd < content.size) {
            nextTextBoundary(content, lineEnd)
        } else {
            lineEnd
        }
    }

    /** Collapses any selection onto the caret. */
    public func clearSelection(): Unit {
        anchor.value = normalizedTextCursor(text.value, cursor.value)
    }

    /** Removes the selected span if any; returns whether text changed. */
    public func deleteSelection(): Bool {
        let start = selectionStart()
        let end = selectionEnd()
        if (start == end) {
            return false
        }
        text.value = text.value[0..start] + text.value[end..text.value.size]
        cursor.value = start
        anchor.value = start
        true
    }

    /** Replaces the selection (or inserts at the caret) with `value`, collapsing the caret after it. */
    public func insert(value: String): Unit {
        let _ = deleteSelection() // cjcheck-ignore: ignore-result # insert replaces any selection; "nothing was selected" needs no branch
        let position = normalizedTextCursor(text.value, cursor.value)
        text.value = text.value[0..position] + value + text.value[position..text.value.size]
        cursor.value = position + value.size
        anchor.value = cursor.value
    }

    /** Deletes the selection, or the rune before the caret when nothing is selected. */
    public func backspace(): Unit {
        if (deleteSelection()) {
            return
        }
        let end = normalizedTextCursor(text.value, cursor.value)
        let start = previousTextBoundary(text.value, end)
        if (start == end) {
            return
        }
        text.value = text.value[0..start] + text.value[end..text.value.size]
        cursor.value = start
        anchor.value = start
    }

    /** Deletes the selection, or the rune after the caret when nothing is selected. */
    public func deleteForward(): Unit {
        if (deleteSelection()) {
            return
        }
        let start = normalizedTextCursor(text.value, cursor.value)
        let end = nextTextBoundary(text.value, start)
        if (start == end) {
            return
        }
        text.value = text.value[0..start] + text.value[end..text.value.size]
        cursor.value = start
        anchor.value = start
    }

    // Plain navigation collapses any selection: to its near edge when one exists, otherwise
    // one boundary in the travel direction. The `extend*` variants keep the anchor so a
    // held Shift grows or shrinks the selection.

    /** Moves the caret one boundary left, collapsing a selection to its start. */
    public func moveLeft(): Unit {
        if (hasSelection()) {
            cursor.value = selectionStart()
        } else {
            cursor.value = previousTextBoundary(text.value, cursor.value)
        }
        anchor.value = cursor.value
    }

    /** Moves the caret one boundary right, collapsing a selection to its end. */
    public func moveRight(): Unit {
        if (hasSelection()) {
            cursor.value = selectionEnd()
        } else {
            cursor.value = nextTextBoundary(text.value, cursor.value)
        }
        anchor.value = cursor.value
    }

    /** Extends the selection one boundary left, keeping the anchor (Shift+Left). */
    public func extendLeft(): Unit {
        cursor.value = previousTextBoundary(text.value, cursor.value)
    }

    /** Extends the selection one boundary right, keeping the anchor (Shift+Right). */
    public func extendRight(): Unit {
        cursor.value = nextTextBoundary(text.value, cursor.value)
    }

    /** Moves the caret to the start of the document, collapsing any selection. */
    public func moveToStart(): Unit {
        cursor.value = 0
        anchor.value = 0
    }

    /** Moves the caret to the end of the document, collapsing any selection. */
    public func moveToEnd(): Unit {
        cursor.value = text.value.size
        anchor.value = cursor.value
    }

    /** Extends the selection to the start of the document, keeping the anchor. */
    public func extendToStart(): Unit {
        cursor.value = 0
    }

    /** Extends the selection to the end of the document, keeping the anchor. */
    public func extendToEnd(): Unit {
        cursor.value = text.value.size
    }

    /** Moves the caret to the start of the current line, collapsing any selection (Home). */
    public func moveToLineStart(): Unit {
        extendToLineStart()
        anchor.value = cursor.value
    }

    /** Moves the caret to the end of the current line, collapsing any selection (End). */
    public func moveToLineEnd(): Unit {
        extendToLineEnd()
        anchor.value = cursor.value
    }

    /** Extends the selection to the start of the current line, keeping the anchor (Shift+Home). */
    public func extendToLineStart(): Unit {
        cursor.value = lineStartBeforeOrAt(text.value, cursor.value)
    }

    /** Extends the selection to the end of the current line, keeping the anchor (Shift+End). */
    public func extendToLineEnd(): Unit {
        cursor.value = lineEndAfterOrAt(text.value, cursor.value)
    }

    /** Moves the caret one line up keeping the column, collapsing any selection (Up). */
    public func moveLineUp(): Unit {
        extendLineUp()
        anchor.value = cursor.value
    }

    /** Moves the caret one line down keeping the column, collapsing any selection (Down). */
    public func moveLineDown(): Unit {
        extendLineDown()
        anchor.value = cursor.value
    }

    // Column-preserving vertical motion that keeps the anchor, so Shift+Up / Shift+Down grow
    // the selection. The plain move* variants above delegate here and then collapse.

    /** Extends the selection one line up keeping the column and the anchor (Shift+Up). */
    public func extendLineUp(): Unit {
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

    /** Extends the selection one line down keeping the column and the anchor (Shift+Down). */
    public func extendLineDown(): Unit {
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

    /** Places the caret at `position`, collapsing any selection (a plain click). */
    public func moveTo(position: Int64): Unit {
        cursor.value = normalizedTextCursor(text.value, position)
        anchor.value = cursor.value
    }

    /** Moves the caret to `position` while keeping the anchor (a drag-select). */
    public func extendTo(position: Int64): Unit {
        cursor.value = normalizedTextCursor(text.value, position)
    }
}

/*
 * Copies the selection to the system clipboard, returning whether anything was copied.
 * Clipboard access can fail without a desktop session; a failed platform write reports
 * false (nothing copied) rather than raising, so Ctrl+C/Ctrl+X never crash the editor.
 * Shared by TextField and TextArea.
 */
internal func copyEditSelection(edit: TextEditState): Bool {
    if (!edit.hasSelection()) {
        return false
    }
    try {
        Clipboard.setText(edit.selectedText())
        true
    } catch (_: Exception) {
        false
    }
}
