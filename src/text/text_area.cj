package cui.text

import sdl.{FontSizes, Key, MouseButton, Point, Rect, Size, UiEvent}
import sdl.input.{Clipboard, Keyboard}
import cui.core.{Bindable, CUI_SMALL_H, CursorShape, ScrollBar, State, UiContext, Widget, claimHoverIfInside,
    clampScrollOffset, drawSurface, drawVerticalScrollBar, emit, localState, registerFocusable, scrollLineIndex,
    scrollLineRemainder, scrollOffsetAfterWheel}

// SDL reports letter keys as their uppercase ASCII code (see the Ctrl+letter shortcuts).
private let AREA_LETTER_A: UInt8 = 65
private let AREA_LETTER_C: UInt8 = 67
private let AREA_LETTER_V: UInt8 = 86
private let AREA_LETTER_X: UInt8 = 88
private let AREA_LETTER_Y: UInt8 = 89
private let AREA_LETTER_Z: UInt8 = 90

/*
 * Caches a document's line split so scrolling does not re-split the whole text every frame. Keyed
 * by the text's revision: an edit bumps the revision (see Observable.revision), which refreshes the
 * split on next access, so the cache never serves stale lines. Splitting is already the fast
 * primitive here (stdlib split beats a hand-rolled byte scan), so the win is not re-doing it.
 */
class TextLineCache {
    private var cachedRevision: UInt64 = 0
    private var cachedLines: Array<String> = []
    private var hasValue = false

    func lines(text: String, revision: UInt64): Array<String> {
        if (!hasValue || revision != cachedRevision) {
            cachedLines = text.split("\n")
            cachedRevision = revision
            hasValue = true
        }
        cachedLines
    }
}

public class TextArea <: Widget {
    private let id: String
    private let text: Bindable<String>
    private var scrollStateValue: State<Float32>
    private var cursorStateValue: State<Int64>
    private var anchorStateValue: State<Int64>
    private var isEditable: Bool
    private let scrollBar: ScrollBar
    private let history: UndoHistory
    private let lineCache: TextLineCache
    private var frame = Rect.zero()

    public init(
        id: String,
        text: Bindable<String>,
        scroll!: ?State<Float32> = None,
        cursor!: ?State<Int64> = None,
        anchor!: ?State<Int64> = None,
        editable!: Bool = true
    ) {
        this.id = id
        this.text = text
        this.scrollStateValue = match (scroll) {
            case Some(value) => value
            case None => localState<Float32>("TextArea:${id}:scroll") {0.0}
        }
        this.cursorStateValue = match (cursor) {
            case Some(value) => value
            case None => localState<Int64>("TextArea:${id}:cursor") {text.value.size}
        }
        // The anchor starts collapsed on the caret so no phantom selection appears. A caller
        // that owns the cursor and moves it from outside (loading a file, a programmatic
        // paste) must own the anchor too and move both together — otherwise the stale anchor
        // spans a selection the user never made, and the next keystroke replaces it.
        let caretStart = cursorStateValue.value
        this.anchorStateValue = match (anchor) {
            case Some(value) => value
            case None => localState<Int64>("TextArea:${id}:anchor") {caretStart}
        }
        this.isEditable = editable
        this.scrollBar = ScrollBar("TextArea:${id}:thumb")
        this.history = localState<UndoHistory>("TextArea:${id}:history") {UndoHistory()}.value
        this.lineCache = localState<TextLineCache>("TextArea:${id}:lines") {TextLineCache()}.value
        // A read-only text area is not an editing stop, so it stays out of Tab traversal.
        if (editable) {
            registerFocusable(id)
        }
        emit(this)
    }

    /** Reverts the last edit group; also bound to Ctrl+Z. */
    public func undo(): Unit {
        match (history.undo(snapshot())) {
            case Some(state) => applySnapshot(state)
            case None => ()
        }
    }

    /** Reapplies the last undone edit; also bound to Ctrl+Y / Ctrl+Shift+Z. */
    public func redo(): Unit {
        match (history.redo(snapshot())) {
            case Some(state) => applySnapshot(state)
            case None => ()
        }
    }

    public func measure(_: UiContext, available: Size): Size {
        Size(available.w, available.h)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    // The document split into lines, cached by text revision so scrolling never re-splits per frame.
    private func lines(): Array<String> {
        lineCache.lines(text.value, text.revision)
    }

    public func draw(ctx: UiContext): Unit {
        let edit = editState()
        edit.normalizeCursor()
        let docLines = lines()
        // Clamp writes only on change: draw runs every frame, and the offset may be an
        // externally owned state whose observers should not fire for no-op writes.
        let clampedScroll = clampScrollOffset(scrollStateValue.value, textContentHeight(docLines),
            textViewport(frame).h)
        if (clampedScroll != scrollStateValue.value) {
            scrollStateValue.value = clampedScroll
        }
        let content = TextAreaContent(text.value, cursorStateValue.value, scrollStateValue.value)
        drawTextAreaBox(ctx, frame, id, content, docLines, edit.selectionStart(), edit.selectionEnd(),
            ctx.hasFocus(id), scrollBar.dragging(ctx))
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        // A read-only area is not an editing target, so it does not request the text cursor.
        if (isEditable) {
            claimHoverIfInside(ctx, event, frame, id, CursorShape.Text)
        }
        let edit = editState()
        match (event) {
            case UiEvent.MouseDown(MouseButton.Left, x, y) =>
                if (scrollBar.press(ctx, frame, scrollStateValue, textContentHeight(lines()),
                    textViewport(frame).h, x, y)) {
                    return true
                }
                return pressAt(ctx, edit, x, y)
            case UiEvent.MouseMove(x, y) =>
                if (scrollBar.drag(ctx, frame, scrollStateValue, textContentHeight(lines()),
                    textViewport(frame).h, y)) {
                    return true
                }
                if (ctx.isDragging(id) && ctx.leftMouseDown) {
                    edit.extendTo(pointOffset(ctx, x, y))
                    return true
                }
            case UiEvent.MouseWheel(_, wy, wx, pointerY) =>
                if (frame.contains(wx, pointerY)) {
                    scrollStateValue.value = scrollOffsetAfterWheel(scrollStateValue.value, wy,
                        textContentHeight(lines()), textViewport(frame).h)
                    return true
                }
            case UiEvent.TextInput(value) => return recordedEdit(ctx, {=> edit.insert(value)})
            case UiEvent.KeyDown(Key.Enter, _) => return recordedEdit(ctx, {=> edit.insert("\n")})
            case UiEvent.KeyDown(Key.Backspace, _) => return recordedEdit(ctx, {=> edit.backspace()})
            case UiEvent.KeyDown(Key.Delete, _) => return recordedEdit(ctx, {=> edit.deleteForward()})
            case UiEvent.KeyDown(Key.Left, _) => return navigate(ctx, {=> edit.moveLeft()}, {=> edit.extendLeft()})
            case UiEvent.KeyDown(Key.Right, _) => return navigate(ctx, {=> edit.moveRight()}, {=> edit.extendRight()})
            case UiEvent.KeyDown(Key.Up, _) => return navigate(ctx, {=> edit.moveLineUp()}, {=> edit.extendLineUp()})
            case UiEvent.KeyDown(Key.Down, _) => return navigate(ctx, {=> edit.moveLineDown()}, {=> edit.extendLineDown()})
            case UiEvent.KeyDown(Key.Home, _) => return navigate(ctx, {=> edit.moveToLineStart()},
                {=> edit.extendToLineStart()})
            case UiEvent.KeyDown(Key.End, _) => return navigate(ctx, {=> edit.moveToLineEnd()},
                {=> edit.extendToLineEnd()})
            case UiEvent.KeyDown(Key.Letter(code), _) => return shortcut(ctx, edit, code)
            case _ => ()
        }
        false
    }

    public func isFlexible(): Bool {
        true
    }

    public func focusableId(): ?String {
        // A read-only area never registered, so there is nothing for `.enabled` to remove.
        if (isEditable) {
            Some(id)
        } else {
            None
        }
    }

    private func editState(): TextEditState {
        TextEditState(text, cursor: Some(cursorStateValue), anchor: Some(anchorStateValue))
    }

    // Runs a mutating action while focused and editable, recording it for undo. The
    // before/after text comparison means a no-op edit adds no undo step.
    private func recordedEdit(ctx: UiContext, action: () -> Unit): Bool {
        if (!ctx.hasFocus(id) || !isEditable) {
            return false
        }
        let before = snapshot()
        action()
        if (text.value != before.text) {
            history.commit(before, ctx.frame.elapsedMs)
        }
        revealCaretLine()
        true
    }

    private func snapshot(): TextSnapshot {
        TextSnapshot(text.value, cursorStateValue.value, anchorStateValue.value)
    }

    private func applySnapshot(state: TextSnapshot): Unit {
        text.value = state.text
        cursorStateValue.value = state.cursor
        anchorStateValue.value = state.anchor
        revealCaretLine() // an undo/redo may jump the caret far from the visible lines
    }

    /*
     * Vertical caret follow: keeps the caret's line inside the viewport after keyboard
     * edits and navigation, scrolling the minimal distance (top-align when above, bottom-
     * align when below). Pointer paths need no follow — the pointer is already in view.
     */
    private func revealCaretLine(): Unit {
        let viewportH = textViewport(frame).h
        if (viewportH <= 0.0) {
            return
        }
        let position = normalizedTextCursor(text.value, cursorStateValue.value)
        let rowTop = Float32(textCursorLineIndex(text.value, position)) * CUI_SMALL_H
        var scroll = scrollStateValue.value
        if (rowTop < scroll) {
            scroll = rowTop
        } else if (rowTop + CUI_SMALL_H > scroll + viewportH) {
            scroll = rowTop + CUI_SMALL_H - viewportH
        }
        let clamped = clampScrollOffset(scroll, textContentHeight(lines()), viewportH)
        if (clamped != scrollStateValue.value) {
            scrollStateValue.value = clamped
        }
    }

    private func pointOffset(ctx: UiContext, x: Float32, y: Float32): Int64 {
        textAreaCursorForPoint(ctx, frame, TextAreaContent(text.value, cursorStateValue.value, scrollStateValue.value),
            Point(x, y))
    }

    private func pressAt(ctx: UiContext, edit: TextEditState, x: Float32, y: Float32): Bool {
        if (frame.contains(x, y)) {
            ctx.focus(id)
            let offset = pointOffset(ctx, x, y)
            if (ctx.clickCount == 2) {
                edit.selectWordAt(offset)
            } else if (ctx.clickCount >= 3) {
                edit.selectLineAt(offset)
            } else {
                edit.moveTo(offset)
                ctx.beginDrag(id) // a press-drag extends the selection (see MouseMove)
            }
            history.breakGroup() // edits before and after a caret jump undo separately
            return true
        }
        false
    }

    // Held Shift extends the selection; plain navigation collapses it. Navigation stays
    // available in read-only mode so text can be selected for copying.
    private func navigate(ctx: UiContext, moveCaret: () -> Unit, growSelection: () -> Unit): Bool {
        if (!ctx.hasFocus(id)) {
            return false
        }
        if (Keyboard.modifiers().shift) {
            growSelection()
        } else {
            moveCaret()
        }
        history.breakGroup() // edits before and after a caret jump undo separately
        revealCaretLine()
        true
    }

    private func shortcut(ctx: UiContext, edit: TextEditState, code: UInt8): Bool {
        if (!ctx.hasFocus(id) || !Keyboard.modifiers().command) {
            return false
        }
        if (code == AREA_LETTER_A) {
            edit.selectAll()
            return true
        } else if (code == AREA_LETTER_C) {
            let _ = copySelection(edit)
            return true
        } else if (code == AREA_LETTER_X) {
            if (isEditable) {
                return recordedEdit(ctx, {=> if (copySelection(edit)) {
                    let _ = edit.deleteSelection()
                }})
            }
            let _ = copySelection(edit) // read-only: cut degrades to copy
            return true
        } else if (code == AREA_LETTER_V) {
            if (isEditable) {
                return recordedEdit(ctx, {=> pasteClipboard(edit)})
            }
            return true
        } else if (code == AREA_LETTER_Z) {
            if (isEditable) {
                if (Keyboard.modifiers().shift) {
                    redo()
                } else {
                    undo()
                }
            }
            return true
        } else if (code == AREA_LETTER_Y) {
            if (isEditable) {
                redo()
            }
            return true
        }
        false
    }

    // Clipboard access can fail without a desktop session; treat it as best-effort.
    private func copySelection(edit: TextEditState): Bool {
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

    private func pasteClipboard(edit: TextEditState): Unit {
        try {
            let clip = Clipboard.getText()
            if (clip.size > 0) {
                // Line breaks are kept (this is the multi-line control), but Windows CRLF is
                // normalised: a raw \r at each line end breaks End/Backspace and measurement.
                edit.insert(clip.replace("\r\n", "\n").replace("\r", "\n"))
            }
        } catch (_: Exception) {
            ()
        }
    }
}

private func drawTextAreaBox(
    ctx: UiContext,
    frame: Rect,
    id: String,
    content: TextAreaContent,
    lines: Array<String>,
    selStart: Int64,
    selEnd: Int64,
    focused: Bool,
    barActive: Bool
): Unit {
    drawTextBoxChrome(ctx, frame, id)
    let viewport = textViewport(frame)
    ctx.renderer.pushClip(viewport)
    if (focused) {
        drawTextAreaSelection(ctx, viewport, content, selStart, selEnd)
    }
    drawLines(ctx, viewport, lines, content.scroll)
    drawTextAreaCursor(ctx, viewport, id, content)
    ctx.renderer.popClip()
    drawVerticalScrollBar(ctx, frame, content.scroll, textContentHeight(lines), viewport.h, active: barActive)
}

internal func drawTextBoxChrome(ctx: UiContext, frame: Rect, id: String): Unit {
    drawSurface(ctx, frame, ctx.theme.fieldSurface(ctx.showFocusRing(id)))
}

private func drawLines(ctx: UiContext, rect: Rect, lines: Array<String>, scroll: Float32): Unit {
    var i = scrollLineIndex(scroll)
    var y = rect.y - scrollLineRemainder(scroll)
    while (i < lines.size && y < rect.bottom()) {
        ctx.renderer.text(lines[i], rect.x, y, ctx.theme.text, pointSize: FontSizes.BODY)
        y += CUI_SMALL_H
        i += 1
    }
}

private func textContentHeight(lines: Array<String>): Float32 {
    Float32(lines.size) * CUI_SMALL_H
}

private func textViewport(frame: Rect): Rect {
    textInputViewport(frame)
}
