package cui.controls

import std.collection.ArrayList
import sdl.{FontSizes, Key, MouseButton, Rect, Size, UiEvent, clampF32}
import cui.core.{CursorShape, MenuItem, Overlay, State, UiContext, Widget, claimHoverIfInside, drawFocusRing,
    drawMenuPopup, emit, focusableControlIdentity, localState, menuContentHeight, menuFirstSelectable,
    menuItemIndexAt, menuItemSelectable, menuNextSelectable, menuPreferredWidth, requireControlId, runMenuItem}

private let MENU_BAR_HEIGHT: Float32 = 34.0
private let MENU_BAR_INSET: Float32 = 4.0
private let MENU_BAR_TITLE_PAD: Float32 = 12.0
private let MENU_BAR_MARGIN: Float32 = 4.0
private let MENU_BAR_GAP: Float32 = 2.0

/** One top-level menu of a `MenuBar`: a title and the items its dropdown holds. */
public struct Menu {
    let title: String
    let items: Array<MenuItem>

    public init(title: String, items: Array<MenuItem>) {
        this.title = title
        this.items = items
    }
}

/**
 * A horizontal application menu bar: a row of titles, each dropping a menu below it. Clicking a title
 * opens its menu (floated over the tree via the interactive overlay); with a menu open, moving the
 * pointer across the other titles switches between them, the classic menu-bar feel. Choosing an item
 * runs its action and closes; a click outside or Escape dismisses.
 *
 * Menus are described by `Menu` values holding `MenuItem`s, which may carry shortcut hints, be disabled,
 * or be `MenuItem.separator()` dividers. The bar is a keyboard focus stop: when focused, Left/Right move
 * along the titles and Enter/Space/Down opens one; while a menu is open, Up/Down move the highlight
 * (skipping separators and disabled rows), Left/Right switch menus, and Enter runs the highlight.
 */
public class MenuBar <: Widget {
    private let menus: Array<Menu>
    private let id: String
    private let overlayOwner: String
    private let openIndex: State<Int64>
    private let highlight: State<Int64>
    private let focusedTitle: State<Int64>
    private var frame = Rect.zero()

    public init(menus: Array<Menu>, key!: ?String = None) {
        this.menus = menus
        let base = match (key) {
            case Some(value) =>
                requireControlId(value, "MenuBar")
                value
            case None => "MenuBar"
        }
        let cid = focusableControlIdentity(base)
        this.id = cid
        this.overlayOwner = "MenuBar:${cid}"
        this.openIndex = localState<Int64>("${cid}:open") {-1}
        this.highlight = localState<Int64>("${cid}:hl") {0}
        this.focusedTitle = localState<Int64>("${cid}:focusedTitle") {0}
        emit(this)
    }

    public func measure(_: UiContext, available: Size): Size {
        Size(available.w, MENU_BAR_HEIGHT)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = Rect(rect.x, rect.y, rect.w, MENU_BAR_HEIGHT)
    }

    public func draw(ctx: UiContext): Unit {
        let titles = titleRects(ctx)
        for (i in 0..menus.size) {
            drawTitle(ctx, titles[i], i)
        }
        if (isOpen()) {
            ctx.setOverlay(Overlay(handleEvent: {c, e => handleOverlay(c, e)},
                render: {c => drawMenuPopup(c, currentPopup(c), currentItems(), highlight.value)}, owner: overlayOwner))
        }
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        claimHoverIfInside(ctx, event, frame, id, CursorShape.Interactive)
        // While a menu is open the overlay consumes every activation key; only events it deliberately
        // declines (moves, Tab, unrelated keys) fall through to this closed-bar handler.
        match (event) {
            case UiEvent.MouseDown(MouseButton.Left, x, y) =>
                let index = titleIndexAt(titleRects(ctx), x, y)
                if (index >= 0) {
                    ctx.focus(id)
                    openMenu(index)
                    return true
                }
            case UiEvent.KeyDown(Key.Left, _) => return moveTitle(ctx, -1)
            case UiEvent.KeyDown(Key.Right, _) => return moveTitle(ctx, 1)
            case UiEvent.KeyDown(Key.Down, _) => return openFocused(ctx)
            case UiEvent.KeyDown(Key.Enter, _) => return openFocused(ctx)
            case UiEvent.KeyDown(Key.Space, _) => return openFocused(ctx)
            case _ => ()
        }
        false
    }

    public func focusableId(): ?String {
        Some(id)
    }

    public func isFlexible(): Bool {
        false
    }

    private func isOpen(): Bool {
        openIndex.value >= 0 && openIndex.value < menus.size
    }

    private func currentItems(): Array<MenuItem> {
        if (isOpen()) {
            menus[openIndex.value].items
        } else {
            []
        }
    }

    private func openMenu(index: Int64): Unit {
        openIndex.value = index
        focusedTitle.value = index
        highlight.value = menuFirstSelectable(menus[index].items)
    }

    private func close(ctx: UiContext): Unit {
        openIndex.value = -1
        ctx.removeOverlay(overlayOwner)
    }

    private func moveTitle(ctx: UiContext, delta: Int64): Bool {
        if (!ctx.hasFocus(id) || menus.isEmpty()) {
            return false
        }
        focusedTitle.value = wrapIndex(focusedTitle.value + delta, menus.size)
        true
    }

    private func openFocused(ctx: UiContext): Bool {
        if (!ctx.hasFocus(id) || menus.isEmpty()) {
            return false
        }
        openMenu(wrapIndex(focusedTitle.value, menus.size))
        true
    }

    private func handleOverlay(ctx: UiContext, event: UiEvent): Bool {
        let titles = titleRects(ctx)
        let popup = currentPopup(ctx)
        match (event) {
            case UiEvent.MouseDown(MouseButton.Left, x, y) =>
                if (popup.contains(x, y)) {
                    runItem(ctx, menuItemIndexAt(popup, y))
                } else {
                    let index = titleIndexAt(titles, x, y)
                    if (index < 0) {
                        close(ctx) // click outside both the bar and the menu dismisses
                    } else if (index == openIndex.value) {
                        close(ctx) // clicking the open title toggles it shut
                    } else {
                        openMenu(index) // clicking another title switches to it
                    }
                }
                true
            case UiEvent.MouseDown(_, _, _) =>
                close(ctx)
                true
            case UiEvent.MouseMove(x, y) =>
                if (popup.contains(x, y)) {
                    // Claim the default cursor over the popup so a control beneath it cannot set its
                    // shape through the menu (the move still falls through for the bar's own hover).
                    ctx.claimHover(overlayOwner, CursorShape.Default)
                    let index = menuItemIndexAt(popup, y)
                    if (index >= 0 && index < currentItems().size && menuItemSelectable(currentItems()[index])) {
                        highlight.value = index
                    }
                } else {
                    let index = titleIndexAt(titles, x, y)
                    if (index >= 0 && index != openIndex.value) {
                        openMenu(index) // hover-switch between menus while open
                    }
                }
                false
            case UiEvent.KeyDown(Key.Escape, _) =>
                close(ctx)
                true
            case UiEvent.KeyDown(Key.Enter, _) =>
                runItem(ctx, highlight.value)
                true
            // Space activates like Enter. It must be consumed here regardless: unconsumed it would fall
            // through to the bar's own handler, whose Space arm re-opens the menu and resets the highlight.
            case UiEvent.KeyDown(Key.Space, _) =>
                runItem(ctx, highlight.value)
                true
            case UiEvent.KeyDown(Key.Down, _) =>
                highlight.value = menuNextSelectable(currentItems(), highlight.value, 1)
                true
            case UiEvent.KeyDown(Key.Up, _) =>
                highlight.value = menuNextSelectable(currentItems(), highlight.value, -1)
                true
            case UiEvent.KeyDown(Key.Left, _) =>
                openMenu(wrapIndex(openIndex.value - 1, menus.size))
                true
            case UiEvent.KeyDown(Key.Right, _) =>
                openMenu(wrapIndex(openIndex.value + 1, menus.size))
                true
            case UiEvent.KeyDown(Key.Tab, _) =>
                close(ctx) // commit and let Tab traversal move focus on
                false
            case _ => false
        }
    }

    // A click inside the menu closes it; a selectable row also runs its action.
    private func runItem(ctx: UiContext, index: Int64): Unit {
        let items = currentItems()
        close(ctx)
        if (index >= 0 && index < items.size && menuItemSelectable(items[index])) {
            runMenuItem(items[index])
        }
    }

    // Title cells laid left to right, each sized to its label; recomputed from the frame and the
    // renderer's text metrics so `handle` (before draw) and `draw` agree.
    private func titleRects(ctx: UiContext): Array<Rect> {
        let rects = ArrayList<Rect>()
        var x = frame.x + MENU_BAR_INSET
        for (menu in menus) {
            let w = ctx.renderer.textWidth(menu.title, pointSize: FontSizes.CONTROL) + MENU_BAR_TITLE_PAD * 2.0
            rects.add(Rect(x, frame.y, w, frame.h))
            x += w
        }
        rects.toArray()
    }

    private func titleIndexAt(titles: Array<Rect>, x: Float32, y: Float32): Int64 {
        for (i in 0..titles.size) {
            if (titles[i].contains(x, y)) {
                return i
            }
        }
        -1
    }

    // The dropdown rect for the open menu: anchored under its title, clamped into the viewport, and
    // flipped above the bar when there is no room below.
    private func currentPopup(ctx: UiContext): Rect {
        let titles = titleRects(ctx)
        if (!isOpen() || openIndex.value >= titles.size) {
            return Rect.zero()
        }
        let title = titles[openIndex.value]
        let items = menus[openIndex.value].items
        let w = menuPreferredWidth(ctx, items)
        let h = menuContentHeight(items)
        let x = clampF32(title.x, MENU_BAR_MARGIN, max(MENU_BAR_MARGIN, ctx.viewportWidth - w - MENU_BAR_MARGIN))
        let below = title.bottom() + MENU_BAR_GAP
        let y = if (below + h <= ctx.viewportHeight - MENU_BAR_MARGIN) {
            below
        } else {
            max(MENU_BAR_MARGIN, title.y - MENU_BAR_GAP - h)
        }
        Rect(x, y, w, h)
    }

    private func drawTitle(ctx: UiContext, cell: Rect, index: Int64): Unit {
        let active = index == openIndex.value
        let hovered = cell.contains(ctx.mouseX, ctx.mouseY)
        let keyboardFocused = ctx.showFocusRing(id) && index == focusedTitle.value
        if (active) {
            ctx.renderer.fillRoundedRect(cell.inset(3.0), ctx.theme.smallRadius, ctx.theme.accent)
        } else if (hovered) {
            ctx.renderer.fillRoundedRect(cell.inset(3.0), ctx.theme.smallRadius, ctx.theme.fieldActive)
        }
        if (keyboardFocused && !active) {
            drawFocusRing(ctx, cell.inset(3.0), ctx.theme.smallRadius)
        }
        let color = if (active) {
            ctx.theme.accentText
        } else {
            ctx.theme.text
        }
        let tw = ctx.renderer.textWidth(menus[index].title, pointSize: FontSizes.CONTROL)
        let ty = cell.centerY() - ctx.renderer.textHeight(pointSize: FontSizes.CONTROL) / 2.0
        ctx.renderer.text(menus[index].title, cell.centerX() - tw / 2.0, ty, color, pointSize: FontSizes.CONTROL)
    }
}

private func wrapIndex(index: Int64, count: Int64): Int64 {
    if (count <= 0) {
        0
    } else {
        ((index % count) + count) % count
    }
}
