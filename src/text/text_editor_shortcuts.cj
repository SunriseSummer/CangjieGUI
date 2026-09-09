package cui.text

import cui.core.UiContext

private let EDITOR_SELECT_ALL: UInt8 = 65
private let EDITOR_COPY: UInt8 = 67
private let EDITOR_PASTE: UInt8 = 86
private let EDITOR_CUT: UInt8 = 88
private let EDITOR_REDO: UInt8 = 89
private let EDITOR_UNDO: UInt8 = 90

// Keep command ownership, IME exclusion and undo boundaries identical in both editors.
internal func handleEditorShortcut(ctx: UiContext, id: String, code: UInt8, actions: TextEditorActions): Bool {
    if (!ctx.hasFocus(id) || !ctx.eventModifiers().command) {
        return false
    }
    if (code == EDITOR_SELECT_ALL) {
        actions.selectAll();
        return true
    }
    if (code == EDITOR_COPY) {
        let _ = actions.copy() // cjcheck-ignore: ignore-result # the focused editor owns Ctrl+C even if clipboard access fails; public copy() reports the result
        actions.breakGroup()
        return true
    }
    if (ctx.imeComposition(id).isSome()) {
        return false
    }
    if (code == EDITOR_CUT) {
        let _ = actions.cut() // cjcheck-ignore: ignore-result # failed copy must preserve text; the focused shortcut remains consumed
        return true
    }
    if (code == EDITOR_PASTE) {
        let _ = actions.paste() // cjcheck-ignore: ignore-result # empty or failed clipboard reads are consumed no-ops
        return true
    }
    if (code == EDITOR_UNDO) {
        if (ctx.eventModifiers().shift) {
            actions.redo()
        } else {
            actions.undo()
        }
        return true
    }
    if (code == EDITOR_REDO) {
        actions.redo();
        return true
    }
    false
}
