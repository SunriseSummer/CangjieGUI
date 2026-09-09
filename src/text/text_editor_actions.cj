package cui.text

// Shared behavior behind keyboard shortcuts and public toolbar/menu commands.
class TextEditorActions {
    let edit: TextEditState
    private let history: UndoHistory
    private let clipboard: TextClipboard
    private let editable: Bool
    private let multiline: Bool

    init(edit: TextEditState, history: UndoHistory, clipboard: TextClipboard, editable: Bool, multiline!: Bool) {
        this.edit = edit
        this.history = history
        this.clipboard = clipboard
        this.editable = editable
        this.multiline = multiline
        history.synchronize(edit.text.value)
    }

    func snapshot(): TextSnapshot {
        TextSnapshot(edit.text.value, edit.cursor.value, edit.anchor.value)
    }

    func record(now: UInt64, action: () -> Unit, isolated!: Bool = false): Bool {
        if (!editable) {
            return false
        }
        let before = snapshot()
        history.prepare(before, isolated || edit.hasSelection())
        action()
        let changed = edit.text.value != before.text
        if (changed) {
            history.commit(before, now)
        }
        history.accept(snapshot())
        if (isolated) {
            history.breakGroup()
        }
        changed
    }

    func insert(value: String, now: UInt64, isolated!: Bool = false): Bool {
        if (value.isEmpty() || value.contains("\u{0000}")) {
            return false
        }
        record(now, {=> edit.insert(normalizedEditorInput(value, multiline: multiline))}, isolated: isolated)
    }

    func selectedText(): String {
        edit.selectedText()
    }
    func replaceValue(value: String): Bool {
        if (value.contains("\u{0000}")) {
            return false
        }
        record(
            UInt64(0),
            {
                =>
                    edit.selectAll();
                    edit.insert(normalizedEditorInput(value, multiline: multiline))
            },
            isolated: true
        )
    }
    func replaceSelection(value: String): Bool {
        if (value.contains("\u{0000}")) {
            return false
        }
        record(UInt64(0), {=> edit.insert(normalizedEditorInput(value, multiline: multiline))}, isolated: true)
    }
    func selectAll(): Unit {
        history.breakGroup()
        edit.selectAll()
    }
    func breakGroup(): Unit {
        history.breakGroup()
    }
    func selectRange(anchor: Int64, cursor: Int64): Unit {
        history.breakGroup()
        edit.moveTo(anchor)
        edit.extendTo(cursor)
    }
    func copy(): Bool {
        let selected = edit.selectedText()
        !selected.isEmpty() && clipboard.writeText(selected)
    }
    func cut(): Bool {
        if (!editable) {
            return false
        }
        let before = snapshot()
        if (!copy()) {
            return false
        }
        if (edit.text.value != before.text || edit.cursor.value != before.cursor || edit.anchor.value != before.anchor) {
            return false
        }
        record(UInt64(0), {=> edit.insert("")}, isolated: true)
    }
    func paste(): Bool {
        if (!editable) {
            return false
        }
        match (clipboard.readText()) {
            case Some(value) => insert(value, UInt64(0), isolated: true)
            case None => false
        }
    }
    func canUndo(): Bool {
        editable && history.canUndo()
    }
    func canRedo(): Bool {
        editable && history.canRedo()
    }
    func undo(): Unit {
        if (editable) {
            apply(history.undo(snapshot()))
        }
    }
    func redo(): Unit {
        if (editable) {
            apply(history.redo(snapshot()))
        }
    }
    private func apply(step: ?TextSnapshot): Unit {
        if (let Some(state) <- step) {
            edit.text.value = state.text
            edit.cursor.value = state.cursor
            edit.anchor.value = state.anchor
            edit.normalizeCursor()
            history.accept(snapshot())
        }
    }
}
