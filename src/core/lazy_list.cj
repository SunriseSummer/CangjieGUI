package cui.core

import sdl.{Rect, Size, UiEvent}

/**
 * A vertically scrolling list of variable-height rows that materializes only the rows near the viewport
 * — the variable-height counterpart of `LazyColumn`. Each row's height is supplied by `heightOf(index)`,
 * so rows sized to their own content (chat bubbles, comments, cards with wrapped text) still cost only a
 * screenful to build, lay out and draw.
 *
 * Row offsets live in a Fenwick extent index, so prefix lookup and mutable point updates are O(log N).
 * The compatibility `heightOf` form rescans all heights unless a stable `revision` is supplied; with a
 * revision it rescans only when that revision changes. High-frequency changes should use
 * `LazyListExtents.update`. Heights must be stored/estimated values rather than fresh text measurement
 * and must match the drawn slot. Scroll, stable keys, anchoring, controller and pixel overscan behave
 * as in `LazyColumn`.
 */
public class LazyList <: Widget {
    private let count: Int64
    private let extents: LazyExtentIndex
    private let scrollStateValue: State<Float32>
    private let keyForIndex: (Int64) -> String
    private let viewportMemory: LazyViewportMemory
    private let scrollBar: ScrollBar
    private let visibleItems: Array<(Int64, Widget)>
    private let frameScroll: Float32
    private var frame = Rect.zero()

    /**
     * The index form: `count` rows whose heights come from `heightOf(index)`. `id` is the optional
     * container identity (auto-derived by build order when omitted). `key` optionally gives each row a
     * stable identity string (so its per-row state follows the item across inserts/reorders); when
     * omitted, rows are keyed by index. `revision` versions the height/key snapshot; `None` preserves
     * compatibility by rescanning every build. See `LazyList.of` for the data-driven form.
     */
    public init(
        count: Int64,
        heightOf: (Int64) -> Float32,
        spacing!: Float32 = 0.0,
        scroll!: ?State<Float32> = None,
        key!: ?((Int64) -> String) = None,
        id!: ?String = None,
        revision!: ?UInt64 = None,
        controller!: ?LazyViewportController = None,
        overscan!: Float32 = LAZY_DEFAULT_OVERSCAN_PIXELS,
        item!: (Int64) -> Unit
    ) {
        this(count, heightOf, spacing: spacing, scroll: scroll, key: key, id: id, revision: revision,
            controller: controller, overscan: overscan, extentModel: None, item: item)
    }

    /**
     * The mutable-extent form. Point updates through `extents.update` are O(log N), automatically
     * schedule a frame and preserve the top visible stable key. Spacing belongs to the extent model.
     */
    public init(
        extents: LazyListExtents,
        scroll!: ?State<Float32> = None,
        key!: ?((Int64) -> String) = None,
        id!: ?String = None,
        controller!: ?LazyViewportController = None,
        overscan!: Float32 = LAZY_DEFAULT_OVERSCAN_PIXELS,
        item!: (Int64) -> Unit
    ) {
        this(extents.count, {row => extents.heightAt(row)}, scroll: scroll, key: key, id: id, revision: None,
            controller: controller, overscan: overscan, extentModel: Some(extents), item: item)
    }

    private init(
        count: Int64,
        heightOf: (Int64) -> Float32,
        spacing!: Float32 = 0.0,
        scroll!: ?State<Float32> = None,
        key!: ?((Int64) -> String) = None,
        id!: ?String = None,
        revision!: ?UInt64 = None,
        controller!: ?LazyViewportController = None,
        overscan!: Float32 = LAZY_DEFAULT_OVERSCAN_PIXELS,
        extentModel!: ?LazyListExtents,
        item!: (Int64) -> Unit
    ) {
        let ident = resolveControlKey(id, "LazyList")
        if (scroll.isSome() && controller.isSome()) {
            throw IllegalArgumentException("LazyList accepts either scroll or controller, not both")
        }
        this.count = max(0, count)
        this.scrollStateValue = match (controller) {
            case Some(value) => value.state()
            case None => match (scroll) {
                case Some(value) => value
                case None => localState<Float32>("LazyList:${ident}:scroll") {0.0}
            }
        }
        let resolvedKey = lazyKeyOrIndex(key)
        this.keyForIndex = resolvedKey
        let effectiveRevision = match (extentModel) {
            case Some(model) => model.revision()
            case None => match (revision) {
                case Some(value) => value
                case None => UInt64(0)
            }
        }
        let structuralRevision = match (extentModel) {
            case Some(model) => model.structuralRevision()
            case None => effectiveRevision
        }
        this.viewportMemory = localState<LazyViewportMemory>("LazyList:${ident}:viewport") {
            LazyViewportMemory(effectiveRevision)
        }.value
        this.scrollBar = ScrollBar("LazyList:${ident}:thumb")
        let resolvedExtents = match (extentModel) {
            case Some(model) => model.currentIndex()
            case None =>
                let cache = localState<LazyExtentCache>("LazyList:${ident}:extentCache") {LazyExtentCache()}.value
                cache.prepare(this.count, heightOf, max(0.0, spacing), revision)
        }
        this.extents = resolvedExtents
        let content = resolvedExtents.contentExtent()
        let current = clampScrollOffset(this.scrollStateValue.value, content, this.viewportMemory.viewportExtent)
        let geometry = LazyItemGeometry(this.count, resolvedKey, {index => resolvedExtents.topOf(index)},
            {index => resolvedExtents.heightAt(index)}, content)
        let anchored = lazyResolveAnchoredScroll(this.viewportMemory, effectiveRevision, structuralRevision, current,
            geometry)
        this.frameScroll = lazyResolveControllerScroll(controller, this.viewportMemory, anchored, geometry)
        let insets = lazyAdaptiveOverscan(overscan, this.frameScroll, this.viewportMemory.previousScroll,
            this.viewportMemory.viewportExtent)
        let (first, last) = resolvedExtents.visibleRange(this.frameScroll, this.viewportMemory.viewportExtent, insets)
        this.visibleItems = buildLazyChildren("LazyList:${ident}", first, last, resolvedKey, item)
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
    public static func of<T>( // cjcheck-ignore: param-count # declarative factory keeps named optional controls at the call site; a config wrapper would add ceremony
        data: Array<T>,
        heightOf: (T) -> Float32,
        spacing!: Float32 = 0.0,
        scroll!: ?State<Float32> = None,
        key!: ?((T) -> String) = None,
        id!: ?String = None,
        revision!: ?UInt64 = None,
        controller!: ?LazyViewportController = None,
        overscan!: Float32 = LAZY_DEFAULT_OVERSCAN_PIXELS,
        item!: (T) -> Unit
    ): LazyList {
        let itemKey: ?((Int64) -> String) = match (key) {
            case Some(k) => Some({index => k(data[index])})
            case None => None
        }
        LazyList(data.size, {index => heightOf(data[index])}, spacing: spacing, scroll: scroll, key: itemKey, id: id,
            revision: revision, controller: controller, overscan: overscan) {
            index => item(data[index])
        }
    }

    /** Data-driven mutable-extent form; `data.size` must match `extents.count`. */
    public static func ofExtents<T>( // cjcheck-ignore: param-count # declarative factory uses named optional controls; a config object would make the common call less legible
        data: Array<T>,
        extents: LazyListExtents,
        scroll!: ?State<Float32> = None,
        key!: ?((T) -> String) = None,
        id!: ?String = None,
        controller!: ?LazyViewportController = None,
        overscan!: Float32 = LAZY_DEFAULT_OVERSCAN_PIXELS,
        item!: (T) -> Unit
    ): LazyList {
        if (data.size != extents.count) {
            throw IllegalArgumentException("LazyList data and extent counts must match")
        }
        let itemKey: ?((Int64) -> String) = match (key) {
            case Some(k) => Some({index => k(data[index])})
            case None => None
        }
        LazyList(extents, scroll: scroll, key: itemKey, id: id, controller: controller, overscan: overscan) {
            index => item(data[index])
        }
    }

    public func measure(_: UiContext, available: Size): Size {
        Size(available.w, available.h)
    }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        frame = rect
        viewportMemory.viewportExtent = rect.h
        let content = extents.contentExtent()
        if (lazyFloatChanged(frameScroll, scrollStateValue.value)) {
            scrollStateValue.value = frameScroll
        }
        let contentWidth = if (content > rect.h) {
            max(0.0, rect.w - scrollBarGutter())
        } else {
            rect.w
        }
        for (pair in visibleItems) {
            let (index, widget) = pair
            let y = rect.y - frameScroll + extents.topOf(index)
            widget.layout(ctx, Rect(rect.x, y, contentWidth, extents.heightAt(index)))
        }
        lazyRememberAnchor(viewportMemory, frameScroll, count, {offset => extents.rowAt(offset)}, keyForIndex,
            {index => extents.topOf(index)})
    }

    public func draw(ctx: UiContext): Unit {
        let content = extents.contentExtent()
        // Exact on the scroll axis, shadow clearance on the cross axis (see CUI_SHADOW_CLEARANCE).
        ctx.renderer.pushClip(Rect(frame.x - CUI_SHADOW_CLEARANCE, frame.y, frame.w + 2.0 * CUI_SHADOW_CLEARANCE,
            frame.h))
        for (pair in visibleItems) {
            let (index, widget) = pair
            // Row clip widened by the shadow clearance so a card row's halo stays rounded; gross
            // overflow beyond the clearance is still truncated (intersected with the viewport).
            let rowRect = Rect(frame.x, frame.y - frameScroll + extents.topOf(index), frame.w, extents.heightAt(index))
            ctx.renderer.pushClip(rowRect.inset(-CUI_SHADOW_CLEARANCE))
            widget.draw(ctx)
            ctx.renderer.popClip()
        }
        ctx.renderer.popClip()
        drawVerticalScrollBar(ctx, frame, frameScroll, content, frame.h, active: scrollBar.dragging(ctx))
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        let content = extents.contentExtent()
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
        collectLazyFocusableIds(visibleItems)
    }
}
