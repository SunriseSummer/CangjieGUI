package cui.controls

import std.collection.ArrayList
import sdl.{Color, FontSizes, MouseButton, Pen, Rect, Size, UiEvent}
import cui.core.{Bindable, CursorShape, UiContext, Widget, resolveControlKey, emit}

private let PAGE_BTN_W: Float32 = 34.0
private let PAGE_BTN_H: Float32 = 34.0
private let PAGE_GAP: Float32 = 4.0
// A page index of -1 in the item list stands for an ellipsis gap.
private let PAGE_ELLIPSIS: Int64 = -1

/**
 * A page navigator for long, paged content (search results, tables, catalogs). It shows previous/next
 * arrows around a windowed run of page numbers — always the first and last page, the pages around the
 * current one, and an ellipsis for any gap. Clicking a number jumps to that page; the arrows step one
 * page and disable at the ends. `current` is the zero-based page bound two-way, displayed one-based.
 */
public class Pagination <: Widget {
    private let id: String
    private let pageCount: Int64
    private let current: Bindable<Int64>
    private let items: Array<Int64>
    private var frame = Rect.zero()
    private var prevRect = Rect.zero()
    private var nextRect = Rect.zero()
    private let itemRects: Array<Rect>

    public init(pageCount: Int64, current: Bindable<Int64>, window!: Int64 = 1, key!: ?String = None) {
        this.id = resolveControlKey(key, "Pagination")
        this.pageCount = max(1, pageCount)
        this.current = current
        this.items = paginationItems(this.pageCount, clampPage(current.value, this.pageCount), max(0, window))
        this.itemRects = Array<Rect>(this.items.size, {_ => Rect.zero()})
        emit(this)
    }

    public func measure(_: UiContext, _: Size): Size {
        let cells = Float32(items.size + 2) // page cells plus the two arrows
        Size(cells * PAGE_BTN_W + (cells - 1.0) * PAGE_GAP, PAGE_BTN_H)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
        var cursor = rect.x
        prevRect = Rect(cursor, rect.y, PAGE_BTN_W, PAGE_BTN_H)
        cursor += PAGE_BTN_W + PAGE_GAP
        for (i in 0..items.size) {
            itemRects[i] = Rect(cursor, rect.y, PAGE_BTN_W, PAGE_BTN_H)
            cursor += PAGE_BTN_W + PAGE_GAP
        }
        nextRect = Rect(cursor, rect.y, PAGE_BTN_W, PAGE_BTN_H)
    }

    public func draw(ctx: UiContext): Unit {
        let page = clampPage(current.value, pageCount)
        drawArrow(ctx, prevRect, true, page > 0)
        for (i in 0..items.size) {
            let value = items[i]
            if (value == PAGE_ELLIPSIS) {
                drawEllipsis(ctx, itemRects[i])
            } else {
                drawPage(ctx, itemRects[i], value, value == page)
            }
        }
        drawArrow(ctx, nextRect, false, page < pageCount - 1)
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        match (event) {
            case UiEvent.MouseMove(x, y) => if (clickableAt(x, y)) {
                ctx.claimHover(id, CursorShape.Interactive)
            }
            case UiEvent.MouseDown(MouseButton.Left, x, y) =>
                let page = clampPage(current.value, pageCount)
                if (prevRect.contains(x, y)) {
                    if (page > 0) {
                        current.value = page - 1
                    }
                    return true
                }
                if (nextRect.contains(x, y)) {
                    if (page < pageCount - 1) {
                        current.value = page + 1
                    }
                    return true
                }
                for (i in 0..items.size) {
                    if (items[i] != PAGE_ELLIPSIS && itemRects[i].contains(x, y)) {
                        current.value = items[i]
                        return true
                    }
                }
            case _ => ()
        }
        false
    }

    // The pointer is over a clickable target: an enabled arrow or a real (non-ellipsis) page cell.
    // The ellipsis cell and a disabled arrow keep the default cursor.
    private func clickableAt(x: Float32, y: Float32): Bool {
        let page = clampPage(current.value, pageCount)
        if (prevRect.contains(x, y)) {
            return page > 0
        }
        if (nextRect.contains(x, y)) {
            return page < pageCount - 1
        }
        for (i in 0..items.size) {
            if (items[i] != PAGE_ELLIPSIS && itemRects[i].contains(x, y)) {
                return true
            }
        }
        false
    }

    private func drawPage(ctx: UiContext, rect: Rect, page: Int64, isCurrent: Bool): Unit {
        let hovered = rect.contains(ctx.mouseX, ctx.mouseY)
        if (isCurrent) {
            ctx.renderer.fillRoundedRect(rect, ctx.theme.smallRadius, ctx.theme.accent)
        } else if (hovered) {
            ctx.renderer.fillRoundedRect(rect, ctx.theme.smallRadius, ctx.theme.fieldActive)
        } else {
            ctx.renderer.fillRoundedRect(rect, ctx.theme.smallRadius, ctx.theme.field)
        }
        let color = if (isCurrent) {
            ctx.theme.accentText
        } else {
            ctx.theme.text
        }
        // Displayed one-based.
        drawCentered(ctx, "${page + 1}", rect, color)
    }

    private func drawEllipsis(ctx: UiContext, rect: Rect): Unit {
        drawCentered(ctx, "…", rect, ctx.theme.mutedText)
    }

    private func drawArrow(ctx: UiContext, rect: Rect, pointsLeft: Bool, enabled: Bool): Unit {
        let hovered = enabled && rect.contains(ctx.mouseX, ctx.mouseY)
        let fill = if (hovered) {
            ctx.theme.fieldActive
        } else {
            ctx.theme.field
        }
        ctx.renderer.fillRoundedRect(rect, ctx.theme.smallRadius, fill)
        let color = if (enabled) {
            ctx.theme.text
        } else {
            ctx.theme.mutedText.withAlpha(120)
        }
        let pen = Pen(width: 1.8, color: color)
        let cx = rect.centerX()
        let cy = rect.centerY()
        if (pointsLeft) {
            ctx.renderer.strokeLine(cx + 3.0, cy - 5.0, cx - 3.0, cy, pen)
            ctx.renderer.strokeLine(cx - 3.0, cy, cx + 3.0, cy + 5.0, pen)
        } else {
            ctx.renderer.strokeLine(cx - 3.0, cy - 5.0, cx + 3.0, cy, pen)
            ctx.renderer.strokeLine(cx + 3.0, cy, cx - 3.0, cy + 5.0, pen)
        }
    }

    private func drawCentered(ctx: UiContext, text: String, rect: Rect, color: Color): Unit {
        let w = ctx.renderer.textWidth(text, pointSize: FontSizes.CONTROL)
        let h = ctx.renderer.textHeight(pointSize: FontSizes.CONTROL)
        ctx.renderer.text(text, rect.centerX() - w / 2.0, rect.centerY() - h / 2.0, color, pointSize: FontSizes.CONTROL)
    }
}

internal func clampPage(page: Int64, pageCount: Int64): Int64 {
    if (pageCount <= 0) {
        0
    } else if (page < 0) {
        0
    } else if (page >= pageCount) {
        pageCount - 1
    } else {
        page
    }
}

/*
 * The page indices to display: always the first and last page, the run current±window, and -1 for each
 * ellipsis gap between them. So 20 pages at page 10 (window 1) yields 0, -1, 9, 10, 11, -1, 19.
 */
internal func paginationItems(pageCount: Int64, current: Int64, window: Int64): Array<Int64> {
    if (pageCount <= 0) {
        return []
    }
    if (pageCount == 1) {
        return [0]
    }
    let cur = clampPage(current, pageCount)
    let lo = max(0, cur - window)
    let hi = min(pageCount - 1, cur + window)
    let result = ArrayList<Int64>()
    result.add(0)
    if (lo > 1) {
        result.add(PAGE_ELLIPSIS)
    }
    var p = max(1, lo)
    let mid = min(pageCount - 2, hi)
    while (p <= mid) {
        result.add(p)
        p += 1
    }
    if (hi < pageCount - 2) {
        result.add(PAGE_ELLIPSIS)
    }
    result.add(pageCount - 1)
    result.toArray()
}
