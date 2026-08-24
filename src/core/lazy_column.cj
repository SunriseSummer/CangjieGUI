package cui.core

import std.collection.ArrayList
import sdl.{Rect, Size, UiEvent}

// The viewport height assumed on the very first frame, before layout has measured the real one — a
// full-ish screen, so the first frame is populated rather than blank. Layout corrects it at once.
let LAZY_DEFAULT_VIEWPORT: Float32 = 720.0

/**
 * A vertically scrolling list that materializes only the rows near the viewport. Rows have a fixed
 * height (in logical pixels) and are built on demand by index, so build, layout and draw are all
 * O(visible) rather than O(count): a list of thousands of arbitrary item widgets scrolls at the
 * cost of a screenful.
 *
 * Because only visible rows are built, per-row local state (`rememberState` / `Keyed`) lives only
 * while a row is on screen and is dropped when it scrolls off; hoist any state that must outlive
 * scrolling into the application model. The scroll offset may be owned externally (via `scroll`) or
 * by a `LazyViewportController`; the controller can reveal a stable key. `revision` tells the list
 * when keys moved so the top visible key remains anchored across inserts and reorders.
 *
 * Immediate-mode note: the tree is rebuilt every frame, so the visible window is chosen during the
 * build pass from the scroll offset and viewport height retained from the previous frame, then that
 * same snapshot drives layout and draw. A wheel or drag updates the live offset for the next frame.
 * Overscan is pixel-based and expands in the travel direction, independent of row height.
 */
public class LazyColumn <: Widget {
    private let count: Int64
    private let itemHeight: Float32
    private let spacing: Float32
    private let scrollStateValue: State<Float32>
    private let keyForIndex: (Int64) -> String
    private let viewportMemory: LazyViewportMemory
    private let scrollBar: ScrollBar
    // Rows materialized this frame, each paired with its absolute index for positioning and events.
    private let visibleItems: Array<(Int64, Widget)>
    // The scroll offset snapshotted for the whole frame so build, layout and draw agree.
    private let frameScroll: Float32
    private var frame = Rect.zero()

    /**
     * The index form: `count` rows built on demand by index. `id` is the optional container identity
     * (auto-derived by build order when omitted; an explicit one must be non-empty). Row height is in
     * logical pixels. `key` optionally gives each row a stable identity string (so its per-row state
     * follows the item across inserts/reorders); when omitted, rows are keyed by index — see
     * `LazyColumn.of` for the data-driven form. Increment `revision` when keys insert/reorder;
     * `overscan` is the idle pixel margin and adapts to scroll motion.
     */
    public init(
        count: Int64,
        itemHeight: Float32,
        spacing!: Float32 = 0.0,
        scroll!: ?State<Float32> = None,
        key!: ?((Int64) -> String) = None,
        id!: ?String = None,
        revision!: UInt64 = UInt64(0),
        controller!: ?LazyViewportController = None,
        overscan!: Float32 = LAZY_DEFAULT_OVERSCAN_PIXELS,
        item!: (Int64) -> Unit
    ) {
        let ident = resolveControlKey(id, "LazyColumn")
        let resolvedItemHeight = max(1.0, itemHeight)
        let resolvedSpacing = max(0.0, spacing)
        this.count = max(0, count)
        this.itemHeight = resolvedItemHeight
        this.spacing = resolvedSpacing
        if (scroll.isSome() && controller.isSome()) {
            throw IllegalArgumentException("LazyColumn accepts either scroll or controller, not both")
        }
        this.scrollStateValue = match (controller) {
            case Some(value) => value.state()
            case None => match (scroll) {
                case Some(value) => value
                case None => localState<Float32>("LazyColumn:${ident}:scroll") {0.0}
            }
        }
        let resolvedKey = lazyKeyOrIndex(key)
        this.keyForIndex = resolvedKey
        this.viewportMemory = localState<LazyViewportMemory>("LazyColumn:${ident}:viewport") {
            LazyViewportMemory(revision)
        }.value
        this.scrollBar = ScrollBar("LazyColumn:${ident}:thumb")
        let content = lazyContentHeight(this.count, resolvedItemHeight, resolvedSpacing)
        let current = clampScrollOffset(this.scrollStateValue.value, content, this.viewportMemory.viewportExtent)
        let geometry = LazyItemGeometry(this.count, resolvedKey,
            {index => lazyFixedItemTop(index, resolvedItemHeight, resolvedSpacing)}, {_ => resolvedItemHeight}, content)
        let anchored = lazyResolveAnchoredScroll(this.viewportMemory, revision, revision, current, geometry)
        this.frameScroll = lazyResolveControllerScroll(controller, this.viewportMemory, anchored, geometry)
        let insets = lazyAdaptiveOverscan(overscan, this.frameScroll, this.viewportMemory.previousScroll,
            this.viewportMemory.viewportExtent)
        let (first, last) = lazyFixedVisibleRange(this.frameScroll, this.viewportMemory.viewportExtent,
            resolvedItemHeight, resolvedSpacing, this.count, insets)
        this.visibleItems = buildLazyChildren("LazyColumn:${ident}", first, last, resolvedKey, item)
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
     * LazyColumn.of(model.notes, 72.0, key: {n => n.id}) { note => noteRow(note) }
     * ```
     */
    public static func of<T>( // cjcheck-ignore: param-count # declarative factory keeps named optional controls at the call site; a config wrapper would add ceremony
        data: Array<T>,
        itemHeight: Float32,
        spacing!: Float32 = 0.0,
        scroll!: ?State<Float32> = None,
        key!: ?((T) -> String) = None,
        id!: ?String = None,
        revision!: UInt64 = UInt64(0),
        controller!: ?LazyViewportController = None,
        overscan!: Float32 = LAZY_DEFAULT_OVERSCAN_PIXELS,
        item!: (T) -> Unit
    ): LazyColumn {
        let rowKey: ?((Int64) -> String) = match (key) {
            case Some(k) => Some({index => k(data[index])})
            case None => None
        }
        LazyColumn(data.size, itemHeight, spacing: spacing, scroll: scroll, key: rowKey, id: id, revision: revision,
            controller: controller, overscan: overscan) {
            index => item(data[index])
        }
    }

    public func measure(_: UiContext, available: Size): Size {
        Size(available.w, available.h)
    }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        frame = rect
        viewportMemory.viewportExtent = rect.h
        let content = lazyContentHeight(count, itemHeight, spacing)
        // Commit a clamp, anchor correction or controller request after this frame's snapshot has
        // already selected its rows. The following rebuild sees the same value and is stable.
        if (lazyFloatChanged(frameScroll, scrollStateValue.value)) {
            scrollStateValue.value = frameScroll
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
        lazyRememberAnchor(viewportMemory, frameScroll, count, {offset => Int64(max(0.0, offset) / stride)}, keyForIndex,
            {index => lazyFixedItemTop(index, itemHeight, spacing)})
    }

    public func draw(ctx: UiContext): Unit {
        let content = lazyContentHeight(count, itemHeight, spacing)
        let stride = itemHeight + spacing
        // Exact on the scroll axis, shadow clearance on the cross axis (see CUI_SHADOW_CLEARANCE).
        ctx.renderer.pushClip(Rect(frame.x - CUI_SHADOW_CLEARANCE, frame.y, frame.w + 2.0 * CUI_SHADOW_CLEARANCE,
            frame.h))
        for (pair in visibleItems) {
            let (index, widget) = pair
            // Clip each row to its own bounds plus shadow clearance (intersected with the viewport):
            // grossly oversized content is still truncated near its slot, while a card row's soft
            // halo wraps its corners instead of being cut into hard-edged bands at the slot line.
            let rowRect = Rect(frame.x, frame.y - frameScroll + Float32(index) * stride, frame.w, itemHeight)
            ctx.renderer.pushClip(rowRect.inset(-CUI_SHADOW_CLEARANCE))
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
                    broadcastEvent(widget, ctx, event)
                }
                return false
            case UiEvent.MouseWheel(_, wheelY, pointerX, pointerY) =>
                // Content that fits leaves the wheel to an enclosing scroller (no dead zone).
                if (frame.contains(pointerX, pointerY) && maxScrollOffset(content, viewportH) > 0.0) {
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
        collectLazyFocusableIds(visibleItems)
    }
}

internal func lazyFixedItemTop(index: Int64, itemExtent: Float32, spacing: Float32): Float32 {
    Float32(index) * (itemExtent + spacing)
}

/** The total scrollable height of `count` fixed-height rows separated by `spacing`. */
internal func lazyContentHeight(count: Int64, itemHeight: Float32, spacing: Float32): Float32 {
    if (count <= 0) {
        return 0.0
    }
    Float32(count) * (itemHeight + spacing) - spacing
}

// Materializes the visible items in `[first, last]` during the build pass, each scoped by
// `scope:item:key(index)` so its local state follows it (across scrolls, and — with a data key —
// across inserts/reorders); it is dropped when the item scrolls off, so hoist anything that must
// persist. Shared by both axes: LazyColumn passes its rows, LazyRow its columns — and by
// ReorderableList in cui.controls, which virtualizes its rows the same way.
protected func buildLazyChildren(
    scope: String,
    first: Int64,
    last: Int64,
    key: (Int64) -> String,
    item: (Int64) -> Unit
): Array<(Int64, Widget)> {
    let built = ArrayList<(Int64, Widget)>()
    var index = first
    while (index <= last) {
        let itemIndex = index
        let widget = buildKeyedChild("${scope}:item:${key(itemIndex)}") {=> item(itemIndex)}
        built.add((itemIndex, widget))
        index += 1
    }
    built.toArray()
}

// The effective item-key function: the caller's key, or the index as a string. The index default
// reproduces the historical per-item scope key exactly, so index-keyed lists are byte-for-byte unchanged.
protected func lazyKeyOrIndex(key: ?((Int64) -> String)): (Int64) -> String {
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
 * LazyGrid(photos, 4, 160.0, spacing: 12.0, columnSpacing: 12.0) { photo => photoCell(photo) }
 * ```
 */
public func LazyGrid<T>( // cjcheck-ignore: param-count # public fluent factory: named params with defaults are the rule's own recommended form; a config struct would break the declarative call style
    data: Array<T>,
    columns: Int64,
    itemHeight: Float32,
    spacing!: Float32 = 0.0,
    columnSpacing!: Float32 = 0.0,
    scroll!: ?State<Float32> = None,
    id!: ?String = None,
    item!: (T) -> Unit
): LazyColumn {
    let cols = max(1, columns)
    let count = data.size
    let rowCount = (count + cols - 1) / cols
    LazyColumn(rowCount, itemHeight, spacing: spacing, scroll: scroll, id: id) {
        rowIndex => Grid(cols) {
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

// Collects the focus ids of the currently materialized items, in declaration order —
// shared by the lazy containers, whose Tab ring only contains on-screen rows.
protected func collectLazyFocusableIds(visibleItems: Array<(Int64, Widget)>): Array<String> {
    let ids = ArrayList<String>()
    for (pair in visibleItems) {
        let (_, widget) = pair
        for (fid in widget.focusableIds()) {
            ids.add(fid)
        }
    }
    ids.toArray()
}
