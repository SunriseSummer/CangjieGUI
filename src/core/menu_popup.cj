package cui.core

import sdl.{FontSizes, Rect, SurfaceStyle}

// Padding strips above and below the rows inside a menu popup.
private let MENU_ROW_PAD: Float32 = 5.0
private let MENU_MIN_WIDTH: Float32 = 120.0
// Horizontal budget added to the widest label so text never touches the popup edge.
private let MENU_LABEL_PAD: Float32 = 24.0
// Extra width reserved when a row carries a shortcut hint, keeping label and hint apart.
private let MENU_SHORTCUT_GAP: Float32 = 30.0

/**
 * One entry in a menu (shared by `ContextMenu` and `MenuBar`): a label, the action run when it is
 * chosen, an optional right-aligned `shortcut` hint, and an `enabled` flag. A separator — a thin rule
 * that neither highlights nor runs — is made with `MenuItem.separator()`.
 */
public struct MenuItem {
    let label: String
    let action: () -> Unit
    let shortcut: String
    let enabled: Bool
    let isSeparator: Bool

    public init(label: String, action: () -> Unit, shortcut!: String = "", enabled!: Bool = true) {
        this.label = label
        this.action = action
        this.shortcut = shortcut
        this.enabled = enabled
        this.isSeparator = false
    }

    private init(separatorMarker!: Bool) {
        this.label = ""
        this.action = {=> ()}
        this.shortcut = ""
        this.enabled = false
        this.isSeparator = separatorMarker
    }

    /** A non-interactive divider rule between groups of items. */
    public static func separator(): MenuItem {
        MenuItem(separatorMarker: true)
    }

    /** Whether this item can be highlighted and run (not a separator, not disabled). */
    func isSelectable(): Bool {
        enabled && !isSeparator
    }
}

/** Whether `item` can be highlighted and run — the cross-package accessor for `MenuItem.isSelectable`. */
protected func menuItemSelectable(item: MenuItem): Bool {
    item.isSelectable()
}

/** Runs `item`'s action — the cross-package accessor for the internal action field. */
protected func runMenuItem(item: MenuItem): Unit {
    item.action()
}

/** The popup width that fits the widest label (plus any shortcut), floored at a minimum. */
protected func menuPreferredWidth(ctx: UiContext, items: Array<MenuItem>): Float32 {
    var width = MENU_MIN_WIDTH
    for (item in items) {
        if (item.isSeparator) {
            continue
        }
        var w = ctx.renderer.textWidth(item.label, pointSize: FontSizes.CONTROL) + MENU_LABEL_PAD
        if (!item.shortcut.isEmpty()) {
            w += ctx.renderer.textWidth(item.shortcut, pointSize: FontSizes.CAPTION) + MENU_SHORTCUT_GAP
        }
        width = max(width, w)
    }
    width
}

/** Total popup height for `items` at uniform row height plus the top and bottom pad strips. */
protected func menuContentHeight(items: Array<MenuItem>): Float32 {
    Float32(items.size) * CUI_SMALL_H + MENU_ROW_PAD * 2.0
}

/*
 * The row index at pointer `y` within `menu` (uniform CUI_SMALL_H rows), or -1 in the pad strips.
 * Callers check the item at that index for selectability before running or highlighting it.
 */
protected func menuItemIndexAt(menu: Rect, y: Float32): Int64 {
    if (y < menu.y + MENU_ROW_PAD || y >= menu.bottom() - MENU_ROW_PAD) {
        return -1
    }
    Int64((y - menu.y - MENU_ROW_PAD) / CUI_SMALL_H)
}

/*
 * The next selectable index from `from` stepping by `direction` (+1 down, -1 up), skipping separators
 * and disabled rows. Stays at `from` when no selectable row lies that way, so navigation stops at the
 * ends instead of landing on a divider.
 */
protected func menuNextSelectable(items: Array<MenuItem>, from: Int64, direction: Int64): Int64 {
    var i = from + direction
    while (i >= 0 && i < items.size) {
        if (items[i].isSelectable()) {
            return i
        }
        i += direction
    }
    from
}

/** The first selectable index, or 0 when the menu holds none (all separators/disabled). */
protected func menuFirstSelectable(items: Array<MenuItem>): Int64 {
    for (i in 0..items.size) {
        if (items[i].isSelectable()) {
            return i
        }
    }
    0
}

/** Draws the menu surface and its rows: labels, right-aligned shortcuts, separators, dimmed disables. */
protected func drawMenuPopup(ctx: UiContext, menu: Rect, items: Array<MenuItem>, highlight: Int64): Unit {
    drawSurface(ctx, menu, menuPopupSurface(ctx))
    ctx.renderer.pushClip(menu)
    var y = menu.y + MENU_ROW_PAD
    var i = 0
    while (i < items.size) {
        drawMenuRow(ctx, items[i], Rect(menu.x + 4.0, y, max(0.0, menu.w - 8.0), CUI_SMALL_H), i == highlight)
        y += CUI_SMALL_H
        i += 1
    }
    ctx.renderer.popClip()
}

private func drawMenuRow(ctx: UiContext, item: MenuItem, row: Rect, highlightIndex: Bool): Unit {
    if (item.isSeparator) {
        let lineY = row.centerY()
        ctx.renderer.fill(Rect(row.x + 6.0, lineY, max(0.0, row.w - 12.0), 1.0), ctx.theme.panelEdge)
        return
    }
    let highlighted = highlightIndex && item.isSelectable()
    if (highlighted) {
        ctx.renderer.fillRoundedRect(row, ctx.theme.smallRadius, ctx.theme.accent)
    }
    let labelColor = if (highlighted) {
        ctx.theme.accentText
    } else if (!item.enabled) {
        ctx.theme.mutedText
    } else {
        ctx.theme.text
    }
    let labelY = row.centerY() - ctx.renderer.textHeight(pointSize: FontSizes.CONTROL) / 2.0
    ctx.renderer.text(item.label, row.x + 8.0, labelY, labelColor, pointSize: FontSizes.CONTROL)
    if (!item.shortcut.isEmpty()) {
        let shortcutColor = if (highlighted) {
            ctx.theme.accentText
        } else {
            ctx.theme.mutedText
        }
        let sw = ctx.renderer.textWidth(item.shortcut, pointSize: FontSizes.CAPTION)
        let sy = row.centerY() - ctx.renderer.textHeight(pointSize: FontSizes.CAPTION) / 2.0
        ctx.renderer.text(item.shortcut, row.right() - sw - 8.0, sy, shortcutColor, pointSize: FontSizes.CAPTION)
    }
}

protected func menuPopupSurface(ctx: UiContext): SurfaceStyle {
    SurfaceStyle(ctx.theme.panelRaised, border: ctx.theme.panelEdge, radius: ctx.theme.controlRadius,
        borderWidth: 1.0, shadow: ctx.theme.shadow, shadowOffsetY: 4.0)
}
