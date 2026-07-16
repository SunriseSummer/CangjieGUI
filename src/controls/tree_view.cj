package cui.controls

import std.collection.{ArrayList, HashSet}
import sdl.{Color, FontSizes, IconName, Key, MouseButton, Pen, Rect, Size, UiEvent, drawIcon}
import cui.core.{Bindable, CUI_SMALL_H, CursorShape, ScrollBar, State, UiContext, Widget, requireControlId,
    claimHoverIfInside, clampScrollOffset, drawSurface, drawVerticalScrollBar, emit, focusableControlIdentity,
    localState, scrollLineIndex, scrollLineRemainder, scrollOffsetAfterWheel}

// Logical pixels of indentation added per depth level.
private let TREE_INDENT: Float32 = 16.0
// Width reserved at the start of each row's content for the disclosure chevron, so leaf rows align
// with their expandable siblings.
private let TREE_TWISTY_W: Float32 = 18.0
private let TREE_ICON_SIZE: Float32 = 16.0

/**
 * A node in a `TreeView`: a stable `id`, a display `label`, an optional leading `icon`, and its
 * `children`. Ids must be unique across the whole tree — the view keys expansion and selection by
 * them, so a duplicate id would make two nodes toggle and select as one.
 *
 * ```
 * TreeNode("src", "src", icon: IconName.OpenFolder, children: [
 *     TreeNode("src/main", "main.cj", icon: IconName.NewDocument)
 * ])
 * ```
 */
public class TreeNode {
    public let id: String
    public let label: String
    public let icon: ?IconName
    public let children: Array<TreeNode>

    public init(id: String, label: String, children!: Array<TreeNode> = [], icon!: ?IconName = None) {
        this.id = id
        this.label = label
        this.children = children
        this.icon = icon
    }
}

// One materialized row of the flattened, currently-visible tree: a node paired with its depth and
// disclosure state. Collapsed subtrees contribute no rows, so the flattened list is exactly what the
// user can see, which is what the view windows and navigates over.
struct TreeRow {
    let id: String
    let label: String
    let icon: ?IconName
    let depth: Int64
    let hasChildren: Bool
    let expanded: Bool

    init(id: String, label: String, icon: ?IconName, depth: Int64, hasChildren: Bool, expanded: Bool) {
        this.id = id
        this.label = label
        this.icon = icon
        this.depth = depth
        this.hasChildren = hasChildren
        this.expanded = expanded
    }
}

/**
 * A hierarchical list with expand/collapse disclosure — a file explorer, an outline, a nav tree.
 * Nodes are described by `TreeNode` roots; the view flattens the currently-expanded nodes into rows,
 * windows them (only rows near the viewport are drawn, so a large tree costs a screenful), and lets
 * the user reveal structure by toggling nodes.
 *
 * Selection is by node id (a stable key rather than a row index, since expanding and collapsing
 * shifts every row below). Expansion is retained by the view's identity across the per-frame rebuild;
 * seed the initially-open nodes with `initiallyExpanded`, or own the set externally through `expanded`
 * for persistence or coordination. The `selected` binding holds the selected node id (empty for none).
 *
 * Keyboard, when focused: Up/Down move through visible rows, Home/End jump to the ends, Right expands
 * a collapsed node then steps into it, Left collapses an expanded node then steps out to its parent,
 * and Enter/Space toggle the current node. Clicking a row selects it; clicking its chevron toggles it.
 */
public class TreeView <: Widget {
    private let roots: Array<TreeNode>
    private let selected: Bindable<String>
    private let expandedState: State<HashSet<String>>
    private var scrollStateValue: State<Float32>
    private let controlId: String
    private let scrollBar: ScrollBar
    // The selection last scrolled into view, retained across rebuilds; draw reveals the selected row
    // only when it differs, so an externally driven selection scrolls in while plain scrolling does not.
    private let lastRevealed: State<String>
    // The visible rows for this frame, flattened from the roots and the retained expansion set.
    private let rows: Array<TreeRow>
    private var frame = Rect.zero()

    public init(
        roots: Array<TreeNode>,
        selected: Bindable<String>,
        scroll!: ?State<Float32> = None,
        expanded!: ?State<HashSet<String>> = None,
        initiallyExpanded!: Array<String> = [],
        key!: ?String = None
    ) {
        this.roots = roots
        this.selected = selected
        // Identity is optional and auto-derived by build order (like ListView); pass `key` to keep
        // scroll/expansion/selection state across a structural change or to coordinate them externally.
        let base = match (key) {
            case Some(value) =>
                requireControlId(value, "TreeView")
                value
            case None => "TreeView"
        }
        let cid = focusableControlIdentity(base)
        this.controlId = cid
        this.scrollStateValue = match (scroll) {
            case Some(value) => value
            case None => localState<Float32>("${cid}:scroll") {0.0}
        }
        this.expandedState = match (expanded) {
            case Some(value) => value
            case None => localState<HashSet<String>>("${cid}:expanded") {seedExpanded(initiallyExpanded)}
        }
        this.scrollBar = ScrollBar("TreeView:${cid}:thumb")
        this.lastRevealed = localState<String>("${cid}:revealed") {""}
        this.rows = flattenTree(roots, this.expandedState.value)
        emit(this)
    }

    /** Uses an externally owned scroll offset, enabling restoration and coordination. */
    public func scrollState(value: State<Float32>): TreeView {
        scrollStateValue = value
        this
    }

    public func measure(_: UiContext, available: Size): Size {
        Size(available.w, available.h)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        let content = treeContentHeight(rows)
        let viewport = treeViewport(frame)
        // Clamp on change only: draw runs every frame and the offset may be externally owned.
        let clamped = clampScrollOffset(scrollStateValue.value, content, viewport.h)
        if (clamped != scrollStateValue.value) {
            scrollStateValue.value = clamped
        }
        // Reveal the selection when it changed since last frame — catches selections driven from
        // outside this widget; unchanged selection (plain scrolling) is left alone.
        if (selected.value != lastRevealed.value) {
            revealRowIndex(selectedIndex())
            lastRevealed.value = selected.value
        }
        drawSurface(ctx, frame, ctx.theme.fieldSurface(ctx.showFocusRing(controlId)))

        ctx.renderer.pushClip(viewport)
        var i = scrollLineIndex(scrollStateValue.value)
        var y = viewport.y - scrollLineRemainder(scrollStateValue.value)
        while (i < rows.size && y < viewport.bottom()) {
            drawRow(ctx, rows[i], Rect(viewport.x, y, viewport.w, CUI_SMALL_H))
            y += CUI_SMALL_H
            i += 1
        }
        ctx.renderer.popClip()
        drawVerticalScrollBar(ctx, frame, scrollStateValue.value, content, viewport.h, active: scrollBar.dragging(ctx))
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        claimHoverIfInside(ctx, event, frame, controlId, CursorShape.Interactive)
        let content = treeContentHeight(rows)
        let viewportH = treeViewport(frame).h
        match (event) {
            case UiEvent.MouseDown(MouseButton.Left, x, y) =>
                if (scrollBar.press(ctx, frame, scrollStateValue, content, viewportH, x, y)) {
                    return true
                }
                if (frame.contains(x, y)) {
                    ctx.focus(controlId)
                    let viewport = treeViewport(frame)
                    if (viewport.contains(x, y)) {
                        let idx = Int64((y - viewport.y + scrollStateValue.value) / CUI_SMALL_H)
                        if (idx >= 0 && idx < rows.size) {
                            pressRow(idx, viewport.x, x)
                        }
                    }
                    return true
                }
            case UiEvent.MouseMove(_, y) =>
                if (scrollBar.drag(ctx, frame, scrollStateValue, content, viewportH, y)) {
                    return true
                }
            case UiEvent.MouseWheel(_, wy, wx, pointerY) =>
                if (frame.contains(wx, pointerY)) {
                    scrollStateValue.value = scrollOffsetAfterWheel(scrollStateValue.value, wy, content, viewportH)
                    return true
                }
            case UiEvent.KeyDown(Key.Up, _) => return moveSelection(ctx, -1)
            case UiEvent.KeyDown(Key.Down, _) => return moveSelection(ctx, 1)
            case UiEvent.KeyDown(Key.Home, _) => return jumpSelection(ctx, 0)
            case UiEvent.KeyDown(Key.End, _) => return jumpSelection(ctx, rows.size - 1)
            case UiEvent.KeyDown(Key.Right, _) => return expandOrDescend(ctx)
            case UiEvent.KeyDown(Key.Left, _) => return collapseOrAscend(ctx)
            case UiEvent.KeyDown(Key.Enter, _) => return toggleSelected(ctx)
            case UiEvent.KeyDown(Key.Space, _) => return toggleSelected(ctx)
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

    // A press inside a row toggles the node when it lands on the chevron column, otherwise selects it.
    private func pressRow(idx: Int64, viewportX: Float32, x: Float32): Unit {
        let row = rows[idx]
        let disclosureX = viewportX + 6.0 + Float32(row.depth) * TREE_INDENT
        if (row.hasChildren && x >= disclosureX && x <= disclosureX + TREE_TWISTY_W) {
            toggleExpanded(row.id)
        } else {
            selectRow(idx)
        }
    }

    private func moveSelection(ctx: UiContext, delta: Int64): Bool {
        if (!ctx.hasFocus(controlId) || rows.isEmpty()) {
            return false
        }
        let current = selectedIndex()
        let next = if (current < 0) {
            if (delta > 0) {
                0
            } else {
                rows.size - 1
            }
        } else {
            clampRowIndex(current + delta)
        }
        selectRow(next)
        true
    }

    private func jumpSelection(ctx: UiContext, index: Int64): Bool {
        if (!ctx.hasFocus(controlId) || rows.isEmpty()) {
            return false
        }
        selectRow(clampRowIndex(index))
        true
    }

    // Right: open a collapsed node, or step into an already-open one's first child.
    private func expandOrDescend(ctx: UiContext): Bool {
        if (!ctx.hasFocus(controlId) || rows.isEmpty()) {
            return false
        }
        let current = selectedIndex()
        if (current >= 0) {
            let row = rows[current]
            if (row.hasChildren && !row.expanded) {
                setExpanded(row.id, true)
            } else if (row.hasChildren && row.expanded && current + 1 < rows.size) {
                selectRow(current + 1)
            }
        }
        true
    }

    // Left: close an open node, or step out to the parent of a leaf/closed node.
    private func collapseOrAscend(ctx: UiContext): Bool {
        if (!ctx.hasFocus(controlId) || rows.isEmpty()) {
            return false
        }
        let current = selectedIndex()
        if (current >= 0) {
            let row = rows[current]
            if (row.hasChildren && row.expanded) {
                setExpanded(row.id, false)
            } else {
                let parent = parentIndex(current)
                if (parent >= 0) {
                    selectRow(parent)
                }
            }
        }
        true
    }

    private func toggleSelected(ctx: UiContext): Bool {
        if (!ctx.hasFocus(controlId) || rows.isEmpty()) {
            return false
        }
        let current = selectedIndex()
        if (current >= 0 && rows[current].hasChildren) {
            toggleExpanded(rows[current].id)
        }
        true
    }

    // The nearest row above `index` that sits one level shallower — the parent in the flattened view.
    private func parentIndex(index: Int64): Int64 {
        let depth = rows[index].depth
        var i = index - 1
        while (i >= 0) {
            if (rows[i].depth < depth) {
                return i
            }
            i -= 1
        }
        -1
    }

    private func selectedIndex(): Int64 {
        for (i in 0..rows.size) {
            if (rows[i].id == selected.value) {
                return i
            }
        }
        -1
    }

    private func selectRow(index: Int64): Unit {
        if (index < 0 || index >= rows.size) {
            return
        }
        selected.value = rows[index].id
        revealRowIndex(index)
        lastRevealed.value = selected.value
    }

    // Scrolls the given row's band just into view, adjusting the offset minimally.
    private func revealRowIndex(index: Int64): Unit {
        if (index < 0) {
            return
        }
        let viewportH = treeViewport(frame).h
        let rowTop = Float32(index) * CUI_SMALL_H
        let rowBottom = rowTop + CUI_SMALL_H
        var offset = scrollStateValue.value
        if (rowTop < offset) {
            offset = rowTop
        } else if (rowBottom > offset + viewportH) {
            offset = rowBottom - viewportH
        }
        scrollStateValue.value = clampScrollOffset(offset, treeContentHeight(rows), viewportH)
    }

    private func clampRowIndex(index: Int64): Int64 {
        if (rows.isEmpty()) {
            0
        } else if (index < 0) {
            0
        } else if (index >= rows.size) {
            rows.size - 1
        } else {
            index
        }
    }

    private func toggleExpanded(id: String): Unit {
        setExpanded(id, !expandedState.value.contains(id))
    }

    // Rebuilds the expansion set as a fresh value so the state write is observed (a mutated-in-place
    // set would keep the same reference and could be missed by change tracking).
    private func setExpanded(id: String, expand: Bool): Unit {
        let next = HashSet<String>()
        for (existing in expandedState.value) {
            next.add(existing)
        }
        if (expand) {
            next.add(id)
        } else {
            next.remove(id)
        }
        expandedState.value = next
    }

    private func drawRow(ctx: UiContext, row: TreeRow, rect: Rect): Unit {
        let isSelected = row.id == selected.value
        if (isSelected) {
            ctx.renderer.fillRoundedRect(rect.inset(2.0), ctx.theme.smallRadius, ctx.theme.accent)
        }
        let textColor = if (isSelected) {
            ctx.theme.accentText
        } else {
            ctx.theme.text
        }
        let disclosureX = rect.x + 6.0 + Float32(row.depth) * TREE_INDENT
        if (row.hasChildren) {
            drawChevron(ctx, disclosureX + TREE_TWISTY_W / 2.0, rect.centerY(), row.expanded, textColor)
        }
        var contentX = disclosureX + TREE_TWISTY_W
        match (row.icon) {
            case Some(icon) =>
                drawIcon(ctx.renderer, icon,
                    Rect(contentX, rect.centerY() - TREE_ICON_SIZE / 2.0, TREE_ICON_SIZE, TREE_ICON_SIZE), textColor)
                contentX += TREE_ICON_SIZE + 6.0
            case None => ()
        }
        let textY = rect.centerY() - ctx.renderer.textHeight(pointSize: FontSizes.BODY) / 2.0
        ctx.renderer.text(row.label, contentX, textY, textColor, pointSize: FontSizes.BODY)
    }
}

// A disclosure chevron: pointing down when expanded, right when collapsed — the conventional twisty.
private func drawChevron(ctx: UiContext, cx: Float32, cy: Float32, expanded: Bool, color: Color): Unit {
    let pen = Pen(width: 1.6, color: color)
    let arm: Float32 = 3.0
    if (expanded) {
        ctx.renderer.strokeLine(cx - arm, cy - arm * 0.5, cx, cy + arm * 0.5, pen)
        ctx.renderer.strokeLine(cx, cy + arm * 0.5, cx + arm, cy - arm * 0.5, pen)
    } else {
        ctx.renderer.strokeLine(cx - arm * 0.5, cy - arm, cx + arm * 0.5, cy, pen)
        ctx.renderer.strokeLine(cx + arm * 0.5, cy, cx - arm * 0.5, cy + arm, pen)
    }
}

private func treeViewport(frame: Rect): Rect {
    Rect(frame.x + 4.0, frame.y + 6.0, max(0.0, frame.w - 12.0), max(0.0, frame.h - 12.0))
}

private func treeContentHeight(rows: Array<TreeRow>): Float32 {
    Float32(rows.size) * CUI_SMALL_H
}

private func seedExpanded(ids: Array<String>): HashSet<String> {
    let set = HashSet<String>()
    for (id in ids) {
        set.add(id)
    }
    set
}

/** Flattens the roots into the rows currently visible, descending only into expanded nodes. */
internal func flattenTree(roots: Array<TreeNode>, expanded: HashSet<String>): Array<TreeRow> {
    let rows = ArrayList<TreeRow>()
    for (root in roots) {
        appendTreeRows(rows, root, 0, expanded)
    }
    rows.toArray()
}

private func appendTreeRows(rows: ArrayList<TreeRow>, node: TreeNode, depth: Int64, expanded: HashSet<String>): Unit {
    let hasChildren = !node.children.isEmpty()
    let isExpanded = expanded.contains(node.id)
    rows.add(TreeRow(node.id, node.label, node.icon, depth, hasChildren, isExpanded))
    if (hasChildren && isExpanded) {
        for (child in node.children) {
            appendTreeRows(rows, child, depth + 1, expanded)
        }
    }
}
