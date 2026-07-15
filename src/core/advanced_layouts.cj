package cui.core

import sdl.{Rect, Size, UiEvent}

private let LAYOUT_UNBOUNDED: Float32 = 999936.0

/** Layers children back-to-front and aligns each child inside the same frame. */
public class ZStack <: Widget {
    private let children: Array<Widget>
    private var contentAlignment = Alignment.Center

    public init(body!: () -> Unit) {
        children = buildChildren(body)
        emit(this)
    }

    /** Sets how non-stretching children are positioned in the overlay. */
    public func alignment(value: Alignment): ZStack {
        contentAlignment = value
        this
    }

    public func measure(ctx: UiContext, available: Size): Size {
        var width: Float32 = 0.0
        var height: Float32 = 0.0
        for (child in children) {
            if (!child.participatesInLayout()) {
                continue
            }
            let size = child.measure(ctx, available)
            width = max(width, size.w)
            height = max(height, size.h)
        }
        Size(min(width, available.w), min(height, available.h))
    }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        for (child in children) {
            if (!child.participatesInLayout()) {
                continue
            }
            let measured = child.measure(ctx, Size(rect.w, rect.h))
            let width = if (child.acceptsStretch(Axis.Horizontal)) {
                rect.w
            } else {
                min(rect.w, measured.w)
            }
            let height = if (child.acceptsStretch(Axis.Vertical)) {
                rect.h
            } else {
                min(rect.h, measured.h)
            }
            child.layout(ctx, alignedRect(rect, width, height, contentAlignment))
        }
    }

    public func draw(ctx: UiContext): Unit {
        for (child in children) {
            child.draw(ctx)
        }
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        match (event) {
            case UiEvent.Frame(_) =>
                for (child in children) {
                    let _ = child.handle(ctx, event)
                }
                return false
            case _ => ()
        }
        var i = children.size - 1
        while (i >= 0) {
            if (children[i].handle(ctx, event)) {
                return true
            }
            i -= 1
        }
        false
    }

    public func focusableIds(): Array<String> {
        collectFocusableIds(children)
    }
}

/**
 * Arranges children in a fixed number of equal-width columns and content-sized rows.
 * Throws `IllegalArgumentException` when `columns` is not positive.
 */
public class Grid <: Widget {
    private let columns: Int64
    private let children: Array<Widget>
    private var horizontalGap: Length = vpLength(CUI_GAP)
    private var verticalGap: Length = vpLength(CUI_GAP)

    /** Creates a grid. Throws `IllegalArgumentException` when `columns` is not positive. */
    public init(columns: Int64, body!: () -> Unit) {
        if (columns <= 0) {
            throw IllegalArgumentException("Grid columns must be greater than zero")
        }
        this.columns = columns
        this.children = buildChildren(body)
        emit(this)
    }

    /** Sets equal horizontal and vertical gaps, e.g. `.spacing(12.vp)`. */
    public func spacing(value: Length): Grid {
        horizontalGap = value
        verticalGap = value
        this
    }

    /** Sets equal horizontal and vertical gaps in virtual pixels. */
    public func spacing(value: Float32): Grid {
        spacing(vpLength(value))
    }

    /** Sets independent horizontal and vertical gaps. */
    public func spacing(horizontal: Length, vertical: Length): Grid {
        horizontalGap = horizontal
        verticalGap = vertical
        this
    }

    /** Sets independent horizontal and vertical gaps in virtual pixels. */
    public func spacing(horizontal: Float32, vertical: Float32): Grid {
        spacing(vpLength(horizontal), vpLength(vertical))
    }

    public func measure(ctx: UiContext, available: Size): Size {
        let heights = rowHeights(ctx, available.w, available.h)
        Size(available.w, min(available.h, sum(heights) + gapExtent(heights.size, gapV(ctx))))
    }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        let hGap = gapH(ctx)
        let cellWidth = gridCellWidth(rect.w, hGap)
        let heights = rowHeights(ctx, rect.w, rect.h)
        var y = rect.y
        var childIndex: Int64 = 0
        var row: Int64 = 0
        while (row < heights.size) {
            var column: Int64 = 0
            while (column < columns && childIndex < children.size) {
                if (!children[childIndex].participatesInLayout()) {
                    childIndex += 1
                    continue
                }
                let x = rect.x + Float32(column) * (cellWidth + hGap)
                let child = children[childIndex]
                let measured = child.measure(ctx, Size(cellWidth, heights[row]))
                let width = if (child.acceptsStretch(Axis.Horizontal)) {
                    cellWidth
                } else {
                    measured.w
                }
                let height = if (child.acceptsStretch(Axis.Vertical)) {
                    heights[row]
                } else {
                    measured.h
                }
                child.layout(ctx, Rect(x, y, min(cellWidth, width), min(heights[row], height)))
                column += 1
                childIndex += 1
            }
            y += heights[row] + gapV(ctx)
            row += 1
        }
    }

    public func draw(ctx: UiContext): Unit {
        for (child in children) {
            child.draw(ctx)
        }
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        dispatchChildren(children, ctx, event)
    }

    public func focusableIds(): Array<String> {
        collectFocusableIds(children)
    }

    private func gapH(ctx: UiContext): Float32 {
        max(0.0, ctx.resolve(horizontalGap))
    }

    private func gapV(ctx: UiContext): Float32 {
        max(0.0, ctx.resolve(verticalGap))
    }

    private func rowHeights(ctx: UiContext, width: Float32, height: Float32): Array<Float32> {
        let count = participatingCount(children)
        let rows = (count + columns - 1) / columns
        let heights = Array<Float32>(rows, {_ => Float32(0.0)})
        let cellWidth = gridCellWidth(width, gapH(ctx))
        var i: Int64 = 0
        var activeIndex: Int64 = 0
        while (i < children.size) {
            if (!children[i].participatesInLayout()) {
                i += 1
                continue
            }
            let row = activeIndex / columns
            heights[row] = max(heights[row], children[i].measure(ctx, Size(cellWidth, height)).h)
            i += 1
            activeIndex += 1
        }
        heights
    }

    private func gridCellWidth(width: Float32, hGap: Float32): Float32 {
        max(0.0, width - gapExtent(columns, hGap)) / Float32(columns)
    }
}

/** Places children left-to-right and wraps them onto content-sized rows. */
public class FlowRow <: Widget {
    private let children: Array<Widget>
    private var horizontalGap: Length = vpLength(CUI_GAP)
    private var verticalGap: Length = vpLength(CUI_GAP)

    public init(body!: () -> Unit) {
        children = buildChildren(body)
        emit(this)
    }

    /** Sets equal horizontal and vertical gaps, e.g. `.spacing(10.vp)`. */
    public func spacing(value: Length): FlowRow {
        horizontalGap = value
        verticalGap = value
        this
    }

    /** Sets equal horizontal and vertical gaps in virtual pixels. */
    public func spacing(value: Float32): FlowRow {
        spacing(vpLength(value))
    }

    /** Sets independent horizontal and vertical gaps. */
    public func spacing(horizontal: Length, vertical: Length): FlowRow {
        horizontalGap = horizontal
        verticalGap = vertical
        this
    }

    /** Sets independent horizontal and vertical gaps in virtual pixels. */
    public func spacing(horizontal: Float32, vertical: Float32): FlowRow {
        spacing(vpLength(horizontal), vpLength(vertical))
    }

    public func measure(ctx: UiContext, available: Size): Size {
        let extent = flowExtent(ctx, available, false, Rect.zero())
        Size(min(available.w, extent.w), min(available.h, extent.h))
    }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        let _ = flowExtent(ctx, Size(rect.w, rect.h), true, rect)
    }

    public func draw(ctx: UiContext): Unit {
        for (child in children) {
            if (!child.participatesInLayout()) {
                continue
            }
            child.draw(ctx)
        }
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        dispatchChildren(children, ctx, event)
    }

    public func focusableIds(): Array<String> {
        collectFocusableIds(children)
    }

    private func flowExtent(ctx: UiContext, available: Size, shouldLayout: Bool, frame: Rect): Size {
        let hGap = max(0.0, ctx.resolve(horizontalGap))
        let vGap = max(0.0, ctx.resolve(verticalGap))
        var x: Float32 = 0.0
        var y: Float32 = 0.0
        var rowHeight: Float32 = 0.0
        var usedWidth: Float32 = 0.0
        for (child in children) {
            if (!child.participatesInLayout()) {
                continue
            }
            let childSize = child.measure(ctx, available)
            if (x > 0.0 && x + childSize.w > available.w) {
                x = 0.0
                y += rowHeight + vGap
                rowHeight = 0.0
            }
            if (shouldLayout) {
                child.layout(ctx, Rect(frame.x + x, frame.y + y, childSize.w, childSize.h))
            }
            usedWidth = max(usedWidth, x + childSize.w)
            x += childSize.w + hGap
            rowHeight = max(rowHeight, childSize.h)
        }
        Size(usedWidth, y + rowHeight)
    }
}

/** A clipped, wheel-scrollable viewport with state retained by its stable `id`. */
public class ScrollView <: Widget {
    private let child: Widget
    private var scrollOffset: State<Float32>
    private let scrollBar: ScrollBar
    private var frame = Rect.zero()
    private var contentHeight: Float32 = 0.0

    public init(key!: ?String = None, body!: () -> Unit) {
        let ident = resolveControlKey(key, "ScrollView")
        child = buildChild(body)
        scrollOffset = localState<Float32>("ScrollView:${ident}:offset") {0.0}
        scrollBar = ScrollBar("ScrollView:${ident}:thumb")
        emit(this)
    }

    /** Uses an externally owned vertical scroll offset. */
    public func scrollState(value: State<Float32>): ScrollView {
        scrollOffset = value
        this
    }

    public func measure(_: UiContext, available: Size): Size {
        available
    }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        frame = rect
        // Content gets the full width until it overflows; then it gives up the bar's
        // gutter so the bar never covers it. A narrower child can only grow taller,
        // so a single re-measure settles the decision without oscillating.
        var contentWidth = rect.w
        var measured = child.measure(ctx, Size(contentWidth, LAYOUT_UNBOUNDED))
        if (measured.h > rect.h) {
            contentWidth = max(0.0, rect.w - scrollBarGutter())
            measured = child.measure(ctx, Size(contentWidth, LAYOUT_UNBOUNDED))
        }
        contentHeight = measured.h
        // Clamp writes only on change: layout runs every frame, and the offset may be an
        // externally owned state whose observers should not fire for no-op writes.
        let clamped = clampScrollOffset(scrollOffset.value, contentHeight, rect.h)
        if (clamped != scrollOffset.value) {
            scrollOffset.value = clamped
        }
        child.layout(ctx, Rect(rect.x, rect.y - scrollOffset.value, contentWidth, contentHeight))
    }

    public func draw(ctx: UiContext): Unit {
        ctx.renderer.pushClip(frame)
        child.draw(ctx)
        ctx.renderer.popClip()
        drawVerticalScrollBar(ctx, frame, scrollOffset.value, contentHeight, frame.h, active: scrollBar.dragging(ctx))
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        match (event) {
            case UiEvent.MouseWheel(_, wheelY, pointerX, pointerY) =>
                if (frame.contains(pointerX, pointerY)) {
                    scrollOffset.value = scrollOffsetAfterWheel(scrollOffset.value, wheelY, contentHeight, frame.h)
                    return true
                }
            case UiEvent.MouseDown(_, x, y) =>
                if (scrollBar.press(ctx, frame, scrollOffset, contentHeight, frame.h, x, y)) {
                    return true
                }
                if (!frame.contains(x, y)) {
                    return false
                }
            case UiEvent.MouseMove(x, y) =>
                if (scrollBar.drag(ctx, frame, scrollOffset, contentHeight, frame.h, y)) {
                    return true
                }
                // While a child drag is live (a slider knob, a text selection), track the
                // pointer past the viewport edge to the release — pointer capture — instead
                // of freezing the gesture at the boundary.
                if (!frame.contains(x, y) && ctx.dragId.isEmpty()) {
                    return false
                }
            case UiEvent.MouseUp(_, x, y) =>
                if (!frame.contains(x, y) && ctx.dragId.isEmpty()) {
                    return false
                }
            case _ => ()
        }
        child.handle(ctx, event)
    }

    public func isFlexible(): Bool {
        true
    }

    public func focusableIds(): Array<String> {
        child.focusableIds()
    }
}

private func alignedRect(bounds: Rect, width: Float32, height: Float32, alignment: Alignment): Rect {
    let x = match (alignment) {
        case Alignment.Top => bounds.x + (bounds.w - width) / 2.0
        case Alignment.Center => bounds.x + (bounds.w - width) / 2.0
        case Alignment.Bottom => bounds.x + (bounds.w - width) / 2.0
        case Alignment.TopTrailing => bounds.right() - width
        case Alignment.Trailing => bounds.right() - width
        case Alignment.BottomTrailing => bounds.right() - width
        case _ => bounds.x
    }
    let y = match (alignment) {
        case Alignment.Leading => bounds.y + (bounds.h - height) / 2.0
        case Alignment.Center => bounds.y + (bounds.h - height) / 2.0
        case Alignment.Trailing => bounds.y + (bounds.h - height) / 2.0
        case Alignment.BottomLeading => bounds.bottom() - height
        case Alignment.Bottom => bounds.bottom() - height
        case Alignment.BottomTrailing => bounds.bottom() - height
        case _ => bounds.y
    }
    Rect(x, y, width, height)
}

internal func dispatchChildren(children: Array<Widget>, ctx: UiContext, event: UiEvent): Bool {
    match (event) {
        case UiEvent.Frame(_) =>
            for (child in children) {
                let _ = child.handle(ctx, event)
            }
            return false
        case _ => ()
    }
    var i = children.size - 1
    while (i >= 0) {
        if (children[i].handle(ctx, event)) {
            return true
        }
        i -= 1
    }
    false
}

private func gapExtent(count: Int64, gap: Float32): Float32 {
    if (count <= 1) {
        0.0
    } else {
        Float32(count - 1) * gap
    }
}

private func sum(values: Array<Float32>): Float32 {
    var total: Float32 = 0.0
    for (value in values) {
        total += value
    }
    total
}

private func participatingCount(children: Array<Widget>): Int64 {
    var count: Int64 = 0
    for (child in children) {
        if (child.participatesInLayout()) {
            count += 1
        }
    }
    count
}
