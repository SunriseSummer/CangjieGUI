package cui.core

import std.collection.ArrayList
import sdl.{Rect, Size, UiEvent}

/**
 * A vertically scrolling list of variable-height rows that materializes only the rows near the viewport
 * — the variable-height counterpart of `LazyColumn`. Each row's height is supplied by `heightOf(index)`,
 * so rows sized to their own content (chat bubbles, comments, cards with wrapped text) still cost only a
 * screenful to build, lay out and draw.
 *
 * Row offsets are a running sum of the heights, and the visible window is found by binary search over
 * them, so only the visible rows are built while the offset pass is a cheap walk of the height values.
 * `heightOf` must therefore be O(1) — a stored or estimated height, not a fresh text measurement — and
 * must match the height the row actually draws to, or rows would overlap or leave gaps. The scroll
 * offset, `key` and `id` behave as in `LazyColumn`.
 */
public class LazyList <: Widget {
    private let id: String
    private let count: Int64
    private let heightOf: (Int64) -> Float32
    private let scrollStateValue: State<Float32>
    private let viewportHeightState: State<Float32>
    private let scrollBar: ScrollBar
    // Running row tops: rowTops[i] is the top of row i in content space; rowTops[count] is the total
    // content height (spacing sits only between rows, not after the last).
    private let rowTops: Array<Float32>
    private let visibleItems: Array<(Int64, Widget)>
    private let frameScroll: Float32
    private var frame = Rect.zero()

    /**
     * The index form: `count` rows whose heights come from `heightOf(index)`. `id` is the optional
     * container identity (auto-derived by build order when omitted). `key` optionally gives each row a
     * stable identity string (so its per-row state follows the item across inserts/reorders); when
     * omitted, rows are keyed by index — see `LazyList.of` for the data-driven form.
     */
    public init(
        count: Int64,
        heightOf: (Int64) -> Float32,
        spacing!: Float32 = 0.0,
        scroll!: ?State<Float32> = None,
        key!: ?((Int64) -> String) = None,
        id!: ?String = None,
        item!: (Int64) -> Unit
    ) {
        let ident = resolveControlKey(id, "LazyList")
        this.id = ident
        this.count = max(0, count)
        this.heightOf = heightOf
        this.scrollStateValue = match (scroll) {
            case Some(value) => value
            case None => localState<Float32>("LazyList:${ident}:scroll") {0.0}
        }
        this.viewportHeightState = localState<Float32>("LazyList:${ident}:viewportH") {LAZY_DEFAULT_VIEWPORT}
        this.scrollBar = ScrollBar("LazyList:${ident}:thumb")
        this.rowTops = lazyListRowTops(this.count, heightOf, max(0.0, spacing))
        let content = this.rowTops[this.count]
        this.frameScroll = clampScrollOffset(this.scrollStateValue.value, content, this.viewportHeightState.value)
        let (first, last) = lazyListVisibleRange(this.rowTops, this.frameScroll, this.viewportHeightState.value,
            LAZY_OVERSCAN)
        this.visibleItems = buildLazyChildren("LazyList:${ident}", first, last, lazyKeyOrIndex(key), item)
        emit(this)
    }

    /**
     * The data-driven form: builds a variable-height list from `data`, a per-item height extractor and a
     * per-item builder. `heightOf` must be O(1) (a stored or precomputed height).
     *
     * ```
     * LazyList.of(model.messages, {m => m.height}, key: {m => m.id}) { msg => bubble(msg) }
     * ```
     */
    public static func of<T>(
        data: Array<T>,
        heightOf: (T) -> Float32,
        spacing!: Float32 = 0.0,
        scroll!: ?State<Float32> = None,
        key!: ?((T) -> String) = None,
        id!: ?String = None,
        item!: (T) -> Unit
    ): LazyList {
        let itemKey: ?((Int64) -> String) = match (key) {
            case Some(k) => Some({index => k(data[index])})
            case None => None
        }
        LazyList(data.size, {index => heightOf(data[index])}, spacing: spacing, scroll: scroll, key: itemKey, id: id) {
            index => item(data[index])
        }
    }

    public func measure(_: UiContext, available: Size): Size {
        Size(available.w, available.h)
    }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        frame = rect
        let _ = viewportHeightState.setIfChanged(rect.h)
        let content = rowTops[count]
        let clamped = clampScrollOffset(scrollStateValue.value, content, rect.h)
        if (clamped != scrollStateValue.value) {
            scrollStateValue.value = clamped
        }
        let contentWidth = if (content > rect.h) {
            max(0.0, rect.w - scrollBarGutter())
        } else {
            rect.w
        }
        for (pair in visibleItems) {
            let (index, widget) = pair
            let y = rect.y - frameScroll + rowTops[index]
            widget.layout(ctx, Rect(rect.x, y, contentWidth, max(0.0, heightOf(index))))
        }
    }

    public func draw(ctx: UiContext): Unit {
        let content = rowTops[count]
        ctx.renderer.pushClip(frame)
        for (pair in visibleItems) {
            let (index, widget) = pair
            let rowRect = Rect(frame.x, frame.y - frameScroll + rowTops[index], frame.w, max(0.0, heightOf(index)))
            ctx.renderer.pushClip(rowRect)
            widget.draw(ctx)
            ctx.renderer.popClip()
        }
        ctx.renderer.popClip()
        drawVerticalScrollBar(ctx, frame, frameScroll, content, frame.h, active: scrollBar.dragging(ctx))
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        let content = rowTops[count]
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
                if (!frame.contains(x, y) && ctx.dragId.isEmpty()) {
                    return false
                }
            case UiEvent.MouseUp(_, x, y) =>
                if (!frame.contains(x, y) && ctx.dragId.isEmpty()) {
                    return false
                }
            case _ => ()
        }
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

/*
 * The running row tops for `count` rows of the given heights and inter-row `spacing`: entry i is the top
 * of row i in content space, and the final entry (index count) is the total content height. Spacing sits
 * only between rows, never after the last, so the total matches what the rows actually occupy.
 */
internal func lazyListRowTops(count: Int64, heightOf: (Int64) -> Float32, spacing: Float32): Array<Float32> {
    let tops = Array<Float32>(count + 1, {_ => Float32(0.0)})
    var acc: Float32 = 0.0
    for (i in 0..count) {
        tops[i] = acc
        acc += max(0.0, heightOf(i))
        if (i < count - 1) {
            acc += spacing
        }
    }
    tops[count] = acc
    tops
}

/*
 * The inclusive [first, last] row range visible for a viewport at `scroll`, widened by `overscan` rows
 * each side. `tops` is the running-tops array (length count+1). Returns an empty range (first > last)
 * when there is nothing to show.
 */
internal func lazyListVisibleRange(
    tops: Array<Float32>,
    scroll: Float32,
    viewportH: Float32,
    overscan: Int64
): (Int64, Int64) {
    let count = tops.size - 1
    if (count <= 0) {
        return (0, -1)
    }
    let top = max(0.0, scroll)
    let bottom = top + max(0.0, viewportH)
    var first = lazyListLastRowAtOrBefore(tops, top, count)
    if (first < 0) {
        first = 0
    }
    var last = lazyListLastRowAtOrBefore(tops, bottom, count)
    if (last < 0) {
        last = 0
    }
    first = max(0, first - overscan)
    last = min(count - 1, last + overscan)
    (first, last)
}

// Largest row index in [0, count-1] whose top is at or before `value`, by binary search; -1 if none.
private func lazyListLastRowAtOrBefore(tops: Array<Float32>, value: Float32, count: Int64): Int64 {
    var lo = 0
    var hi = count - 1
    var answer = -1
    while (lo <= hi) {
        let mid = (lo + hi) / 2
        if (tops[mid] <= value) {
            answer = mid
            lo = mid + 1
        } else {
            hi = mid - 1
        }
    }
    answer
}
