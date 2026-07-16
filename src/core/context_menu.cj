package cui.core

import sdl.{Key, MouseButton, Rect, Size, UiEvent}

private let CONTEXT_MENU_MARGIN: Float32 = 4.0

/*
 * Wraps a control with a right-click context menu. A secondary press inside the child opens a
 * menu at the pointer, floated above the tree via the interactive overlay — so its clicks are
 * never stolen by controls beneath it. Choosing an item runs its action and closes; a click
 * outside or Escape dismisses; arrows and hover move the highlight (skipping separators and
 * disabled rows), Enter runs it. Otherwise a transparent wrapper: it forwards layout, drawing
 * and all other events to the child. Menu rows may carry shortcut hints and be disabled, and
 * `MenuItem.separator()` inserts a divider.
 */
public class ContextMenu <: Widget {
    private let child: Widget
    private let items: Array<MenuItem>
    private let open: State<Bool>
    private let menuX: State<Float32>
    private let menuY: State<Float32>
    private let highlight: State<Int64>
    // Identifies this menu on the overlay stack across per-frame rebuilds, so closing
    // removes exactly its own registration (a dialog beneath it stays open).
    private let overlayOwner: String
    private var frame = Rect.zero()

    public init(items!: Array<MenuItem>, key!: ?String = None, body!: () -> Unit) {
        this.child = buildChild(body)
        this.items = items
        let ident = "ContextMenu:${resolveControlKey(key, "ContextMenu")}"
        this.overlayOwner = ident
        this.open = localState<Bool>("${ident}:open") {false}
        this.menuX = localState<Float32>("${ident}:x") {0.0}
        this.menuY = localState<Float32>("${ident}:y") {0.0}
        this.highlight = localState<Int64>("${ident}:hl") {0}
        emit(this)
    }

    public func measure(ctx: UiContext, available: Size): Size {
        child.measure(ctx, available)
    }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        frame = rect
        child.layout(ctx, rect)
    }

    public func draw(ctx: UiContext): Unit {
        child.draw(ctx)
        if (open.value && !items.isEmpty()) {
            let menu = menuRect(ctx)
            ctx.setOverlay(Overlay(handleEvent: {c, e => handleMenu(c, e, menu)},
                render: {c => drawMenuPopup(c, menu, items, highlight.value)}, owner: overlayOwner))
        }
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        match (event) {
            case UiEvent.MouseDown(MouseButton.Right, x, y) =>
                // With no items there is nothing to show — and draw would never register
                // the overlay, so a latched `open` could pop a menu much later, unprompted.
                if (frame.contains(x, y) && !items.isEmpty()) {
                    open.value = true
                    menuX.value = x
                    menuY.value = y
                    highlight.value = menuFirstSelectable(items)
                    return true
                }
            case _ => ()
        }
        child.handle(ctx, event)
    }

    public func isFlexible(): Bool {
        child.isFlexible()
    }

    public func flexWeight(): Float32 {
        child.flexWeight()
    }

    public func acceptsStretch(axis: Axis): Bool {
        child.acceptsStretch(axis)
    }

    public func participatesInLayout(): Bool {
        child.participatesInLayout()
    }

    public func focusableId(): ?String {
        child.focusableId()
    }

    public func focusableIds(): Array<String> {
        child.focusableIds()
    }

    private func handleMenu(ctx: UiContext, event: UiEvent, menu: Rect): Bool {
        match (event) {
            case UiEvent.MouseDown(MouseButton.Left, x, y) =>
                if (menu.contains(x, y)) {
                    runItem(ctx, menuItemIndexAt(menu, y))
                } else {
                    close(ctx)
                }
                true
            case UiEvent.MouseDown(_, _, _) =>
                close(ctx) // any other button dismisses
                true
            case UiEvent.MouseMove(x, y) =>
                if (menu.contains(x, y)) {
                    // The popup floats over arbitrary content; claim the default cursor so a control
                    // beneath it (a text field, a divider) cannot set its shape through the menu.
                    ctx.claimHover(overlayOwner, CursorShape.Default)
                    let index = menuItemIndexAt(menu, y)
                    if (index >= 0 && index < items.size && items[index].isSelectable()) {
                        highlight.value = index
                    }
                }
                false
            case UiEvent.KeyDown(Key.Escape, _) =>
                close(ctx)
                true
            case UiEvent.KeyDown(Key.Enter, _) =>
                runItem(ctx, highlight.value)
                true
            case UiEvent.KeyDown(Key.Down, _) =>
                highlight.value = menuNextSelectable(items, highlight.value, 1)
                true
            case UiEvent.KeyDown(Key.Up, _) =>
                highlight.value = menuNextSelectable(items, highlight.value, -1)
                true
            case _ => false
        }
    }

    // A click inside the menu closes it; a selectable row also runs its action, while a separator,
    // disabled row or pad index just dismisses. Closing before the action lets the action settle the
    // UI (or open its own overlay).
    private func runItem(ctx: UiContext, index: Int64): Unit {
        close(ctx)
        if (index >= 0 && index < items.size && items[index].isSelectable()) {
            items[index].action()
        }
    }

    private func close(ctx: UiContext): Unit {
        open.value = false
        ctx.removeOverlay(overlayOwner)
    }

    private func menuRect(ctx: UiContext): Rect {
        let width = menuPreferredWidth(ctx, items)
        let height = menuContentHeight(items)
        var x = menuX.value
        var y = menuY.value
        if (x + width > ctx.viewportWidth) {
            x = max(CONTEXT_MENU_MARGIN, ctx.viewportWidth - width - CONTEXT_MENU_MARGIN)
        }
        if (y + height > ctx.viewportHeight) {
            y = max(CONTEXT_MENU_MARGIN, ctx.viewportHeight - height - CONTEXT_MENU_MARGIN)
        }
        Rect(x, y, width, height)
    }
}
