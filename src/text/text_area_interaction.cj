package cui.text

import cui.core.{State, UiContext, localState}

// Retained viewport/navigation state is separate from the bound document and undo history.
internal class TextAreaInteraction {
    let xOffset: State<Float32>
    let preferredX: State<Float32>
    let upstream: State<Bool>
    let revealPending: State<Bool>
    let blink: TextCursorState
    let dragScroll: TextDragScroll
    let layoutCache: TextEditorLayoutCache
    private let id: String
    private let history: UndoHistory

    init(id: String, history: UndoHistory) {
        this.id = id
        this.history = history
        xOffset = localState<Float32>("TextArea:${id}:xoff") {0.0}
        preferredX = localState<Float32>("TextArea:${id}:preferredX") {-1.0}
        upstream = localState<Bool>("TextArea:${id}:upstream") {false}
        revealPending = localState<Bool>("TextArea:${id}:reveal") {false}
        blink = localState<TextCursorState>("TextArea:${id}:caretState") {TextCursorState()}.value
        dragScroll = localState<TextDragScroll>("TextArea:${id}:dragScroll") {TextDragScroll()}.value
        layoutCache = localState<TextEditorLayoutCache>("TextArea:${id}:layout") {TextEditorLayoutCache()}.value
    }

    func moveVertical(ctx: UiContext, edit: TextEditState, view: TextEditorView, direction: Int64): Bool {
        if (!ctx.hasFocus(id)) {
            return false
        }
        if (ctx.imeComposition(id).isSome()) {
            return true
        }
        let (target, goal, affinity) = view.verticalTarget(direction, preferredX.value)
        preferredX.value = goal
        upstream.value = affinity
        selectTarget(ctx, edit, target)
        true
    }

    func moveEdge(ctx: UiContext, edit: TextEditState, view: TextEditorView, toEnd!: Bool): Bool {
        if (!ctx.hasFocus(id)) {
            return false
        }
        if (ctx.imeComposition(id).isSome()) {
            return true
        }
        let row = view.layout.rows[view.cursorRow()]
        let target = if (toEnd) {
            row.end
        } else {
            row.start
        }
        upstream.value = toEnd
        preferredX.value = -1.0
        selectTarget(ctx, edit, target)
        true
    }

    private func selectTarget(ctx: UiContext, edit: TextEditState, target: Int64): Unit {
        if (ctx.eventModifiers().shift) {
            edit.extendTo(target)
        } else {
            edit.moveTo(target)
        }
        history.breakGroup();
        revealPending.value = true
    }

    func autoScroll(ctx: UiContext, edit: TextEditState, view: TextEditorView, scroll: State<Float32>, editable!: Bool): Unit {
        if (dragScroll.step(ctx, id, view, requireFocus: editable)) {
            scroll.value = view.scroll
            xOffset.value = view.xShift
            let (target, affinity) = dragScroll.target(view)
            upstream.value = affinity
            edit.extendTo(target)
        }
    }
}
