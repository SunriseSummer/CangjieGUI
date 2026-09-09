package cui.controls

import sdl.{Color, FontSizes, Key, MouseButton, Rect, Size, UiEvent}
import cui.core.{rekeyControl, clampItemIndex, Bindable, CUI_CONTROL_H, CUI_SMALL_H, CursorShape, ScrollBar,
    maxScrollOffset, Semantics, SemanticsAction, SemanticsRole, Spring, State, UiContext, Widget, requireControlId,
    claimHoverIfInside, clampScrollOffset, drawFocusRing, drawSurface, drawVerticalScrollBar, emit,
    focusableControlIdentity, localState, scrollLineIndex, scrollLineRemainder, scrollByWheel}

/*
 * A labelled on/off toggle bound to a `Bindable<Bool>`, with an animated check fill.
 * Click or Space/Enter toggles; a focus stop in Tab traversal.
 */
public class Checkbox <: Widget {
    private let label: String
    private let checked: Bindable<Bool>
    private var controlId: String
    private let fillSpring: Spring
    private var frame = Rect.zero()

    public init(label: String, checked: Bindable<Bool>) {
        this.label = label
        this.checked = checked
        this.controlId = focusableControlIdentity("Checkbox:${label}")
        // The check fill scales in when ticked. Retained across rebuilds and started at the
        // current state, so a static first frame is settled (snapshot-stable).
        let checkStart: Float32 = if (checked.value) {
            1.0
        } else {
            0.0
        }
        this.fillSpring = localState<Spring>("${this.controlId}:fill") {Spring(checkStart)}.value
        emit(this)
    }

    /**
     * Sets an explicit focus and press identity; defaults are unique per build.
     * Throws `IllegalArgumentException` when `value` is empty.
     */
    public func key(value: String): Checkbox {
        controlId = rekeyControl(controlId, value, "Checkbox")
        this
    }

    public func measure(ctx: UiContext, available: Size): Size {
        Size(min(available.w, ctx.textWidth(label) + 34.0), ctx.textRowHeight(minHeight: CUI_CONTROL_H, padding: 12.0))
    }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        frame = rect
        ctx.registerSemanticProvider(controlId, rect, [SemanticsAction.Activate],
            {=> Semantics(label: label, role: SemanticsRole.Checkbox, checked: Some(checked.value))}, {
                action => match (action) {
                    case SemanticsAction.Activate =>
                        checked.value = !checked.value
                        true
                    case _ => false
                }
            })
    }

    public func draw(ctx: UiContext): Unit {
        let goal: Float32 = if (checked.value) {
            1.0
        } else {
            0.0
        }
        let t = fillSpring.animate(ctx, target: goal)
        let box = Rect(frame.x, frame.y + 7.0, 18.0, 18.0)
        drawSurface(ctx, box, ctx.theme.fieldSurface().withBorder(ctx.theme.panelEdge.lerp(ctx.theme.accent, t)))
        // The fill grows from the centre to fill the box as it is ticked.
        if (t > 0.001) {
            let full = box.inset(4.0)
            let w = full.w * t
            let h = full.h * t
            let mark = Rect(full.centerX() - w / 2.0, full.centerY() - h / 2.0, w, h)
            ctx.renderer.fillRoundedRect(mark, ctx.theme.smallRadius * t, ctx.theme.accent)
        }
        let textY = frame.centerY() - ctx.textHeight(pointSize: ctx.textSize(fallback: FontSizes.CONTROL)) / 2.0
        ctx.text(label, frame.x + 26.0, textY, ctx.theme.text, pointSize: ctx.textSize(fallback: FontSizes.CONTROL))
        if (ctx.showFocusRing(controlId)) {
            drawFocusRing(ctx, box, ctx.theme.smallRadius)
        }
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        claimHoverIfInside(ctx, event, frame, controlId, CursorShape.Interactive)
        match (event) {
            case UiEvent.MouseDown(MouseButton.Left, x, y) =>
                if (frame.contains(x, y)) {
                    ctx.focus(controlId)
                    ctx.press(controlId)
                    return true
                }
            case UiEvent.MouseUp(MouseButton.Left, x, y) =>
                if (ctx.isPressed(controlId)) {
                    if (frame.contains(x, y)) {
                        checked.value = !checked.value
                    }
                    return true
                }
            case UiEvent.KeyDown(Key.Enter, _) =>
                if (ctx.hasFocus(controlId)) {
                    checked.value = !checked.value
                    return true
                }
            case UiEvent.KeyDown(Key.Space, _) =>
                if (ctx.hasFocus(controlId)) {
                    checked.value = !checked.value
                    return true
                }
            case _ => ()
        }
        false
    }

    public func focusableId(): ?String {
        Some(controlId)
    }
}

/*
 * A scrollable single-selection list of strings bound to a `Bindable<Int64>` index, with
 * a scroll bar and keyboard support (Up/Down move, Home/End jump). A changed selection is
 * scrolled into view; plain wheel/drag scrolling is left alone.
 */
public class ListView <: Widget {
    private let items: Array<String>
    private let selected: Bindable<Int64>
    private var scrollStateValue: State<Float32>
    private let controlId: String
    private let scrollBar: ScrollBar
    // The selection last scrolled into view, retained across rebuilds. Draw reveals the selected
    // row only when it differs — so a changed selection (however it changed) scrolls into view,
    // but plain wheel/drag scrolling (selection unchanged) is left alone.
    private let lastRevealed: State<Int64>
    private var frame = Rect.zero()
    private var rowHeight: Float32 = CUI_SMALL_H

    public init(
        items: Array<String>,
        selected: Bindable<Int64>,
        scroll!: ?State<Float32> = None,
        key!: ?String = None
    ) {
        this.items = items
        this.selected = selected
        // Identity is optional and auto-derived by build order by default (like SegmentedControl and
        // TabView); pass `key` to give it a stable, addressable identity — e.g. to keep scroll/selection
        // state across a structural change or to coordinate scroll externally. Non-empty when given.
        let base = match (key) {
            case Some(value) =>
                requireControlId(value, "ListView")
                value
            case None => "ListView"
        }
        let cid = focusableControlIdentity(base)
        this.controlId = cid
        // Without an external scroll state, retain the offset across the per-frame rebuild via
        // localState keyed by control id — a fresh State each frame would reset the offset, so
        // wheel/drag scrolling would spring back every frame.
        this.scrollStateValue = match (scroll) {
            case Some(value) => value
            case None => localState<Float32>("${cid}:scroll") {0.0}
        }
        this.scrollBar = ScrollBar("ListView:${cid}:thumb")
        this.lastRevealed = localState<Int64>("${cid}:revealed") {Int64.Min}
        emit(this)
    }

    /** Uses an externally owned scroll offset, enabling restoration and coordination. */
    public func scrollState(value: State<Float32>): ListView {
        scrollStateValue = value
        this
    }

    public func measure(ctx: UiContext, available: Size): Size {
        rowHeight = ctx.textRowHeight()
        Size(available.w, available.h)
    }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        rowHeight = ctx.textRowHeight()
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        // Clamp writes only on change: this runs every frame, and the offset may be an
        // externally owned state whose observers should not fire for no-op writes.
        let clampedScroll = clampScrollOffset(scrollStateValue.value, listContentHeight(items, rowHeight: rowHeight),
            listViewport(frame).h)
        if (clampedScroll != scrollStateValue.value) {
            scrollStateValue.value = clampedScroll
        }
        // Reveal the selected row when the selection changed since the last frame — this catches
        // selections driven from outside the list (e.g. app-level key routing) that never reached
        // this widget's own key handling. Unchanged selection (plain scrolling) is left untouched.
        if (selected.value != lastRevealed.value) {
            revealRow(selected.value)
            lastRevealed.value = selected.value
        }
        drawSurface(ctx, frame, ctx.theme.fieldSurface(active: ctx.showFocusRing(controlId)))

        let viewport = listViewport(frame)
        ctx.renderer.pushClip(viewport)
        var i = scrollLineIndex(scrollStateValue.value, rowHeight: rowHeight)
        var y = viewport.y - scrollLineRemainder(scrollStateValue.value, rowHeight: rowHeight)
        while (i < items.size && y < viewport.bottom()) {
            drawRow(ctx, i, Rect(viewport.x, y, viewport.w, rowHeight))
            y += rowHeight
            i += 1
        }
        ctx.renderer.popClip()
        drawVerticalScrollBar(ctx, frame, scrollStateValue.value, listContentHeight(items, rowHeight: rowHeight),
            viewport.h, active: scrollBar.dragging(ctx))
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        claimHoverIfInside(ctx, event, frame, controlId, CursorShape.Interactive)
        let contentH = listContentHeight(items, rowHeight: rowHeight)
        let viewportH = listViewport(frame).h
        match (event) {
            case UiEvent.MouseDown(MouseButton.Left, x, y) =>
                if (scrollBar.press(ctx, frame, scrollStateValue, contentH, viewportH, x, y)) {
                    return true
                }
                if (frame.contains(x, y)) {
                    ctx.focus(controlId)
                    // Presses on the chrome inset around the rows are consumed without
                    // selecting; row math is only valid inside the viewport.
                    let viewport = listViewport(frame)
                    if (viewport.contains(x, y)) {
                        let idx = Int64((y - viewport.y + scrollStateValue.value) / rowHeight)
                        if (idx >= 0 && idx < items.size) {
                            selected.value = idx
                        }
                    }
                    return true
                }
            case UiEvent.MouseMove(_, y) =>
                if (scrollBar.drag(ctx, frame, scrollStateValue, contentH, viewportH, y)) {
                    return true
                }
            case UiEvent.MouseWheel(_, wheelY, pointerX, pointerY) =>
                // Content that fits leaves the wheel to an enclosing scroller (no dead zone).
                if (frame.contains(pointerX, pointerY) && maxScrollOffset(contentH, viewportH) > 0.0) {
                    return scrollByWheel(scrollStateValue, wheelY, contentH, viewportH)
                }
            case UiEvent.KeyDown(Key.Up, _) => return moveSelection(ctx, -1)
            case UiEvent.KeyDown(Key.Down, _) => return moveSelection(ctx, 1)
            case UiEvent.KeyDown(Key.Home, _) => return setSelection(ctx, 0)
            case UiEvent.KeyDown(Key.End, _) => return setSelection(ctx, items.size - 1)
            case _ => ()
        }
        false
    }

    public func isFlexible(): Bool {
        true
    }

    public func focusableId(): ?String {
        Some(controlId)
    }

    // Arrow/Home/End move the selection when the list holds keyboard focus, keeping the new
    // row scrolled into view.
    private func moveSelection(ctx: UiContext, delta: Int64): Bool {
        if (!ctx.hasFocus(controlId) || items.isEmpty()) {
            return false
        }
        applySelection(clampIndex(selected.value + delta))
        true
    }

    private func setSelection(ctx: UiContext, index: Int64): Bool {
        if (!ctx.hasFocus(controlId) || items.isEmpty()) {
            return false
        }
        applySelection(clampIndex(index))
        true
    }

    private func clampIndex(index: Int64): Int64 {
        clampItemIndex(index, items.size)
    }

    private func applySelection(index: Int64): Unit {
        selected.value = index
        // Scroll immediately (this frame's handle) and sync lastRevealed so draw does not redo it.
        revealRow(index)
        lastRevealed.value = index
    }

    // Scrolls the given row's band just into view, adjusting the offset minimally.
    private func revealRow(index: Int64): Unit {
        let viewportH = listViewport(frame).h
        let rowTop = Float32(index) * rowHeight
        let rowBottom = rowTop + rowHeight
        var scroll = scrollStateValue.value
        if (rowTop < scroll) {
            scroll = rowTop
        } else if (rowBottom > scroll + viewportH) {
            scroll = rowBottom - viewportH
        }
        scrollStateValue.value = clampScrollOffset(scroll, listContentHeight(items, rowHeight: rowHeight), viewportH)
    }

    private func drawRow(ctx: UiContext, i: Int64, row: Rect): Unit {
        if (i == selected.value) {
            ctx.renderer.fillRoundedRect(row.inset(2.0), ctx.theme.smallRadius, ctx.theme.accent)
            drawRowText(ctx, items[i], row, ctx.theme.accentText)
        } else {
            drawRowText(ctx, items[i], row, ctx.theme.text)
        }
    }
}

private func drawRowText(ctx: UiContext, text: String, row: Rect, color: Color): Unit {
    let textY = row.centerY() - ctx.textHeight(pointSize: ctx.textSize(fallback: FontSizes.BODY)) / 2.0
    ctx.text(text, row.x + 6.0, textY, color, pointSize: ctx.textSize(fallback: FontSizes.BODY))
}

private func listContentHeight(items: Array<String>, rowHeight!: Float32 = CUI_SMALL_H): Float32 {
    Float32(items.size) * rowHeight
}

private func listViewport(frame: Rect): Rect {
    Rect(frame.x + 4.0, frame.y + 6.0, max(0.0, frame.w - 12.0), max(0.0, frame.h - 12.0))
}
