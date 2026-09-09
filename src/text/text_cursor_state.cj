package cui.text

import cui.core.UiContext

// Animation bookkeeping is not observable document state: sampling a caret during paint must
// never schedule a second build/layout transaction merely to store the current blink epoch.
internal class TextCursorState {
    var epoch: UInt64 = UInt64(0)
    private var cursor: Int64 = -1
    private var anchor: Int64 = -1
    private var revision: UInt64 = UInt64(0)
    private var focused = false

    func observe(ctx: UiContext, id: String, edit: TextEditState, editable: Bool): Bool {
        let moved = cursor >= 0 && cursor != edit.cursor.value
        let active = editable && ctx.hasFocus(id) && ctx.textWindowActive()
        if (active && (!focused || cursor != edit.cursor.value || anchor != edit.anchor.value || revision != edit
            .text
            .revision)) {
            epoch = ctx.frame.elapsedMs
        }
        cursor = edit.cursor.value
        anchor = edit.anchor.value
        revision = edit.text.revision
        focused = active
        moved
    }
}
