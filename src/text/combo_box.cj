package cui.text

import std.collection.ArrayList
import sdl.{Color, FontSizes, Key, MouseButton, Pen, Rect, Size, SurfaceStyle, UiEvent}
import cui.core.{Bindable, CUI_CONTROL_H, CUI_SMALL_H, Overlay, ScrollBar, State, UiContext, Widget, resolveControlKey, buildChild,
    clampScrollOffset, drawSurface, drawVerticalScrollBar, emit, localState, scrollBarGutter, scrollOffsetAfterWheel}

private let COMBO_POPUP_PAD: Float32 = 5.0
private let COMBO_GAP: Float32 = 4.0
private let COMBO_MARGIN: Float32 = 4.0
private let COMBO_CHEVRON_W: Float32 = 30.0

/*
 * An editable dropdown (combo box): a text field the user can type into, plus a list of
 * suggestions. It composes an embedded `TextField` (so it inherits full editing — cursor,
 * selection, undo, clipboard) with the interactive overlay used by menus and dropdowns to float
 * the suggestion list. Typing filters the list; clicking a suggestion or pressing Enter fills the
 * field. The bound `text` is the value — freely typed text is kept even if it matches no option.
 *
 * A suggestion list taller than the space around the field scrolls inside the popup: mouse
 * wheel, a draggable scrollbar in the standard lane, and arrow keys that keep the highlight in
 * view. The popup opens on whichever side (below, else above) has room.
 */
public class ComboBox <: Widget {
    private let fieldId: String
    private let text: Bindable<String>
    private let options: Array<String>
    private let cursorState: State<Int64>
    private let anchorState: State<Int64>
    private let field: Widget
    private let open: State<Bool>
    private let highlight: State<Int64>
    // Identifies this control's popup on the overlay stack across per-frame rebuilds, so
    // closing removes exactly its own registration (a dialog beneath it stays open).
    private let overlayOwner: String
    // Scroll offset of the suggestion list, retained across the per-frame rebuild while open.
    private let popupScroll: State<Float32>
    private let popupBar: ScrollBar
    private var frame = Rect.zero()

    public init(text: Bindable<String>, options: Array<String>, key!: ?String = None) {
        let ident = resolveControlKey(key, "ComboBox")
        this.fieldId = ident
        this.text = text
        this.options = options
        // Own the field's caret and anchor, so choosing a suggestion can move the caret to the
        // end and collapse the selection (otherwise a stale anchor leaves the value highlighted).
        let cursor = localState<Int64>("ComboBox:${ident}:cursor") {text.value.size}
        let anchor = localState<Int64>("ComboBox:${ident}:anchor") {text.value.size}
        this.cursorState = cursor
        this.anchorState = anchor
        // The embedded field shares this control's identity (so focus and state line up), passed as
        // its explicit key.
        this.field = buildChild({=> TextField(text, key: ident, cursor: Some(cursor), anchor: Some(anchor))})
        this.overlayOwner = "ComboBox:${ident}"
        this.open = localState<Bool>("ComboBox:${ident}:open") {false}
        this.highlight = localState<Int64>("ComboBox:${ident}:hl") {0}
        this.popupScroll = localState<Float32>("ComboBox:${ident}:popupScroll") {0.0}
        this.popupBar = ScrollBar("ComboBox:${ident}:popupBar")
        emit(this)
    }

    public func measure(_: UiContext, available: Size): Size {
        Size(available.w, CUI_CONTROL_H)
    }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        frame = rect
        field.layout(ctx, rect)
    }

    public func draw(ctx: UiContext): Unit {
        field.draw(ctx)
        drawChevron(ctx)
        if (open.value) {
            let popup = popupRect(ctx, filteredOptions())
            ctx.setOverlay(Overlay(handleEvent: {c, e => handleOverlay(c, e, popup)},
                render: {c => drawPopup(c, popup)}, owner: overlayOwner))
        }
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        match (event) {
            case UiEvent.MouseDown(MouseButton.Left, x, y) =>
                if (chevronRect().contains(x, y)) {
                    toggleOpen(ctx)
                    return true
                }
            case UiEvent.KeyDown(Key.Down, _) =>
                if (ctx.hasFocus(fieldId) && !open.value) {
                    openList(ctx)
                    return true
                }
            case _ => ()
        }
        // Everything else — typing, caret clicks, shortcuts — is the embedded field's job.
        field.handle(ctx, event)
    }

    public func isFlexible(): Bool {
        false
    }

    public func focusableId(): ?String {
        Some(fieldId) // the embedded field owns the focus stop
    }

    private func toggleOpen(ctx: UiContext): Unit {
        if (open.value) {
            close(ctx)
        } else {
            openList(ctx)
        }
    }

    private func openList(ctx: UiContext): Unit {
        open.value = true
        highlight.value = 0
        popupScroll.value = 0.0 // the highlight restarts at the top, so the list does too
        ctx.focus(fieldId) // keep the field focused so typing filters the open list
    }

    private func contentHeight(filtered: Array<String>): Float32 {
        Float32(max(1, filtered.size)) * CUI_SMALL_H
    }

    private func listHeight(popup: Rect): Float32 {
        max(0.0, popup.h - COMBO_POPUP_PAD * 2.0)
    }

    /** The inner list area: the popup minus its top and bottom padding strips. */
    private func listRect(popup: Rect): Rect {
        Rect(popup.x, popup.y + COMBO_POPUP_PAD, popup.w, listHeight(popup))
    }

    private func close(ctx: UiContext): Unit {
        open.value = false
        ctx.removeOverlay(overlayOwner)
    }

    /*
     * Overlay handler while the list is open. It claims list clicks, dismissal, and list
     * navigation, but returns false for typing so those events fall through to the focused field
     * (which re-filters the list as the text changes).
     */
    private func handleOverlay(ctx: UiContext, event: UiEvent, popup: Rect): Bool {
        let filtered = filteredOptions()
        match (event) {
            case UiEvent.MouseDown(MouseButton.Left, x, y) =>
                if (popup.contains(x, y)) {
                    if (popupBar.press(ctx, listRect(popup), popupScroll, contentHeight(filtered),
                        listHeight(popup), x, y)) {
                        return true // the press grabbed the scrollbar; the popup stays open
                    }
                    commit(ctx, filtered, itemIndexAt(popup, y))
                    return true
                }
                close(ctx)
                // A press on the chevron toggles closed; any other outside press dismisses and is
                // let through (e.g. to reposition the caret or focus another control).
                chevronRect().contains(x, y)
            case UiEvent.MouseMove(_, y) =>
                // While the thumb is grabbed the move scrolls the list; hover falls through.
                popupBar.drag(ctx, listRect(popup), popupScroll, contentHeight(filtered), listHeight(popup), y)
            case UiEvent.MouseWheel(_, wheelY, x, y) =>
                if (popup.contains(x, y)) {
                    popupScroll.value = scrollOffsetAfterWheel(popupScroll.value, wheelY, contentHeight(filtered),
                        listHeight(popup))
                    return true
                }
                false
            case UiEvent.KeyDown(Key.Escape, _) =>
                close(ctx)
                true
            case UiEvent.KeyDown(Key.Enter, _) =>
                // Clamp: typing may have shrunk the list below the highlighted index.
                commit(ctx, filtered, clampComboIndex(highlight.value, filtered.size))
                true
            case UiEvent.KeyDown(Key.Down, _) =>
                moveHighlight(1, filtered, popup)
                true
            case UiEvent.KeyDown(Key.Up, _) =>
                moveHighlight(-1, filtered, popup)
                true
            case UiEvent.KeyDown(Key.Tab, _) =>
                close(ctx) // commit the typed text and let the shell's Tab traversal move on
                false
            case _ => false // typing falls through to the field
        }
    }

    private func moveHighlight(delta: Int64, filtered: Array<String>, popup: Rect): Unit {
        highlight.value = clampComboIndex(highlight.value + delta, filtered.size)
        revealRow(highlight.value, filtered, popup)
    }

    // Scrolls just enough to keep the highlighted row visible — the reveal convention
    // shared with ListView and Table keyboard navigation.
    private func revealRow(index: Int64, filtered: Array<String>, popup: Rect): Unit {
        let listH = listHeight(popup)
        let rowTop = Float32(index) * CUI_SMALL_H
        var next = popupScroll.value
        if (rowTop < next) {
            next = rowTop
        }
        if (rowTop + CUI_SMALL_H > next + listH) {
            next = rowTop + CUI_SMALL_H - listH
        }
        let clamped = clampScrollOffset(next, contentHeight(filtered), listH)
        if (clamped != popupScroll.value) {
            popupScroll.value = clamped
        }
    }

    // Fills the field with the chosen suggestion (caret to end, no selection) and closes.
    private func commit(ctx: UiContext, filtered: Array<String>, index: Int64): Unit {
        if (index >= 0 && index < filtered.size) {
            text.value = filtered[index]
            cursorState.value = filtered[index].size
            anchorState.value = filtered[index].size
        }
        close(ctx)
    }

    private func filteredOptions(): Array<String> {
        let query = text.value.toAsciiLower()
        if (query.isEmpty()) {
            return options
        }
        let result = ArrayList<String>()
        for (option in options) {
            if (option.toAsciiLower().contains(query)) {
                result.add(option)
            }
        }
        result.toArray()
    }

    private func chevronRect(): Rect {
        Rect(frame.right() - COMBO_CHEVRON_W, frame.y, COMBO_CHEVRON_W, frame.h)
    }

    // Maps a pointer y inside the popup to an item index, honouring the scroll offset.
    // The padding strips above and below the list hit nothing (-1).
    private func itemIndexAt(popup: Rect, y: Float32): Int64 {
        if (y < popup.y + COMBO_POPUP_PAD || y >= popup.bottom() - COMBO_POPUP_PAD) {
            return -1
        }
        Int64((y - popup.y - COMBO_POPUP_PAD + popupScroll.value) / CUI_SMALL_H)
    }

    /*
     * Anchors the popup below the field, flipping above when only the space above fits the
     * whole list. When neither side fits, it opens on the roomier side at that side's height
     * and the list scrolls inside (see drawPopup). At least one row is kept: with no matches
     * the popup shows a placeholder instead of collapsing to a sliver of empty chrome.
     */
    private func popupRect(ctx: UiContext, filtered: Array<String>): Rect {
        let fullHeight = contentHeight(filtered) + COMBO_POPUP_PAD * 2.0
        let below = max(0.0, ctx.viewportHeight - COMBO_MARGIN - (frame.bottom() + COMBO_GAP))
        let above = max(0.0, frame.y - COMBO_GAP - COMBO_MARGIN)
        if (fullHeight <= below) {
            return Rect(frame.x, frame.bottom() + COMBO_GAP, frame.w, fullHeight)
        }
        if (fullHeight <= above) {
            return Rect(frame.x, frame.y - COMBO_GAP - fullHeight, frame.w, fullHeight)
        }
        let height = max(CUI_SMALL_H + COMBO_POPUP_PAD * 2.0, max(below, above))
        if (below >= above) {
            Rect(frame.x, frame.bottom() + COMBO_GAP, frame.w, height)
        } else {
            Rect(frame.x, frame.y - COMBO_GAP - height, frame.w, height)
        }
    }

    private func drawPopup(ctx: UiContext, popup: Rect): Unit {
        let filtered = filteredOptions()
        let active = clampComboIndex(highlight.value, filtered.size)
        drawSurface(ctx, popup, popupSurface(ctx))
        let contentH = contentHeight(filtered)
        let listH = listHeight(popup)
        let list = listRect(popup)
        // Typing re-filters the list while open; keep the retained offset within range.
        let offset = clampScrollOffset(popupScroll.value, contentH, listH)
        if (offset != popupScroll.value) {
            popupScroll.value = offset
        }
        ctx.renderer.pushClip(list)
        if (filtered.isEmpty()) {
            // No suggestion matches the typed text; clicking the placeholder just dismisses.
            let row = Rect(popup.x + 4.0, list.y, max(0.0, popup.w - 8.0), CUI_SMALL_H)
            drawRowLabel(ctx, "—", row, ctx.theme.mutedText)
            ctx.renderer.popClip()
            return
        }
        let gutter: Float32 = if (contentH > listH) {
            scrollBarGutter()
        } else {
            0.0
        }
        let rowW = max(0.0, popup.w - 8.0 - gutter)
        var i = Int64(offset / CUI_SMALL_H)
        var y = list.y - (offset - Float32(i) * CUI_SMALL_H)
        while (i < filtered.size && y < list.bottom()) {
            let row = Rect(popup.x + 4.0, y, rowW, CUI_SMALL_H)
            if (i == active) {
                ctx.renderer.fillRoundedRect(row, ctx.theme.smallRadius, ctx.theme.accent)
                drawRowLabel(ctx, filtered[i], row, ctx.theme.accentText)
            } else if (row.contains(ctx.mouseX, ctx.mouseY)) {
                ctx.renderer.fillRoundedRect(row, ctx.theme.smallRadius, ctx.theme.fieldActive)
                drawRowLabel(ctx, filtered[i], row, ctx.theme.text)
            } else {
                drawRowLabel(ctx, filtered[i], row, ctx.theme.text)
            }
            y += CUI_SMALL_H
            i += 1
        }
        ctx.renderer.popClip()
        drawVerticalScrollBar(ctx, list, offset, contentH, listH, active: popupBar.dragging(ctx))
    }

    private func drawChevron(ctx: UiContext): Unit {
        let cx = frame.right() - 18.0
        let cy = frame.centerY()
        let pen = Pen(width: 1.6, color: ctx.theme.mutedText)
        ctx.renderer.strokeLine(cx - 4.0, cy - 2.0, cx, cy + 2.5, pen)
        ctx.renderer.strokeLine(cx, cy + 2.5, cx + 4.0, cy - 2.0, pen)
    }

    private func drawRowLabel(ctx: UiContext, label: String, row: Rect, color: Color): Unit {
        let textY = row.centerY() - ctx.renderer.textHeight(pointSize: FontSizes.CONTROL) / 2.0
        ctx.renderer.text(label, row.x + 8.0, textY, color, pointSize: FontSizes.CONTROL)
    }

    private func popupSurface(ctx: UiContext): SurfaceStyle {
        SurfaceStyle(ctx.theme.panelRaised, border: ctx.theme.panelEdge, radius: ctx.theme.controlRadius,
            borderWidth: 1.0, shadow: ctx.theme.shadow, shadowOffsetY: 4.0)
    }
}

private func clampComboIndex(index: Int64, count: Int64): Int64 {
    if (count <= 0) {
        0
    } else if (index < 0) {
        0
    } else if (index >= count) {
        count - 1
    } else {
        index
    }
}
