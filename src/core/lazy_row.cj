package cui.core

import std.collection.ArrayList
import sdl.{Rect, Size, UiEvent}

/**
 * A horizontally scrolling list that materializes only the columns near the viewport — the horizontal
 * counterpart of `LazyColumn`. Items have a fixed width (in logical pixels) and are built on demand by
 * index, so build, layout and draw are all O(visible) rather than O(count): a filmstrip of thousands of
 * arbitrary item widgets scrolls at the cost of a screenful.
 *
 * Because only visible items are built, per-item local state (`rememberState` / `Keyed`) lives only
 * while an item is on screen and is dropped when it scrolls off; hoist any state that must outlive
 * scrolling into the application model. The scroll offset may be owned externally (via `scroll`) for
 * coordination or animation. The `id` scopes the retained scroll and per-item state, like other
 * scrollable controls. The mouse wheel scrolls it horizontally; a bar rides the bottom edge on overflow.
 */
public class LazyRow <: Widget {
    private let id: String
    private let count: Int64
    private let itemWidth: Float32
    private let spacing: Float32
    private let scrollStateValue: State<Float32>
    private let viewportWidthState: State<Float32>
    private let scrollBar: HScrollBar
    // Columns materialized this frame, each paired with its absolute index for positioning and events.
    private let visibleItems: Array<(Int64, Widget)>
    // The scroll offset snapshotted for the whole frame so build, layout and draw agree.
    private let frameScroll: Float32
    private var frame = Rect.zero()

    /**
     * The index form: `count` columns built on demand by index. `id` is the optional container identity
     * (auto-derived by build order when omitted; an explicit one must be non-empty). Item width is in
     * logical pixels. `key` optionally gives each item a stable identity string (so its per-item state
     * follows the item across inserts/reorders); when omitted, items are keyed by index — see
     * `LazyRow.of` for the data-driven form.
     */
    public init(
        count: Int64,
        itemWidth: Float32,
        spacing!: Float32 = 0.0,
        scroll!: ?State<Float32> = None,
        key!: ?((Int64) -> String) = None,
        id!: ?String = None,
        item!: (Int64) -> Unit
    ) {
        let ident = resolveControlKey(id, "LazyRow")
        this.id = ident
        this.count = max(0, count)
        this.itemWidth = max(1.0, itemWidth)
        this.spacing = max(0.0, spacing)
        this.scrollStateValue = match (scroll) {
            case Some(value) => value
            case None => localState<Float32>("LazyRow:${ident}:scroll") {0.0}
        }
        // Retained so the build pass (which has no layout rect yet) knows how wide the viewport was
        // last frame and thus which columns to materialize; layout updates it for the next frame.
        this.viewportWidthState = localState<Float32>("LazyRow:${ident}:viewportW") {LAZY_DEFAULT_VIEWPORT}
        this.scrollBar = HScrollBar("LazyRow:${ident}:thumb")
        // lazyContentHeight computes count*(item+spacing)-spacing along any axis; here it is the width.
        let content = lazyContentHeight(this.count, this.itemWidth, this.spacing)
        this.frameScroll = clampScrollOffset(this.scrollStateValue.value, content, this.viewportWidthState.value)
        let (first, last) = lazyVisibleRange(this.frameScroll, this.viewportWidthState.value, this.itemWidth,
            this.spacing, this.count, LAZY_OVERSCAN)
        this.visibleItems = buildLazyChildren("LazyRow:${ident}", first, last, lazyKeyOrIndex(key), item)
        emit(this)
    }

    /**
     * The data-driven form: builds a virtualized row from `data` and a per-item builder, so a filmstrip
     * of arbitrary item widgets over an `Array<T>` needs neither a manual `count` nor an index-into-data
     * lookup. `key` gives each item a stable identity; omit it to key by index. `itemWidth` is the fixed
     * column width in logical pixels, as for the index form.
     *
     * ```
     * LazyRow.of(model.photos, 160.0, key: {p => p.id}) { photo => photoCard(photo) }
     * ```
     */
    public static func of<T>(
        data: Array<T>,
        itemWidth: Float32,
        spacing!: Float32 = 0.0,
        scroll!: ?State<Float32> = None,
        key!: ?((T) -> String) = None,
        id!: ?String = None,
        item!: (T) -> Unit
    ): LazyRow {
        let itemKey: ?((Int64) -> String) = match (key) {
            case Some(k) => Some({index => k(data[index])})
            case None => None
        }
        LazyRow(data.size, itemWidth, spacing: spacing, scroll: scroll, key: itemKey, id: id) {
            index => item(data[index])
        }
    }

    public func measure(_: UiContext, available: Size): Size {
        Size(available.w, available.h)
    }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        frame = rect
        // Record the viewport width for the next frame's build; write-on-change to avoid churn.
        let _ = viewportWidthState.setIfChanged(rect.w)
        let content = lazyContentHeight(count, itemWidth, spacing)
        // Correct the live offset for the next frame in case the content shrank.
        let clamped = clampScrollOffset(scrollStateValue.value, content, rect.w)
        if (clamped != scrollStateValue.value) {
            scrollStateValue.value = clamped
        }
        let stride = itemWidth + spacing
        // Reserve the bottom bar lane once the columns overflow, so the bar never covers item content.
        let contentHeight = if (content > rect.w) {
            max(0.0, rect.h - scrollBarGutter())
        } else {
            rect.h
        }
        for (pair in visibleItems) {
            let (index, widget) = pair
            let x = rect.x - frameScroll + Float32(index) * stride
            widget.layout(ctx, Rect(x, rect.y, itemWidth, contentHeight))
        }
    }

    public func draw(ctx: UiContext): Unit {
        let content = lazyContentHeight(count, itemWidth, spacing)
        let stride = itemWidth + spacing
        // Exact on the scroll axis, shadow clearance on the cross axis (see CUI_SHADOW_CLEARANCE).
        ctx.renderer.pushClip(Rect(frame.x, frame.y - CUI_SHADOW_CLEARANCE, frame.w,
            frame.h + 2.0 * CUI_SHADOW_CLEARANCE))
        for (pair in visibleItems) {
            let (index, widget) = pair
            // Clip each column to its own bounds plus shadow clearance, so a card column's soft halo
            // wraps its corners; an item wider than the cleared bounds is still truncated rather than
            // bleeding far over its neighbour (and the strip's own clip bounds the scroll axis).
            let colRect = Rect(frame.x - frameScroll + Float32(index) * stride, frame.y, itemWidth, frame.h)
            ctx.renderer.pushClip(colRect.inset(-CUI_SHADOW_CLEARANCE))
            widget.draw(ctx)
            ctx.renderer.popClip()
        }
        ctx.renderer.popClip()
        drawHorizontalScrollBar(ctx, frame, frameScroll, content, frame.w, active: scrollBar.dragging(ctx))
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        let content = lazyContentHeight(count, itemWidth, spacing)
        let viewportW = frame.w
        match (event) {
            case UiEvent.Frame(_) =>
                for (pair in visibleItems) {
                    let (_, widget) = pair
                    let _ = widget.handle(ctx, event)
                }
                return false
            case UiEvent.MouseWheel(wheelX, wheelY, pointerX, pointerY) =>
                // The wheel scrolls the strip along its axis. A horizontal delta (trackpad pan, tilt
                // wheel) drives it directly; otherwise the vertical wheel is remapped so a plain mouse
                // scrolls too — wheel toward the user (scroll down) advances the strip right.
                if (frame.contains(pointerX, pointerY)) {
                    let delta = if (wheelX != 0.0) {
                        -wheelX
                    } else {
                        wheelY
                    }
                    scrollStateValue.value = scrollOffsetAfterWheel(scrollStateValue.value, delta, content, viewportW)
                    return true
                }
            case UiEvent.MouseDown(_, x, y) =>
                if (scrollBar.press(ctx, frame, scrollStateValue, content, viewportW, x, y)) {
                    return true
                }
                if (!frame.contains(x, y)) {
                    return false
                }
            case UiEvent.MouseMove(x, y) =>
                if (scrollBar.drag(ctx, frame, scrollStateValue, content, viewportW, x)) {
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
        // Route to the materialized columns, right-most first, so an item consumes its own clicks.
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
