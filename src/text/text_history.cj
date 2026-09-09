package cui.text

import std.collection.ArrayList

// Edits landing within this window of the previous one collapse into a single undo step, so
// a burst of typing reverts together while a pause starts a new step.
private let UNDO_COALESCE_MS: UInt64 = 500
private let UNDO_LIMIT: Int64 = 300
private let UNDO_BYTE_BUDGET: Int64 = 8 * 1024 * 1024
private let SNAPSHOT_OVERHEAD: Int64 = 32

/** An immutable capture of a text control's editable state. */
struct TextSnapshot {
    let text: String
    let cursor: Int64
    let anchor: Int64

    init(text: String, cursor: Int64, anchor: Int64) {
        this.text = text
        this.cursor = cursor
        this.anchor = anchor
    }
}

/*
 * Undo/redo history for a text control. `commit` records the state *before* an edit, with
 * time coalescing; `undo` swaps to the most recent recorded state and pushes the current one
 * onto the redo stack; any fresh edit clears redo. The stacks are bounded so a long editing
 * session cannot grow memory without limit.
 */
class UndoHistory {
    private let undoStack = ArrayList<TextSnapshot>()
    private let redoStack = ArrayList<TextSnapshot>()
    private var lastEditMs: UInt64 = 0
    private var grouping = false
    private let byteBudget: Int64
    private var byteCount: Int64 = 0
    private var accepted: ?TextSnapshot = None

    init(byteBudget!: Int64 = UNDO_BYTE_BUDGET) {
        this.byteBudget = max(0, byteBudget)
    }

    // A programmatic replacement starts a different document history; Undo must not
    // resurrect the content of the previously bound/loaded value.
    func synchronize(value: String): Unit {
        if (let Some(previous) <- accepted) {
            if (previous.text != value) {
                undoStack.clear()
                redoStack.clear()
                byteCount = 0
                grouping = false
                accepted = None
            }
        }
    }

    func prepare(before: TextSnapshot, isolated: Bool): Unit {
        synchronize(before.text)
        if (isolated) {
            breakGroup()
        }
        if (let Some(previous) <- accepted) {
            if (previous.cursor != before.cursor || previous.anchor != before.anchor) {
                breakGroup()
            }
        }
    }

    func accept(current: TextSnapshot): Unit {
        accepted = Some(current)
    }

    /** Records the pre-edit `before` state, coalescing rapid consecutive edits into one step. */
    func commit(before: TextSnapshot, now: UInt64): Unit {
        let coalesce = grouping && !undoStack.isEmpty() && now >= lastEditMs && now - lastEditMs <= UNDO_COALESCE_MS
        if (!coalesce) {
            undoStack.add(before)
            byteCount += snapshotWeight(before)
        }
        for (entry in redoStack) {
            byteCount -= snapshotWeight(entry)
        }
        redoStack.clear()
        trim()
        lastEditMs = now
        grouping = true
    }

    /*
     * Starts a fresh coalescing group: the next edit will not merge with the previous one.
     * Text controls call this when the caret jumps (a click, arrow navigation), so one
     * undo step never spans edits made at two unrelated positions.
     */
    func breakGroup(): Unit {
        grouping = false
    }

    /** Pops the last recorded state, pushing `current` for redo. `None` when nothing to undo. */
    func undo(current: TextSnapshot): ?TextSnapshot {
        if (undoStack.isEmpty()) {
            return None
        }
        let result = undoStack.remove(at: undoStack.size - 1)
        byteCount -= snapshotWeight(result)
        redoStack.add(current)
        byteCount += snapshotWeight(current)
        trim()
        grouping = false // the next edit begins a fresh coalescing group
        Some(result)
    }

    /** Reapplies the last undone state, pushing `current` back for undo. */
    func redo(current: TextSnapshot): ?TextSnapshot {
        if (redoStack.isEmpty()) {
            return None
        }
        let result = redoStack.remove(at: redoStack.size - 1)
        byteCount -= snapshotWeight(result)
        undoStack.add(current)
        byteCount += snapshotWeight(current)
        trim()
        grouping = false
        Some(result)
    }

    /** Whether an undo step is available. */
    public func canUndo(): Bool {
        !undoStack.isEmpty()
    }

    /** Whether a redo step is available. */
    public func canRedo(): Bool {
        !redoStack.isEmpty()
    }

    private func snapshotWeight(value: TextSnapshot): Int64 {
        value.text.size + SNAPSHOT_OVERHEAD
    }

    private func trim(): Unit {
        while (byteCount > byteBudget || undoStack.size + redoStack.size > UNDO_LIMIT) {
            let removed = if (!undoStack.isEmpty()) {
                undoStack.remove(at: 0)
            } else {
                redoStack.remove(at: 0)
            }
            byteCount -= snapshotWeight(removed)
        }
    }
}
