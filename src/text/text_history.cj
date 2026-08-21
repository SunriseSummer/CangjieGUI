package cui.text

import std.collection.ArrayList

// Edits landing within this window of the previous one collapse into a single undo step, so
// a burst of typing reverts together while a pause starts a new step.
private let UNDO_COALESCE_MS: UInt64 = 500
private let UNDO_LIMIT: Int64 = 300

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

    /** Records the pre-edit `before` state, coalescing rapid consecutive edits into one step. */
    func commit(before: TextSnapshot, now: UInt64): Unit {
        let coalesce = grouping && !undoStack.isEmpty() && now >= lastEditMs && now - lastEditMs <= UNDO_COALESCE_MS
        if (!coalesce) {
            undoStack.add(before)
            if (undoStack.size > UNDO_LIMIT) {
                undoStack.remove(at: 0)
            }
        }
        redoStack.clear()
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
        redoStack.add(current)
        grouping = false // the next edit begins a fresh coalescing group
        Some(undoStack.remove(at: undoStack.size - 1))
    }

    /** Reapplies the last undone state, pushing `current` back for undo. */
    func redo(current: TextSnapshot): ?TextSnapshot {
        if (redoStack.isEmpty()) {
            return None
        }
        undoStack.add(current)
        grouping = false
        Some(redoStack.remove(at: redoStack.size - 1))
    }

    /** Whether an undo step is available. */
    public func canUndo(): Bool {
        !undoStack.isEmpty()
    }

    /** Whether a redo step is available. */
    public func canRedo(): Bool {
        !redoStack.isEmpty()
    }
}

// Applies an optional history step: Some restores the snapshot, None (nothing to undo/redo)
// leaves the editor untouched. Shared by TextField and TextArea so undo/redo read as one line.
internal func applyHistoryStep(step: ?TextSnapshot, apply: (TextSnapshot) -> Unit): Unit {
    match (step) {
        case Some(state) => apply(state)
        case None => ()
    }
}
