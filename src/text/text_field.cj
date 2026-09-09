package cui.text

import sdl.{Key, MouseButton, Rect, Size, UiEvent}
import cui.core.{Bindable, CUI_CONTROL_H, CursorShape, Semantics, SemanticsAction, SemanticsRole, State, UiContext,
    Widget, claimHoverIfInside, emit, localState, registerFocusable, registerFrameSubscriber, resolveControlKey}

// SDL reports letter keys as their uppercase ASCII code, so the editing shortcuts read as
// the familiar Ctrl+letter table.

/*
 * A single-line text editor bound to a `Bindable<String>`. The caret and selection anchor are BYTE
 * offsets into the UTF-8 text, not character counts; a caller supplying its own `cursor`/`anchor`
 * states must keep them on rune boundaries and move the pair together, or the stale anchor spans a
 * selection the user never made. Editing follows the desktop conventions: mouse and double-click-word
 * selection, the Ctrl+A/C/X/V/Z/Y table, grouped undo, and a horizontal follow window that keeps the
 * caret visible. Caret, selection, and scroll state are retained across the per-frame rebuild under
 * the control identity; `editable: false` renders read-only and stays out of Tab traversal.
 */
public class TextField <: Widget {
    private let id: String
    private let text: Bindable<String>
    private var cursorStateValue: State<Int64>
    private var anchorStateValue: State<Int64>
    private let history: UndoHistory
    private let clipboard: TextClipboard
    private let boundaryCache: TextEditBoundaryCache
    // Horizontal follow window: how many pixels the text is slid left so the caret stays
    // inside the field's inner width. Retained across rebuilds; recomputed each draw.
    private let xOffset: State<Float32>
    private var autofocusRequested = false
    private let autofocusDone: State<Bool>
    private let isEditable: Bool
    private var frame = Rect.zero()
    private var lastPaintView: ?TextEditorView = None
    private var lastPaintEpoch: UInt64 = UInt64(0)
    private var inputAppearance = TextInputStyle()
    private var hint = ""
    private var submitAction: ?(String) -> Unit = None
    private let layoutCache: TextEditorLayoutCache
    private let blink: TextCursorState
    private let dragScroll: TextDragScroll

    public init(
        text: Bindable<String>,
        key!: ?String = None,
        cursor!: ?State<Int64> = None,
        anchor!: ?State<Int64> = None,
        editable!: Bool = true,
        clipboard!: TextClipboard = TextClipboard.system
    ) {
        let ident = resolveControlKey(key, "TextField")
        this.id = ident
        this.text = text
        this.isEditable = editable
        this.cursorStateValue = match (cursor) {
            case Some(value) => value
            case None => localState<Int64>("TextField:${ident}:cursor") {text.value.size}
        }
        // The anchor starts collapsed on the caret; defaulting it to the text end instead
        // would present a phantom selection whenever the caret begins elsewhere. A composing
        // widget (e.g. ComboBox) may own both caret and anchor so it can reset the selection.
        let caretStart = cursorStateValue.value
        this.anchorStateValue = match (anchor) {
            case Some(value) => value
            case None => localState<Int64>("TextField:${ident}:anchor") {caretStart}
        }
        this.history = localState<UndoHistory>("TextField:${ident}:history") {UndoHistory()}.value
        this.clipboard = clipboard
        this.boundaryCache = localState<TextEditBoundaryCache>("TextField:${ident}:boundaries") {
            TextEditBoundaryCache()
        }.value
        this.xOffset = localState<Float32>("TextField:${ident}:xoff") {0.0}
        this.autofocusDone = localState<Bool>("TextField:${ident}:autofocused") {false}
        this.layoutCache = localState<TextEditorLayoutCache>("TextField:${ident}:layout") {TextEditorLayoutCache()}
            .value
        this.blink = localState<TextCursorState>("TextField:${ident}:caretState") {TextCursorState()}.value
        this.dragScroll = localState<TextDragScroll>("TextField:${ident}:dragScroll") {TextDragScroll()}.value
        if (dragScroll.active.value) {
            registerFrameSubscriber({ctx, _ => autoScroll(ctx)})
        }
        // A read-only field is not an editing stop, so it stays out of Tab traversal (mirrors TextArea).
        if (editable) {
            registerFocusable(ident)
        }
        emit(this)
    }

    /** Sets editor colors, inner padding, alignment and minimum line height. */
    public func style(value: TextInputStyle): TextField {
        inputAppearance = value
        this
    }
    /** Shows a hint only while the document and IME pre-edit are empty. */
    public func placeholder(value: String): TextField {
        hint = normalizedEditorInput(value, multiline: false)
        this
    }
    /** Handles Enter after composition has committed; receives the current bound text. */
    public func onSubmit(action: (String) -> Unit): TextField {
        submitAction = Some(action)
        this
    }

    /** Claims keyboard focus the first time the field appears (e.g. a search box or dialog). */
    public func autofocus(): TextField {
        autofocusRequested = true
        subscribeEditorAutofocus(autofocusDone, isEditable, {ctx => applyAutofocus(ctx)})
        this
    }

    /** Reverts the last edit group; also bound to Ctrl+Z. */
    public func undo(): Unit {
        actions().undo()
    }

    /** Reapplies the last undone edit; also bound to Ctrl+Y / Ctrl+Shift+Z. */
    public func redo(): Unit {
        actions().redo()
    }

    /** Selects all text; selection and copying remain available in read-only mode. */
    public func selectAll(): Unit {
        actions().selectAll()
    }
    /** Selects byte offsets, snapping both endpoints to extended-grapheme boundaries. */
    public func selectRange(anchor: Int64, cursor: Int64): Unit {
        actions().selectRange(anchor, cursor)
    }
    /** Returns selected plain text. */
    public func selectedText(): String {
        actions().selectedText()
    }
    /** Replaces selection as one undo step; an empty value deletes the selection. */
    public func replaceSelection(value: String): Bool {
        actions().replaceSelection(value)
    }
    /** Copies selection; false means empty selection or a rejected/failed clipboard write. */
    public func copy(): Bool {
        actions().copy()
    }
    /** Deletes selection only after a successful copy; read-only controls return false. */
    public func cut(): Bool {
        actions().cut()
    }
    /** Pastes as one undo step; empty/failed clipboard reads leave selection intact. */
    public func paste(): Bool {
        actions().paste()
    }
    /** Whether this editable document has an undo step. */
    public func canUndo(): Bool {
        actions().canUndo()
    }
    /** Whether this editable document has a redo step. */
    public func canRedo(): Bool {
        actions().canRedo()
    }

    public func measure(ctx: UiContext, available: Size): Size {
        Size(available.w,
            max(CUI_CONTROL_H,
                inputAppearance.rowHeight(ctx, multiline: false) + ctx.resolve(inputAppearance.padding.top) +
                    ctx.resolve(inputAppearance.padding.bottom)))
    }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        frame = rect
        let actions: Array<SemanticsAction> = if (isEditable) {
            [SemanticsAction.Focus, SemanticsAction.SetValue("")]
        } else {
            [SemanticsAction.Focus]
        }
        ctx.registerSemanticProvider(id, rect, actions, {=> Semantics(role: SemanticsRole.TextField, value: text.value)},
            {
                action => match (action) {
                    case SemanticsAction.Focus =>
                        ctx.focus(id, viaKeyboard: true)
                        true
                    case SemanticsAction.SetValue(next) where isEditable && !next.contains("\u{0000}") =>
                        if (this.actions().replaceValue(next)) {
                            ctx.requestFrame()
                        }
                        true
                    case _ => false
                }
            })
    }

    public func draw(ctx: UiContext): Unit {
        if (ctx.isCaretOnlyPaint()) {
            if (ctx.caretPaintIntersects(frame)) {
                if (let Some(view) <- lastPaintView) {
                    view.draw(frame, id, isEditable, hint, lastPaintEpoch)
                }
            }
            return
        }
        let view = editorView(ctx)
        let shift = view.followHorizontal()
        if (shift != xOffset.value) {
            xOffset.value = shift
        }
        lastPaintView = Some(view)
        lastPaintEpoch = blink.epoch
        view.draw(frame, id, isEditable, hint, lastPaintEpoch)
    }

    /*
     * Horizontal caret follow. Values wider than the field slide left so the caret stays
     * visible: the window moves only when the caret leaves it (the usual desktop feel) and
     * is clamped so the text's tail never detaches from the right edge. Runs in draw, so
     * every way the caret moves — keys, clicks, undo, an external state write — is followed.
     */
    private func editorView(ctx: UiContext): TextEditorView {
        let edit = editState()
        let _ = blink.observe(ctx, id, edit, isEditable) // cjcheck-ignore: ignore-result # updates the epoch; single-line horizontal follow is recomputed every draw and needs no moved flag
        if (!isEditable && ctx.hasFocus(id)) {
            ctx.clearTextInputAnchor();
            ctx.clearImeComposition()
        }
        TextEditorView(ctx, frame, TextEditorDisplay(ctx, id, edit, isEditable), layoutCache,
            TextEditorViewState(inputAppearance, multiline: false, xShift: xOffset.value))
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        claimHoverIfInside(ctx, event, frame, id, CursorShape.Text)
        let edit = editState()
        match (event) {
            case UiEvent.MouseDown(MouseButton.Left, x, y) => return pressAt(ctx, edit, x, y)
            case UiEvent.MouseMove(x, y) =>
                if (ctx.isDragging(id) && ctx.leftMouseDown) {
                    let view = editorView(ctx)
                    edit.extendTo(view.hit(x, y)[0])
                    dragScroll.update(ctx, view.viewport, x, y, multiline: false, wrap: false)
                    return true
                }
            case UiEvent.MouseUp(MouseButton.Left, _, _) => dragScroll.active.value = false
            case UiEvent.TextEditing(value, start, length) =>
                if (ctx.hasFocus(id) && isEditable) {
                    ctx.setImeComposition(id, value, start, length)
                    return true
                }
            case UiEvent.TextEditingCandidates(values, selected, horizontal) =>
                if (ctx.hasFocus(id) && isEditable) {
                    ctx.setImeCandidates(id, values, selected, horizontal)
                    return true
                }
            case UiEvent.TextInput(value) => return inputText(ctx, value)
            case UiEvent.KeyDown(key, _) => return handleKey(ctx, edit, key)
            case UiEvent.Frame(_) =>
                // One-time initial focus, applied after the frame's pointer events so a stray
                // startup click cannot cancel it; later frames leave focus to the user.
                applyAutofocus(ctx)
                autoScroll(ctx)
            case _ => ()
        }
        false
    }

    private func handleKey(ctx: UiContext, edit: TextEditState, key: Key): Bool {
        match (key) {
            case Key.Enter =>
                if (!ctx.hasFocus(id) || !isEditable) {
                    return false
                }
                if (ctx.imeComposition(id).isSome()) {
                    return true
                }
                if (let Some(action) <- submitAction) {
                    history.breakGroup();
                    action(text.value);
                    return true
                }
                false
            case Key.Backspace => return recordedEdit(ctx, {
                => if (textWordModifier(ctx)) {
                    edit.deleteWordBackward()
                } else {
                    edit.backspace()
                }
            })
            case Key.Delete => return recordedEdit(ctx, {
                => if (textWordModifier(ctx)) {
                    edit.deleteWordForward()
                } else {
                    edit.deleteForward()
                }
            })
            case Key.Left =>
                if (textWordModifier(ctx)) {
                    return navigate(ctx, {=> edit.moveWordLeft()}, {=> edit.extendWordLeft()})
                }
                return navigate(ctx, {=> edit.moveLeft()}, {=> edit.extendLeft()})
            case Key.Right =>
                if (textWordModifier(ctx)) {
                    return navigate(ctx, {=> edit.moveWordRight()}, {=> edit.extendWordRight()})
                }
                return navigate(ctx, {=> edit.moveRight()}, {=> edit.extendRight()})
            case Key.Home => return navigate(ctx, {=> edit.moveToStart()}, {=> edit.extendToStart()})
            case Key.End => return navigate(ctx, {=> edit.moveToEnd()}, {=> edit.extendToEnd()})
            case Key.Letter(code) => return shortcut(ctx, edit, code)
            case _ => false
        }
    }

    public func focusableId(): ?String {
        textEditorFocusableId(id, isEditable)
    }

    private func editState(): TextEditState {
        TextEditState(text, cursorStateValue, anchorStateValue, boundaryCache)
    }

    private func actions(): TextEditorActions {
        TextEditorActions(editState(), history, clipboard, isEditable, multiline: false)
    }

    private func applyAutofocus(ctx: UiContext): Unit {
        focusTextEditorOnce(ctx, id, autofocusRequested, isEditable, autofocusDone)
    }

    private func autoScroll(ctx: UiContext): Unit {
        let view = editorView(ctx)
        if (dragScroll.step(ctx, id, view, requireFocus: isEditable)) {
            xOffset.value = view.xShift
            editState().extendTo(dragScroll.target(view)[0])
        }
    }

    private func pressAt(ctx: UiContext, edit: TextEditState, x: Float32, y: Float32): Bool {
        if (frame.contains(x, y)) {
            dragScroll.active.value = false
            ctx.focus(id)
            let offset = editorView(ctx).hit(x, y)[0]
            ctx.clearImeComposition()
            blink.epoch = ctx.frame.elapsedMs
            if (ctx.clickCount == 2) {
                edit.selectWordAt(offset)
            } else if (ctx.clickCount >= 3) {
                edit.selectLineAt(offset)
            } else {
                if (ctx.eventModifiers().shift) {
                    edit.extendTo(offset)
                } else {
                    edit.moveTo(offset)
                }
                ctx.beginDrag(id) // a press-drag extends the selection (see MouseMove)
            }
            history.breakGroup() // edits before and after a caret jump undo separately
            return true
        }
        false
    }

    // Runs a mutating action while focused and records it for undo. The before/after text
    // comparison means a no-op edit (e.g. Backspace at position 0) adds no undo step.
    private func inputText(ctx: UiContext, value: String): Bool {
        if (!ctx.hasFocus(id) || !isEditable) {
            return false
        }
        let composing = ctx.imeComposition(id).isSome()
        ctx.clearImeComposition()
        if (actions().insert(value, ctx.frame.elapsedMs, isolated: composing)) {
            ctx.requestFrame()
        }
        true
    }

    private func recordedEdit(ctx: UiContext, action: () -> Unit): Bool {
        if (!ctx.hasFocus(id) || !isEditable) {
            return false
        }
        if (ctx.imeComposition(id).isSome()) {
            return true
        }
        if (actions().record(ctx.frame.elapsedMs, action)) {
            ctx.requestFrame()
        }
        true
    }

    // Held Shift extends the selection; a plain arrow collapses it.
    private func navigate(ctx: UiContext, moveCaret: () -> Unit, growSelection: () -> Unit): Bool {
        if (!ctx.hasFocus(id)) {
            return false
        }
        if (ctx.imeComposition(id).isSome()) {
            return true
        }
        if (ctx.eventModifiers().shift) {
            growSelection()
        } else {
            moveCaret()
        }
        history.breakGroup() // edits before and after a caret jump undo separately
        true
    }

    private func shortcut(ctx: UiContext, _: TextEditState, code: UInt8): Bool {
        handleEditorShortcut(ctx, id, code, actions())
    }
}
