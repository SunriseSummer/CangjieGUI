package cui.core

import std.collection.ArrayList
import sdl.{Color, FontSizes, MouseButton, Pen, Rect, Size, UiEvent}

private let BC_H: Float32 = 28.0
private let BC_HPAD: Float32 = 7.0
private let BC_SEP_W: Float32 = 18.0
// A segment index of -1 in the item list stands for a collapsed ellipsis.
private let BC_ELLIPSIS: Int64 = -1

/*
 * A breadcrumb trail: a horizontal path of segments separated by chevrons (e.g. 首页 › 文档 › 项目).
 * The last segment is the current location — shown emphasized and not clickable; earlier segments are
 * links that call `onSelect` with their index. When `maxItems` is set and the trail is longer, the
 * middle collapses to an ellipsis so the first and the last few stay visible. Without `onSelect` the
 * trail is a pure display.
 */
public class Breadcrumb <: Widget {
    private let id: String
    private let segments: Array<String>
    private let onSelect: ?(Int64) -> Unit
    private let items: Array<Int64>
    private var frame = Rect.zero()
    private let itemRects: Array<Rect>

    public init(segments: Array<String>, onSelect!: ?(Int64) -> Unit = None, maxItems!: Int64 = 0, key!: ?String = None) {
        this.id = resolveControlKey(key, "Breadcrumb")
        this.segments = segments
        this.onSelect = onSelect
        this.items = breadcrumbItems(segments.size, maxItems)
        this.itemRects = Array<Rect>(this.items.size, {_ => Rect.zero()})
        emit(this)
    }

    public func measure(ctx: UiContext, _: Size): Size {
        var total: Float32 = 0.0
        for (i in 0..items.size) {
            total += crumbWidth(ctx, items[i])
            if (i < items.size - 1) {
                total += BC_SEP_W
            }
        }
        Size(total, BC_H)
    }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        frame = rect
        var x = rect.x
        for (i in 0..items.size) {
            let w = crumbWidth(ctx, items[i])
            itemRects[i] = Rect(x, rect.y, w, rect.h)
            x += w
            if (i < items.size - 1) {
                x += BC_SEP_W
            }
        }
    }

    public func isFlexible(): Bool {
        false
    }

    public func draw(ctx: UiContext): Unit {
        ctx.renderer.pushClip(frame)
        for (i in 0..items.size) {
            let idx = items[i]
            let r = itemRects[i]
            if (idx == BC_ELLIPSIS) {
                drawCrumbText(ctx, r, "…", ctx.theme.mutedText)
            } else {
                drawSegment(ctx, r, idx)
            }
            if (i < items.size - 1) {
                drawSeparator(ctx, Rect(r.right(), r.y, BC_SEP_W, r.h))
            }
        }
        ctx.renderer.popClip()
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        match (event) {
            case UiEvent.MouseMove(x, y) => if (clickableIndexAt(x, y) >= 0) {
                ctx.claimHover(id, CursorShape.Interactive)
            }
            case UiEvent.MouseDown(MouseButton.Left, x, y) =>
                let hit = clickableIndexAt(x, y)
                if (hit >= 0) {
                    match (onSelect) {
                        case Some(callback) =>
                            callback(hit)
                            return true
                        case None => ()
                    }
                }
            case _ => ()
        }
        false
    }

    // The segment index under a pointer that is a clickable link (a real, non-current segment with an
    // `onSelect`), or -1.
    private func clickableIndexAt(x: Float32, y: Float32): Int64 {
        if (onSelect.isNone()) {
            return -1
        }
        for (i in 0..items.size) {
            let idx = items[i]
            if (idx != BC_ELLIPSIS && idx != segments.size - 1 && itemRects[i].contains(x, y)) {
                return idx
            }
        }
        -1
    }

    private func drawSegment(ctx: UiContext, r: Rect, idx: Int64): Unit {
        let isCurrent = idx == segments.size - 1
        let clickable = !isCurrent && onSelect.isSome()
        if (clickable && r.contains(ctx.mouseX, ctx.mouseY)) {
            ctx.renderer.fillRoundedRect(r, ctx.theme.smallRadius, ctx.theme.fieldActive)
        }
        let color = if (isCurrent) {
            ctx.theme.text
        } else if (clickable) {
            ctx.theme.accent
        } else {
            ctx.theme.mutedText
        }
        drawCrumbText(ctx, r, segments[idx], color)
    }

    private func drawCrumbText(ctx: UiContext, r: Rect, text: String, color: Color): Unit {
        let ty = r.centerY() - ctx.renderer.textHeight(pointSize: FontSizes.CONTROL) / 2.0
        ctx.renderer.text(text, r.x + BC_HPAD, ty, color, pointSize: FontSizes.CONTROL)
    }

    private func drawSeparator(ctx: UiContext, box: Rect): Unit {
        let cx = box.centerX()
        let cy = box.centerY()
        let pen = Pen(width: 1.5, color: ctx.theme.mutedText.withAlpha(160))
        ctx.renderer.strokeLine(cx - 2.0, cy - 4.0, cx + 2.0, cy, pen)
        ctx.renderer.strokeLine(cx + 2.0, cy, cx - 2.0, cy + 4.0, pen)
    }

    private func crumbWidth(ctx: UiContext, idx: Int64): Float32 {
        let label = if (idx == BC_ELLIPSIS) {
            "…"
        } else {
            segments[idx]
        }
        ctx.renderer.textWidth(label, pointSize: FontSizes.CONTROL) + 2.0 * BC_HPAD
    }
}

/*
 * The segment indices to display, with -1 marking a collapsed run. With `maxItems` unset (0) or a trail
 * no longer than it, every index shows. Otherwise the first segment, an ellipsis and the last
 * `maxItems - 1` segments show, e.g. 7 segments capped at 4 → 0, -1, 4, 5, 6.
 */
internal func breadcrumbItems(count: Int64, maxItems: Int64): Array<Int64> {
    if (count <= 0) {
        return []
    }
    let cap = max(2, maxItems)
    if (maxItems <= 0 || count <= cap) {
        let all = ArrayList<Int64>()
        for (i in 0..count) {
            all.add(i)
        }
        return all.toArray()
    }
    let tail = cap - 1
    let result = ArrayList<Int64>()
    result.add(0)
    result.add(BC_ELLIPSIS)
    var i = count - tail
    while (i < count) {
        result.add(i)
        i += 1
    }
    result.toArray()
}
