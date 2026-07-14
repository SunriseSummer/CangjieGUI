package cui.core

import std.collection.ArrayList
import sdl.{Rect, Size, UiEvent}

// Extra rows built above and below the viewport so a one-frame scroll never reveals a blank edge.
private let LAZY_OVERSCAN: Int64 = 2

// The viewport height assumed on the very first frame, before layout has measured the real one — a
// full-ish screen, so the first frame is populated rather than blank. Layout corrects it at once.
private let LAZY_DEFAULT_VIEWPORT: Float32 = 720.0

/**
 * A vertically scrolling list that materializes only the rows near the viewport. Rows have a fixed
 * height (in logical pixels) and are built on demand by index, so build, layout and draw are all
 * O(visible) rather than O(count): a list of thousands of arbitrary item widgets scrolls at the
 * cost of a screenful.
 *
 * Because only visible rows are built, per-row local state (`rememberState` / `Keyed`) lives only
 * while a row is on screen and is dropped when it scrolls off; hoist any state that must outlive
 * scrolling into the application model. The scroll offset may be owned externally (via `scroll`) for
 * coordination or animation. The `id` scopes the retained scroll and per-row state, like other
 * scrollable controls.
 *
 * Immediate-mode note: the tree is rebuilt every frame, so the visible window is chosen during the
 * build pass from the scroll offset and viewport height retained from the previous frame, then that
 * same snapshot drives layout and draw. A wheel or drag updates the live offset for the next frame;
 * the overscan rows keep the edges filled across that one-frame settle.
 */
public class LazyColumn <: Widget {
    private let id: String
    private let count: Int64
    private let itemHeight: Float32
    private let spacing: Float32
    private let scrollStateValue: State<Float32>
    private let viewportHeightState: State<Float32>
    private let scrollBar: ScrollBar
    // Rows materialized this frame, each paired with its absolute index for positioning and events.
    private let visibleItems: Array<(Int64, Widget)>
    // The scroll offset snapshotted for the whole frame so build, layout and draw agree.
    private let frameScroll: Float32
    private var frame = Rect.zero()

    /**
     * The index form: `count` rows built on demand by index. Throws `IllegalArgumentException` when
     * `id` is empty. Row height is in logical pixels. `key` optionally gives each row a stable
     * identity string (so its per-row state follows the item across inserts/reorders); when omitted,
     * rows are keyed by index — see `LazyColumn.of` for the data-driven form.
     */
    public init(
        id: String,
        count: Int64,
        itemHeight: Float32,
        spacing!: Float32 = 0.0,
        scroll!: ?State<Float32> = None,
        key!: ?((Int64) -> String) = None,
        item!: (Int64) -> Unit
    ) {
        requireControlId(id, "LazyColumn")
        this.id = id
        this.count = max(0, count)
        this.itemHeight = max(1.0, itemHeight)
        this.spacing = max(0.0, spacing)
        this.scrollStateValue = match (scroll) {
            case Some(value) => value
            case None => localState<Float32>("LazyColumn:${id}:scroll") {0.0}
        }
        // Retained so the build pass (which has no layout rect yet) knows how tall the viewport was
        // last frame and thus which rows to materialize; layout updates it for the next frame.
        this.viewportHeightState = localState<Float32>("LazyColumn:${id}:viewportH") {LAZY_DEFAULT_VIEWPORT}
        this.scrollBar = ScrollBar("LazyColumn:${id}:thumb")
        let content = lazyContentHeight(this.count, this.itemHeight, this.spacing)
        this.frameScroll = clampScrollOffset(this.scrollStateValue.value, content, this.viewportHeightState.value)
        this.visibleItems = buildVisibleItems(this.id, this.count, this.itemHeight, this.spacing, this.frameScroll,
            this.viewportHeightState.value, rowKeyOrIndex(key), item)
        emit(this)
    }

    /**
     * The data-driven form: builds a virtualized column from `data` and a per-item row builder, so a
     * list of arbitrary item widgets over an `Array<T>` needs neither a manual `count` nor an
     * index-into-data lookup. `key` gives each item a stable identity (its per-row state and position
     * follow the item across inserts/reorders rather than the slot); omit it to key by index.
     * `itemHeight` is the fixed row height in logical pixels, as for the index form.
     *
     * ```
     * LazyColumn.of("notes", model.notes, 72.0, key: {n => n.id}) { note => noteRow(note) }
     * ```
     */
    public static func of<T>(
        id: String,
        data: Array<T>,
        itemHeight: Float32,
        spacing!: Float32 = 0.0,
        scroll!: ?State<Float32> = None,
        key!: ?((T) -> String) = None,
        item!: (T) -> Unit
    ): LazyColumn {
        let rowKey: ?((Int64) -> String) = match (key) {
            case Some(k) => Some({index => k(data[index])})
            case None => None
        }
        LazyColumn(id, data.size, itemHeight, spacing: spacing, scroll: scroll, key: rowKey) {
            index => item(data[index])
        }
    }

    public func measure(_: UiContext, available: Size): Size {
        Size(available.w, available.h)
    }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        frame = rect
        // Record the viewport height for the next frame's build; write-on-change to avoid churn.
        let _ = viewportHeightState.setIfChanged(rect.h)
        let content = lazyContentHeight(count, itemHeight, spacing)
        // Correct the live offset for the next frame in case the content shrank.
        let clamped = clampScrollOffset(scrollStateValue.value, content, rect.h)
        if (clamped != scrollStateValue.value) {
            scrollStateValue.value = clamped
        }
        let stride = itemHeight + spacing
        let contentWidth = if (content > rect.h) {
            max(0.0, rect.w - scrollBarGutter())
        } else {
            rect.w
        }
        for (pair in visibleItems) {
            let (index, widget) = pair
            let y = rect.y - frameScroll + Float32(index) * stride
            widget.layout(ctx, Rect(rect.x, y, contentWidth, itemHeight))
        }
    }

    public func draw(ctx: UiContext): Unit {
        let content = lazyContentHeight(count, itemHeight, spacing)
        let stride = itemHeight + spacing
        ctx.renderer.pushClip(frame)
        for (pair in visibleItems) {
            let (index, widget) = pair
            // Clip each row to its own bounds (intersected with the viewport) so a row whose content
            // exceeds itemHeight is truncated rather than bleeding over its neighbour.
            let rowRect = Rect(frame.x, frame.y - frameScroll + Float32(index) * stride, frame.w, itemHeight)
            ctx.renderer.pushClip(rowRect)
            widget.draw(ctx)
            ctx.renderer.popClip()
        }
        ctx.renderer.popClip()
        drawVerticalScrollBar(ctx, frame, frameScroll, content, frame.h, active: scrollBar.dragging(ctx))
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        let content = lazyContentHeight(count, itemHeight, spacing)
        let viewportH = frame.h
        match (event) {
            case UiEvent.Frame(_) =>
                for (pair in visibleItems) {
                    let (_, widget) = pair
                    let _ = widget.handle(ctx, event)
                }
                return false
            case UiEvent.MouseWheel(_, wheelY, pointerX, pointerY) =>
                if (frame.contains(pointerX, pointerY)) {
                    scrollStateValue.value = scrollOffsetAfterWheel(scrollStateValue.value, wheelY, content, viewportH)
                    return true
                }
            case UiEvent.MouseDown(_, x, y) =>
                if (scrollBar.press(ctx, frame, scrollStateValue, content, viewportH, x, y)) {
                    return true
                }
                if (!frame.contains(x, y)) {
                    return false
                }
            case UiEvent.MouseMove(x, y) =>
                if (scrollBar.drag(ctx, frame, scrollStateValue, content, viewportH, y)) {
                    return true
                }
                // While a child drag is live, track the pointer past the edge to the release.
                if (!frame.contains(x, y) && ctx.dragId.isEmpty()) {
                    return false
                }
            case UiEvent.MouseUp(_, x, y) =>
                if (!frame.contains(x, y) && ctx.dragId.isEmpty()) {
                    return false
                }
            case _ => ()
        }
        // Route to the materialized rows, top-most first, so a row consumes its own clicks.
        var i = visibleItems.size - 1
        while (i >= 0) {
            let (_, widget) = visibleItems[i]
            if (widget.handle(ctx, event)) {
                return true
            }
            i -= 1
        }
        false
    }

    public func isFlexible(): Bool {
        true
    }

    public func focusableIds(): Array<String> {
        let ids = ArrayList<String>()
        for (pair in visibleItems) {
            let (_, widget) = pair
            for (fid in widget.focusableIds()) {
                ids.add(fid)
            }
        }
        ids.toArray()
    }
}

/** The total scrollable height of `count` fixed-height rows separated by `spacing`. */
internal func lazyContentHeight(count: Int64, itemHeight: Float32, spacing: Float32): Float32 {
    if (count <= 0) {
        return 0.0
    }
    Float32(count) * (itemHeight + spacing) - spacing
}

/*
 * The inclusive [first, last] row range to materialize for a viewport at `scroll`, widened by
 * `overscan` rows each side. Returns an empty range (first > last) when there is nothing to show.
 */
internal func lazyVisibleRange(
    scroll: Float32,
    viewportH: Float32,
    itemHeight: Float32,
    spacing: Float32,
    count: Int64,
    overscan: Int64
): (Int64, Int64) {
    if (count <= 0 || itemHeight <= 0.0) {
        return (0, -1)
    }
    let stride = itemHeight + spacing
    let top = max(0.0, scroll)
    var first = Int64(top / stride) - overscan
    if (first < 0) {
        first = 0
    }
    var last = Int64((top + max(0.0, viewportH)) / stride) + overscan
    if (last > count - 1) {
        last = count - 1
    }
    (first, last)
}

// Materializes the visible rows during the build pass, each scoped by `key(rowIndex)` so its local
// state follows it (across scrolls, and — with a data key — across inserts/reorders); it is dropped
// when the row scrolls off, so hoist anything that must persist.
private func buildVisibleItems(
    id: String,
    count: Int64,
    itemHeight: Float32,
    spacing: Float32,
    scroll: Float32,
    viewportH: Float32,
    key: (Int64) -> String,
    item: (Int64) -> Unit
): Array<(Int64, Widget)> {
    let (first, last) = lazyVisibleRange(scroll, viewportH, itemHeight, spacing, count, LAZY_OVERSCAN)
    let built = ArrayList<(Int64, Widget)>()
    var index = first
    while (index <= last) {
        let rowIndex = index
        let widget = buildKeyedChild("LazyColumn:${id}:item:${key(rowIndex)}") {=> item(rowIndex)}
        built.add((rowIndex, widget))
        index += 1
    }
    built.toArray()
}

// The effective row-key function: the caller's key, or the row index as a string. The index default
// reproduces the historical per-row scope key exactly, so index-keyed lists are byte-for-byte unchanged.
private func rowKeyOrIndex(key: ?((Int64) -> String)): (Int64) -> String {
    match (key) {
        case Some(k) => k
        case None => {index => "${index}"}
    }
}

/**
 * A vertically scrolling, virtualized grid: `data` arranged in `columns` equal columns and windowed by
 * row, so a large collection of uniform cells — a photo wall, a card grid — costs only a screenful.
 * It composes the proven pieces (each virtualized row is a `Grid` of up to `columns` cells over the
 * vertical `LazyColumn`), so it needs no separate horizontal scrolling. `itemHeight` is the fixed row
 * height in logical pixels; `spacing` is the gap between rows and `columnSpacing` the gap between cells.
 * Cells within a row are keyed by their position, so per-cell local state follows the slot — hoist
 * anything that must persist across data reorders.
 *
 * ```
 * LazyGrid("gallery", photos, 4, 160.0, spacing: 12.0, columnSpacing: 12.0) { photo => photoCell(photo) }
 * ```
 */
public func LazyGrid<T>(
    id: String,
    data: Array<T>,
    columns: Int64,
    itemHeight: Float32,
    spacing!: Float32 = 0.0,
    columnSpacing!: Float32 = 0.0,
    scroll!: ?State<Float32> = None,
    item!: (T) -> Unit
): LazyColumn {
    let cols = max(1, columns)
    let count = data.size
    let rowCount = (count + cols - 1) / cols
    LazyColumn(id, rowCount, itemHeight, spacing: spacing, scroll: scroll) {
        rowIndex =>
        Grid(cols) {
            var c = 0
            while (c < cols) {
                let dataIndex = rowIndex * cols + c
                if (dataIndex < count) {
                    item(data[dataIndex])
                }
                c += 1
            }
        }.spacing(columnSpacing)
    }
}
