package cui.text

import cui.core.{Bindable, State}

/**
 * Shared text-editing model for cursor-aware text fields and text areas.
 */
public class TextEditState {
    public let text: Bindable<String>
    public let cursor: State<Int64>
    // The selection spans anchor and cursor; equal endpoints represent a caret.
    // Read-only policy belongs to the controls, while this model remains directly editable.
    public let anchor: State<Int64>
    private var boundaryCache = TextEditBoundaryCache()

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

    init(text: Bindable<String>, cursor: State<Int64>, anchor: State<Int64>, cache: TextEditBoundaryCache) {
        this.text = text
        this.cursor = cursor
        this.anchor = anchor
        this.boundaryCache = cache
        normalizeCursor()
    }

    private func boundaries(): TextEditBoundaryCache {
        boundaryCache.prepare(text)
    }
    private func normalized(position: Int64): Int64 {
        boundaries().floor(position)
    }
    private func previousBoundary(position: Int64): Int64 {
        boundaries().previous(position)
    }
    private func nextBoundary(position: Int64): Int64 {
        boundaries().next(position)
    }

    /** Clamps caret and anchor onto valid extended-grapheme boundaries after an external text write. */
    public func normalizeCursor(): Unit {
        // Runs every frame (draw calls it): skip the write when already normalized so callers
        // that own and observe the cursor/anchor are not notified — and revisions not bumped —
        // for a no-op. Behaviour is unchanged; only redundant notifications are avoided.
        let _ = cursor.setIfChanged(normalized(cursor.value)) // cjcheck-ignore: ignore-result # write-on-change only; whether it changed is irrelevant here
        let _ = anchor.setIfChanged(normalized(anchor.value)) // cjcheck-ignore: ignore-result # write-on-change only; whether it changed is irrelevant here
    }

    /** Whether a non-empty range is selected. */
    public func hasSelection(): Bool {
        normalized(anchor.value) != normalized(cursor.value)
    }

    /** The lower byte offset of the selection (or the caret when nothing is selected). */
    public func selectionStart(): Int64 {
        min(normalized(anchor.value), normalized(cursor.value))
    }

    /** The upper byte offset of the selection (or the caret when nothing is selected). */
    public func selectionEnd(): Int64 {
        max(normalized(anchor.value), normalized(cursor.value))
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
        var probe = normalized(position)
        if (probe >= content.size) {
            probe = previousBoundary(content.size)
        }
        let cls = charClassAt(content, probe)
        var start = probe
        while (start > 0) {
            let previous = previousBoundary(start)
            if (charClassAt(content, previous) != cls) {
                break
            }
            start = previous
        }
        var end = nextBoundary(probe)
        while (end < content.size) {
            if (charClassAt(content, end) != cls) {
                break
            }
            end = nextBoundary(end)
        }
        anchor.value = start
        cursor.value = end
    }

    /** Selects the line containing `position`, including its trailing newline (a triple-click). */
    public func selectLineAt(position: Int64): Unit {
        let content = text.value
        let pos = normalized(position)
        anchor.value = lineStartBeforeOrAt(content, pos)
        let lineEnd = lineEndAfterOrAt(content, pos)
        cursor.value = if (lineEnd < content.size) {
            nextBoundary(lineEnd)
        } else {
            lineEnd
        }
    }

    /** Collapses any selection onto the caret. */
    public func clearSelection(): Unit {
        cursor.value = normalized(cursor.value)
        anchor.value = cursor.value
    }

    /** Removes the selected span atomically; returns whether text changed. */
    public func deleteSelection(): Bool {
        let start = selectionStart()
        let end = selectionEnd()
        if (start == end) {
            return false
        }
        replaceRange(start, end, "")
        true
    }

    /** Replaces the selection with one published text update, preserving whole graphemes. */
    public func insert(value: String): Unit {
        replaceRange(selectionStart(), selectionEnd(), value)
    }

    /** Deletes the selection, or one complete extended grapheme before the caret. */
    public func backspace(): Unit {
        if (deleteSelection()) {
            return
        }
        let end = normalized(cursor.value)
        replaceRange(previousBoundary(end), end, "")
    }

    /** Deletes the selection, or one complete extended grapheme after the caret. */
    public func deleteForward(): Unit {
        if (deleteSelection()) {
            return
        }
        let start = normalized(cursor.value)
        replaceRange(start, nextBoundary(start), "")
    }

    private func replaceRange(start: Int64, end: Int64, value: String): Unit {
        let content = text.value
        let next = content[0..start] + value + content[end..content.size]
        if (next != content) {
            text.value = next
        }
        // An inserted ZWJ/mark or a deleted separator can merge adjacent graphemes.
        cursor.value = boundaries().ceiling(start + value.size)
        anchor.value = cursor.value
    }

    // Plain navigation collapses any selection: to its near edge when one exists, otherwise
    // one boundary in the travel direction. The `extend*` variants keep the anchor so a
    // held Shift grows or shrinks the selection.

    /** Moves the caret one boundary left, collapsing a selection to its start. */
    public func moveLeft(): Unit {
        if (hasSelection()) {
            cursor.value = selectionStart()
        } else {
            cursor.value = previousBoundary(cursor.value)
        }
        anchor.value = cursor.value
    }

    /** Moves the caret one boundary right, collapsing a selection to its end. */
    public func moveRight(): Unit {
        if (hasSelection()) {
            cursor.value = selectionEnd()
        } else {
            cursor.value = nextBoundary(cursor.value)
        }
        anchor.value = cursor.value
    }

    /** Extends the selection one boundary left, keeping the anchor (Shift+Left). */
    public func extendLeft(): Unit {
        cursor.value = previousBoundary(cursor.value)
    }

    /** Extends the selection one boundary right, keeping the anchor (Shift+Right). */
    public func extendRight(): Unit {
        cursor.value = nextBoundary(cursor.value)
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
        let current = normalized(cursor.value)
        let currentStart = lineStartBeforeOrAt(text.value, current)
        if (currentStart <= 0) {
            cursor.value = 0
            return
        }
        let previousEnd = previousBoundary(currentStart)
        let previousStart = lineStartBeforeOrAt(text.value, previousEnd)
        let column = boundaries().index(current) - boundaries().index(currentStart)
        cursor.value = advanceColumn(previousStart, column, previousEnd)
    }

    /** Extends the selection one line down keeping the column and the anchor (Shift+Down). */
    public func extendLineDown(): Unit {
        let current = normalized(cursor.value)
        let currentEnd = lineEndAfterOrAt(text.value, current)
        if (currentEnd >= text.value.size) {
            cursor.value = text.value.size
            return
        }
        let nextStart = nextBoundary(currentEnd)
        let nextEnd = lineEndAfterOrAt(text.value, nextStart)
        let column = boundaries().index(current) - boundaries().index(lineStartBeforeOrAt(text.value, current))
        cursor.value = advanceColumn(nextStart, column, nextEnd)
    }

    private func advanceColumn(start: Int64, column: Int64, limit: Int64): Int64 {
        let map = boundaries()
        map.at(min(map.index(limit), map.index(start) + column))
    }

    /** Moves by a same-class word run (Ctrl+Left), collapsing selection. */
    public func moveWordLeft(): Unit {
        extendWordLeft();
        anchor.value = cursor.value
    }
    /** Moves to the next word run (Ctrl+Right), collapsing selection. */
    public func moveWordRight(): Unit {
        extendWordRight();
        anchor.value = cursor.value
    }
    /** Extends selection to the preceding word-run start. */
    public func extendWordLeft(): Unit {
        cursor.value = wordLeft(cursor.value)
    }
    /** Extends selection to the next word-run start. */
    public func extendWordRight(): Unit {
        cursor.value = wordRight(cursor.value)
    }
    /** Removes selection, or the preceding word run. */
    public func deleteWordBackward(): Unit {
        if (deleteSelection()) {
            return
        }
        let end = normalized(cursor.value)
        replaceRange(wordLeft(end), end, "")
    }
    /** Removes selection, or the following word run. */
    public func deleteWordForward(): Unit {
        if (deleteSelection()) {
            return
        }
        let start = normalized(cursor.value)
        replaceRange(start, wordRight(start), "")
    }

    private func wordLeft(position: Int64): Int64 {
        let content = text.value
        let map = boundaries()
        var index = map.index(position)
        while (index > 0 && charClassAt(content, map.at(index - 1)) == 1) {
            index -= 1
        }
        if (index > 0) {
            let kind = charClassAt(content, map.at(index - 1))
            while (index > 0 && charClassAt(content, map.at(index - 1)) == kind) {
                index -= 1
            }
        }
        map.at(index)
    }

    private func wordRight(position: Int64): Int64 {
        let content = text.value
        let map = boundaries()
        var index = map.index(position)
        if (map.at(index) < content.size) {
            let kind = charClassAt(content, map.at(index))
            while (map.at(index) < content.size && charClassAt(content, map.at(index)) == kind) {
                index += 1
            }
            while (map.at(index) < content.size && charClassAt(content, map.at(index)) == 1) {
                index += 1
            }
        }
        map.at(index)
    }

    /** Places the caret at `position`, collapsing any selection (a plain click). */
    public func moveTo(position: Int64): Unit {
        cursor.value = normalized(position)
        anchor.value = cursor.value
    }

    /** Moves the caret to `position` while keeping the anchor (a drag-select). */
    public func extendTo(position: Int64): Unit {
        cursor.value = normalized(position)
    }
}
