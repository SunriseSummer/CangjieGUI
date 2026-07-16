package cui.controls

import std.collection.ArrayList
import sdl.{MouseButton, Rect, Size, SurfaceStyle, UiEvent, clampF32}
import cui.core.{CUI_SHADOW_CLEARANCE, CursorShape, State, UiContext, Widget, resolveControlKey, buildLazyChildren,
    drawSurface, emit, lazyKeyOrIndex, localState}

// Width of the drag handle at the left of each row.
private let REORDER_HANDLE_W: Float32 = 30.0

/**
 * A vertical list whose fixed-height rows can be dragged to reorder. Each row carries a grip handle on
 * its left; pressing the handle lifts the row to follow the pointer while the others part to open a gap
 * at the drop position. Releasing commits the move by calling `onMove(from, to)` — the caller reorders
 * its own data, and the next build shows the new order.
 *
 * Rows are ordinary widgets built by `item`, so a row can hold its own content and controls (presses
 * outside the handle fall through to the row). Row identity follows `key` so per-row state survives the
 * reorder. Suited to modest, fully visible lists (a settings order, a playlist); wrap a long one so the
 * drag interaction stays within view.
 */
public class ReorderableList <: Widget {
    private let count: Int64
    private let rowHeight: Float32
    private let spacing: Float32
    private let onMove: (Int64, Int64) -> Unit
    private let rows: Array<Widget>
    private let dragIndex: State<Int64>
    private let grabOffset: State<Float32>
    private let pointerY: State<Float32>
    private let dragId: String
    private var frame = Rect.zero()

    public init(
        count: Int64,
        rowHeight: Float32,
        onMove: (Int64, Int64) -> Unit,
        spacing!: Float32 = 6.0,
        key!: ?((Int64) -> String) = None,
        id!: ?String = None,
        item!: (Int64) -> Unit
    ) {
        let ident = resolveControlKey(id, "ReorderableList")
        this.count = max(0, count)
        this.rowHeight = max(1.0, rowHeight)
        this.spacing = max(0.0, spacing)
        this.onMove = onMove
        this.dragId = "ReorderableList:${ident}:drag"
        this.dragIndex = localState<Int64>("ReorderableList:${ident}:dragIndex") {-1}
        this.grabOffset = localState<Float32>("ReorderableList:${ident}:grab") {0.0}
        this.pointerY = localState<Float32>("ReorderableList:${ident}:pointerY") {0.0}
        let pairs = buildLazyChildren("ReorderableList:${ident}", 0, this.count - 1, lazyKeyOrIndex(key), item)
        let built = ArrayList<Widget>()
        for (pair in pairs) {
            let (_, widget) = pair
            built.add(widget)
        }
        this.rows = built.toArray()
        emit(this)
    }

    /**
     * The data-driven form: reorder over an `Array<T>`. `onMove(from, to)` receives array indices; the
     * caller applies the move to its own state. `key` gives each item a stable identity across the move.
     *
     * ```
     * ReorderableList.of(model.tracks, 52.0, {from, to => model.move(from, to)}, key: {t => t.id}) {
     *     track => trackRow(track)
     * }
     * ```
     */
    public static func of<T>(
        data: Array<T>,
        rowHeight: Float32,
        onMove: (Int64, Int64) -> Unit,
        spacing!: Float32 = 6.0,
        key!: ?((T) -> String) = None,
        id!: ?String = None,
        item!: (T) -> Unit
    ): ReorderableList {
        let itemKey: ?((Int64) -> String) = match (key) {
            case Some(k) => Some({index => k(data[index])})
            case None => None
        }
        ReorderableList(data.size, rowHeight, onMove, spacing: spacing, key: itemKey, id: id) {
            index => item(data[index])
        }
    }

    public func measure(_: UiContext, available: Size): Size {
        Size(available.w, contentHeight())
    }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        frame = rect
        let contentX = rect.x + REORDER_HANDLE_W
        let contentW = max(0.0, rect.w - REORDER_HANDLE_W)
        let target = dropTarget()
        for (i in 0..rows.size) {
            let y = rowTop(i, target)
            rows[i].layout(ctx, Rect(contentX, y, contentW, rowHeight))
        }
    }

    public func draw(ctx: UiContext): Unit {
        let target = dropTarget()
        let dragging = dragIndex.value
        // Non-dragged rows at their (possibly shifted) slots.
        for (i in 0..rows.size) {
            if (i != dragging) {
                drawRow(ctx, i, rowTop(i, target), false)
            }
        }
        // The dragged row last, lifted, so it floats above the rest.
        if (dragging >= 0 && dragging < rows.size) {
            drawRow(ctx, dragging, rowTop(dragging, target), true)
        }
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        let dragging = dragIndex.value >= 0
        match (event) {
            case UiEvent.Frame(_) =>
                for (row in rows) {
                    let _ = row.handle(ctx, event)
                }
                return false
            case UiEvent.MouseDown(MouseButton.Left, x, y) =>
                if (!dragging) {
                    let row = handleRowAt(x, y)
                    if (row >= 0) {
                        dragIndex.value = row
                        grabOffset.value = y - slotTop(row)
                        pointerY.value = y
                        ctx.beginDrag(dragId)
                        return true
                    }
                }
            case UiEvent.MouseMove(x, y) =>
                // Hovering a grip advertises the drag affordance; a live drag keeps the shape claimed
                // even as the pointer strays off the strip.
                if (dragging || handleRowAt(x, y) >= 0) {
                    ctx.claimHover(dragId, CursorShape.Interactive)
                }
                if (dragging && ctx.isDragging(dragId) && ctx.leftMouseDown) {
                    pointerY.value = y
                    return true
                }
            case UiEvent.MouseUp(MouseButton.Left, _, _) =>
                if (dragging) {
                    commitDrag()
                    return true
                }
            case _ => ()
        }
        // Not a drag gesture: route to the row content so its own controls work.
        if (!dragging) {
            var i = rows.size - 1
            while (i >= 0) {
                if (rows[i].handle(ctx, event)) {
                    return true
                }
                i -= 1
            }
        }
        false
    }

    public func focusableIds(): Array<String> {
        let ids = ArrayList<String>()
        for (row in rows) {
            for (fid in row.focusableIds()) {
                ids.add(fid)
            }
        }
        ids.toArray()
    }

    private func contentHeight(): Float32 {
        if (count <= 0) {
            0.0
        } else {
            Float32(count) * rowHeight + Float32(count - 1) * spacing
        }
    }

    private func stride(): Float32 {
        rowHeight + spacing
    }

    // The resting top of row `pos` (its slot in display order).
    private func slotTop(pos: Int64): Float32 {
        frame.y + Float32(pos) * stride()
    }

    // The top of row `i` this frame: its lifted pointer position when dragged, otherwise its slot after
    // the drag preview reorders the list around the open gap.
    private func rowTop(i: Int64, target: Int64): Float32 {
        let dragging = dragIndex.value
        if (dragging < 0) {
            return slotTop(i)
        }
        if (i == dragging) {
            let lifted = pointerY.value - grabOffset.value
            return clampF32(lifted, frame.y, frame.y + Float32(max(0, count - 1)) * stride())
        }
        slotTop(previewPosition(i, dragging, target))
    }

    // Display position of a non-dragged row when the dragged row is previewed at `target`.
    private func previewPosition(i: Int64, dragging: Int64, target: Int64): Int64 {
        let reduced = if (i > dragging) {
            i - 1
        } else {
            i
        }
        if (reduced >= target) {
            reduced + 1
        } else {
            reduced
        }
    }

    // The drop index for the dragged row's current position (by its centre).
    private func dropTarget(): Int64 {
        if (dragIndex.value < 0 || count <= 0) {
            return dragIndex.value
        }
        let lifted = pointerY.value - grabOffset.value
        let center = lifted + rowHeight / 2.0
        let raw = Int64((center - frame.y) / stride())
        if (raw < 0) {
            0
        } else if (raw > count - 1) {
            count - 1
        } else {
            raw
        }
    }

    private func commitDrag(): Unit {
        let from = dragIndex.value
        let to = dropTarget()
        dragIndex.value = -1
        if (from >= 0 && from < count && to >= 0 && to < count && from != to) {
            onMove(from, to)
        }
    }

    // The row whose handle contains (x, y), or -1. The handle is the left strip of each row's slot.
    private func handleRowAt(x: Float32, y: Float32): Int64 {
        if (x < frame.x || x > frame.x + REORDER_HANDLE_W) {
            return -1
        }
        if (y < frame.y || count <= 0) {
            return -1
        }
        let index = Int64((y - frame.y) / stride())
        if (index < 0 || index >= count) {
            return -1
        }
        // Reject the spacing gap between rows.
        if (y - slotTop(index) > rowHeight) {
            return -1
        }
        index
    }

    private func drawRow(ctx: UiContext, i: Int64, top: Float32, lifted: Bool): Unit {
        let rowRect = Rect(frame.x, top, frame.w, rowHeight)
        if (lifted) {
            // A raised surface with a shadow so the dragged row reads as picked up.
            drawSurface(ctx, rowRect, SurfaceStyle(ctx.theme.panelRaised, border: ctx.theme.accent,
                radius: ctx.theme.controlRadius, borderWidth: 1.0, shadow: ctx.theme.shadow, shadowOffsetY: 5.0))
        }
        drawHandle(ctx, Rect(frame.x, top, REORDER_HANDLE_W, rowHeight), lifted)
        // The slot clip is widened by the shadow clearance so a card row's soft halo wraps its
        // rounded corners instead of being sliced off at the slot boundary; row content itself is
        // slot-sized, so only the halo occupies the margin.
        ctx.renderer.pushClip(rowRect.inset(-CUI_SHADOW_CLEARANCE))
        rows[i].draw(ctx)
        ctx.renderer.popClip()
    }

    // Two columns of grip dots marking the draggable handle.
    private func drawHandle(ctx: UiContext, box: Rect, active: Bool): Unit {
        let color = if (active) {
            ctx.theme.accent
        } else {
            ctx.theme.mutedText
        }
        let cx = box.x + box.w / 2.0
        let cy = box.centerY()
        var row = -1
        while (row <= 1) {
            let dy = Float32(row) * 5.0
            ctx.renderer.fillCircle(cx - 3.0, cy + dy, 1.3, color)
            ctx.renderer.fillCircle(cx + 3.0, cy + dy, 1.3, color)
            row += 1
        }
    }
}
