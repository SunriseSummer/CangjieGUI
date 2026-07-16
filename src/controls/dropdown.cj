package cui.controls

import sdl.{Color, FontSizes, Key, MouseButton, Pen, Rect, Size, SurfaceStyle, UiEvent}
import cui.core.{Bindable, CUI_CONTROL_H, CUI_SMALL_H, CursorShape, Overlay, ScrollBar, State, UiContext, Widget, resolveControlKey,
    claimHoverIfInside, clampScrollOffset, drawSurface, drawVerticalScrollBar, emit, localState, registerFocusable,
    scrollBarGutter, scrollOffsetAfterWheel}

private let DROPDOWN_DEFAULT_W: Float32 = 190.0
private let DROPDOWN_POPUP_PAD: Float32 = 5.0
private let DROPDOWN_GAP: Float32 = 4.0
private let DROPDOWN_MARGIN: Float32 = 4.0

/*
 * A dropdown select: a closed box showing the current item, and, when opened, a popup list
 * floated above the tree via the interactive overlay. Clicking an item selects and closes;
 * clicking outside or pressing Escape dismisses; arrows move the highlight while open. Because
 * the popup is an overlay, its clicks are never stolen by whatever is drawn beneath it.
 *
 * A list taller than the space around the control scrolls inside the popup: mouse wheel, a
 * draggable scrollbar in the standard lane, and arrow keys that keep the highlight in view.
 * The popup opens on whichever side (below, else above) has room, with the selected row
 * scrolled into view.
 */
public class Dropdown <: Widget {
    private let id: String
    private let items: Array<String>
    private let selected: Bindable<Int64>
    private let open: State<Bool>
    // Identifies this control's popup on the overlay stack across per-frame rebuilds, so
    // closing removes exactly its own registration (a dialog beneath it stays open).
    private let overlayOwner: String
    // Scroll offset of the popup list, retained across the per-frame rebuild while open.
    private let popupScroll: State<Float32>
    private let popupBar: ScrollBar
    private var frame = Rect.zero()

    public init(items: Array<String>, selected: Bindable<Int64>, key!: ?String = None) {
        let ident = resolveControlKey(key, "Dropdown")
        this.id = ident
        this.items = items
        this.selected = selected
        this.overlayOwner = "Dropdown:${ident}"
        this.open = localState<Bool>("Dropdown:${ident}:open") {false}
        this.popupScroll = localState<Float32>("Dropdown:${ident}:popupScroll") {0.0}
        this.popupBar = ScrollBar("Dropdown:${ident}:popupBar")
        registerFocusable(ident)
        emit(this)
    }

    public func measure(_: UiContext, available: Size): Size {
        Size(min(available.w, DROPDOWN_DEFAULT_W), CUI_CONTROL_H)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        drawSurface(ctx, frame, ctx.theme.fieldSurface(ctx.showFocusRing(id) || open.value))
        let labelArea = Rect(frame.x + 10.0, frame.y, max(0.0, frame.w - 40.0), frame.h)
        ctx.renderer.pushClip(labelArea)
        let textY = frame.centerY() - ctx.renderer.textHeight(pointSize: FontSizes.CONTROL) / 2.0
        ctx.renderer.text(currentLabel(), labelArea.x, textY, ctx.theme.text, pointSize: FontSizes.CONTROL)
        ctx.renderer.popClip()
        drawChevron(ctx)

        // While open, register the popup as the interactive overlay: it is drawn on top and
        // gets events before the tree (see the shell's dispatch order).
        if (open.value) {
            let popup = popupRect(ctx)
            ctx.setOverlay(Overlay(handleEvent: {c, e => handleOverlay(c, e, popup)},
                render: {c => drawPopup(c, popup)}, owner: overlayOwner))
        }
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        claimHoverIfInside(ctx, event, frame, id, CursorShape.Interactive)
        match (event) {
            case UiEvent.MouseDown(MouseButton.Left, x, y) =>
                if (frame.contains(x, y)) {
                    ctx.focus(id)
                    openPopup(ctx) // when already open the overlay handles the click, not this
                    return true
                }
            case UiEvent.KeyDown(Key.Enter, _) => return openIfFocused(ctx)
            case UiEvent.KeyDown(Key.Space, _) => return openIfFocused(ctx)
            case UiEvent.KeyDown(Key.Down, _) => return openIfFocused(ctx)
            case _ => ()
        }
        false
    }

    public func focusableId(): ?String {
        Some(id)
    }

    private func openIfFocused(ctx: UiContext): Bool {
        if (ctx.hasFocus(id)) {
            openPopup(ctx)
            return true
        }
        false
    }

    // Opens the popup with the selected row scrolled into view (centred when the list is
    // long), so reopening never lands far from the current value.
    private func openPopup(ctx: UiContext): Unit {
        open.value = true
        let listH = listHeight(popupRect(ctx))
        let target = Float32(selected.value) * CUI_SMALL_H - (listH - CUI_SMALL_H) / 2.0
        popupScroll.value = clampScrollOffset(target, contentHeight(), listH)
    }

    private func contentHeight(): Float32 {
        Float32(items.size) * CUI_SMALL_H
    }

    private func listHeight(popup: Rect): Float32 {
        max(0.0, popup.h - DROPDOWN_POPUP_PAD * 2.0)
    }

    /** The inner list area: the popup minus its top and bottom padding strips. */
    private func listRect(popup: Rect): Rect {
        Rect(popup.x, popup.y + DROPDOWN_POPUP_PAD, popup.w, listHeight(popup))
    }

    // The overlay event handler while the popup is open. Runs before the tree, so it can claim
    // clicks that land on the popup and dismiss on clicks that land elsewhere.
    private func handleOverlay(ctx: UiContext, event: UiEvent, popup: Rect): Bool {
        match (event) {
            case UiEvent.MouseDown(MouseButton.Left, x, y) =>
                if (popup.contains(x, y)) {
                    if (popupBar.press(ctx, listRect(popup), popupScroll, contentHeight(), listHeight(popup), x, y)) {
                        return true // the press grabbed the scrollbar; the popup stays open
                    }
                    let index = itemIndexAt(popup, y)
                    if (index >= 0 && index < items.size) {
                        selected.value = index
                    }
                }
                close(ctx) // select-and-close, or dismiss on an outside click
                true
            case UiEvent.MouseMove(x, y) =>
                // While the thumb is grabbed the move scrolls the list; hover falls through, though the
                // popup still claims the default cursor so a control beneath cannot set its shape through it.
                if (popup.contains(x, y)) {
                    ctx.claimHover(overlayOwner, CursorShape.Default)
                }
                popupBar.drag(ctx, listRect(popup), popupScroll, contentHeight(), listHeight(popup), y)
            case UiEvent.MouseWheel(_, wheelY, x, y) =>
                if (popup.contains(x, y)) {
                    popupScroll.value = scrollOffsetAfterWheel(popupScroll.value, wheelY, contentHeight(),
                        listHeight(popup))
                    return true
                }
                false
            case UiEvent.KeyDown(Key.Escape, _) =>
                close(ctx)
                true
            case UiEvent.KeyDown(Key.Enter, _) =>
                close(ctx)
                true
            case UiEvent.KeyDown(Key.Space, _) =>
                close(ctx)
                true
            case UiEvent.KeyDown(Key.Down, _) =>
                moveHighlight(1, popup)
                true
            case UiEvent.KeyDown(Key.Up, _) =>
                moveHighlight(-1, popup)
                true
            case UiEvent.KeyDown(Key.Tab, _) =>
                close(ctx) // commit and let the shell's Tab traversal move focus on
                false
            case _ => false
        }
    }

    private func close(ctx: UiContext): Unit {
        open.value = false
        ctx.removeOverlay(overlayOwner)
    }

    private func moveHighlight(delta: Int64, popup: Rect): Unit {
        if (items.isEmpty()) {
            return
        }
        // Clamp the current index into range before stepping (matching SegmentedControl/TabView),
        // so the move is relative to the displayed selection and the addition cannot overflow.
        selected.value = clampDropdownIndex(clampDropdownIndex(selected.value, items.size) + delta, items.size)
        revealRow(selected.value, popup)
    }

    // Scrolls just enough to keep the highlighted row visible — the reveal convention
    // shared with ListView and Table keyboard navigation.
    private func revealRow(index: Int64, popup: Rect): Unit {
        let listH = listHeight(popup)
        let rowTop = Float32(index) * CUI_SMALL_H
        var next = popupScroll.value
        if (rowTop < next) {
            next = rowTop
        }
        if (rowTop + CUI_SMALL_H > next + listH) {
            next = rowTop + CUI_SMALL_H - listH
        }
        let clamped = clampScrollOffset(next, contentHeight(), listH)
        if (clamped != popupScroll.value) {
            popupScroll.value = clamped
        }
    }

    // Maps a pointer y inside the popup to an item index, honouring the scroll offset.
    // The padding strips above and below the list hit nothing (-1).
    private func itemIndexAt(popup: Rect, y: Float32): Int64 {
        if (y < popup.y + DROPDOWN_POPUP_PAD || y >= popup.bottom() - DROPDOWN_POPUP_PAD) {
            return -1
        }
        Int64((y - popup.y - DROPDOWN_POPUP_PAD + popupScroll.value) / CUI_SMALL_H)
    }

    /*
     * Anchors the popup below the control, flipping above when only the space above fits the
     * whole list. When neither side fits, it opens on the roomier side at that side's height
     * and the list scrolls inside (see drawPopup).
     */
    private func popupRect(ctx: UiContext): Rect {
        let fullHeight = contentHeight() + DROPDOWN_POPUP_PAD * 2.0
        let below = max(0.0, ctx.viewportHeight - DROPDOWN_MARGIN - (frame.bottom() + DROPDOWN_GAP))
        let above = max(0.0, frame.y - DROPDOWN_GAP - DROPDOWN_MARGIN)
        if (fullHeight <= below) {
            return Rect(frame.x, frame.bottom() + DROPDOWN_GAP, frame.w, fullHeight)
        }
        if (fullHeight <= above) {
            return Rect(frame.x, frame.y - DROPDOWN_GAP - fullHeight, frame.w, fullHeight)
        }
        let height = max(CUI_SMALL_H + DROPDOWN_POPUP_PAD * 2.0, max(below, above))
        if (below >= above) {
            Rect(frame.x, frame.bottom() + DROPDOWN_GAP, frame.w, height)
        } else {
            Rect(frame.x, frame.y - DROPDOWN_GAP - height, frame.w, height)
        }
    }

    private func drawPopup(ctx: UiContext, popup: Rect): Unit {
        drawSurface(ctx, popup, popupSurface(ctx))
        let contentH = contentHeight()
        let listH = listHeight(popup)
        let list = listRect(popup)
        // The item set can change while open; keep the retained offset within range.
        let offset = clampScrollOffset(popupScroll.value, contentH, listH)
        if (offset != popupScroll.value) {
            popupScroll.value = offset
        }
        let gutter: Float32 = if (contentH > listH) {
            scrollBarGutter()
        } else {
            0.0
        }
        let rowW = max(0.0, popup.w - 8.0 - gutter)
        ctx.renderer.pushClip(list)
        var i = Int64(offset / CUI_SMALL_H)
        var y = list.y - (offset - Float32(i) * CUI_SMALL_H)
        while (i < items.size && y < list.bottom()) {
            let row = Rect(popup.x + 4.0, y, rowW, CUI_SMALL_H)
            if (i == selected.value) {
                ctx.renderer.fillRoundedRect(row, ctx.theme.smallRadius, ctx.theme.accent)
                drawRowLabel(ctx, items[i], row, ctx.theme.accentText)
            } else if (row.contains(ctx.mouseX, ctx.mouseY)) {
                ctx.renderer.fillRoundedRect(row, ctx.theme.smallRadius, ctx.theme.fieldActive)
                drawRowLabel(ctx, items[i], row, ctx.theme.text)
            } else {
                drawRowLabel(ctx, items[i], row, ctx.theme.text)
            }
            y += CUI_SMALL_H
            i += 1
        }
        ctx.renderer.popClip()
        drawVerticalScrollBar(ctx, list, offset, contentH, listH, active: popupBar.dragging(ctx))
    }

    // A down chevron drawn as two strokes, so it never depends on a font glyph.
    private func drawChevron(ctx: UiContext): Unit {
        let cx = frame.right() - 18.0
        let cy = frame.centerY()
        let pen = Pen(width: 1.6, color: ctx.theme.mutedText)
        ctx.renderer.strokeLine(cx - 4.0, cy - 2.0, cx, cy + 2.5, pen)
        ctx.renderer.strokeLine(cx, cy + 2.5, cx + 4.0, cy - 2.0, pen)
    }

    private func drawRowLabel(ctx: UiContext, text: String, row: Rect, color: Color): Unit {
        let textY = row.centerY() - ctx.renderer.textHeight(pointSize: FontSizes.CONTROL) / 2.0
        ctx.renderer.text(text, row.x + 8.0, textY, color, pointSize: FontSizes.CONTROL)
    }

    private func popupSurface(ctx: UiContext): SurfaceStyle {
        SurfaceStyle(ctx.theme.panelRaised, border: ctx.theme.panelEdge, radius: ctx.theme.controlRadius,
            borderWidth: 1.0, shadow: ctx.theme.shadow, shadowOffsetY: 4.0)
    }

    private func currentLabel(): String {
        if (items.isEmpty()) {
            "—"
        } else {
            items[clampDropdownIndex(selected.value, items.size)]
        }
    }

    public func isFlexible(): Bool {
        false
    }
}

private func clampDropdownIndex(index: Int64, count: Int64): Int64 {
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
