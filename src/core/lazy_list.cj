package cui.core

import sdl.{MouseButton, Rect, Size, UiEvent}

/**
 * A vertically scrolling list of variable-height rows that materializes only the rows near the viewport
 * — the variable-height counterpart of `LazyColumn`. Heights may come from `heightOf(index)`, a mutable
 * `LazyListExtents`, or the self-sizing `LazyList.measured` factory. Rows sized to their own content
 * (chat bubbles, comments, cards with wrapped text) still cost only a screenful to build, lay out and draw.
 *
 * Row offsets live in a Fenwick extent index, so prefix lookup and mutable point updates are O(log N).
 * The compatibility `heightOf` form rescans all heights unless a stable `revision` is supplied; with a
 * revision it rescans only when that revision changes. High-frequency changes should use
 * `LazyListExtents.update`. The measured form retains intrinsic heights as rows enter the viewport and
 * invalidates them when width/font environment changes, removing the application's height bookkeeping.
 * Scroll, stable keys, anchoring, controller and pixel overscan behave as in `LazyColumn`. Versioned,
 * mutable and measured extent forms treat scrolling inside the materialized interval as a layout
 * transform; the compatibility unversioned `heightOf` form still rebuilds so opaque height changes
 * cannot be missed.
 */
public class LazyList <: Widget {
    private let count: Int64
    private let extents: LazyExtentIndex
    private let scrollStateValue: State<Float32>
    private let keyForIndex: (Int64) -> String
    private let viewportMemory: LazyViewportMemory
    private let scrollBar: ScrollBar
    private let overscan: Float32
    private let phaseSplitEnabled: Bool
    private let visibleItems: Array<(Int64, Widget)>
    private let paintOverflow: PaintOutset
    private let materializedFirst: Int64
    private let materializedLast: Int64
    private let builtMaterializationGeneration: UInt64
    private let builtScrollRevision: UInt64
    private var frameScroll: Float32
    private let measuredExtentCache: ?LazyMeasuredExtentCache
    private var frame = Rect.zero()
    private var spatialClip = exactSpatialClip(Rect.zero())

    /**
     * The index form: `count` rows whose heights come from `heightOf(index)`. `id` is the optional
     * container identity (auto-derived by build order when omitted). `key` optionally gives each row a
     * stable identity string (so its per-row state follows the item across inserts/reorders); when
     * omitted, rows are keyed by index. `revision` versions the height/key snapshot; `None` preserves
     * compatibility by rescanning every build. See `LazyList.of` for the data-driven form.
     * Throws `IllegalArgumentException` when an explicit `id` is empty or both `scroll` and
     * `controller` are provided.
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
            controller: controller, overscan: overscan, extentModel: None, measuredHeight: None, item: item)
    }

    /**
     * The mutable-extent form. Point updates through `extents.update` are O(log N), automatically
     * schedule a frame and preserve the top visible stable key. Spacing belongs to the extent model.
     * Throws `IllegalArgumentException` when an explicit `id` is empty or both `scroll` and
     * `controller` are provided.
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
            controller: controller, overscan: overscan, extentModel: Some(extents), measuredHeight: None, item: item)
    }

    /*
     * Shared constructor for all public list forms. It throws `IllegalArgumentException` for the
     * common empty-id and mutually-exclusive scroll-owner preconditions documented above.
     */
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
        measuredHeight!: ?Float32,
        item!: (Int64) -> Unit
    ) {
        let ident = resolveControlKey(id, "LazyList")
        if (scroll.isSome() && controller.isSome()) {
            throw IllegalArgumentException("LazyList accepts either scroll or controller, not both")
        }
        this.count = max(0, count)
        this.overscan = max(0.0, overscan)
        this.phaseSplitEnabled = extentModel.isSome() || measuredHeight.isSome() || revision.isSome()
        this.scrollStateValue = match (controller) {
            case Some(value) => value.state()
            case None => match (scroll) {
                case Some(value) => value
                case None => localState<Float32>("LazyList:${ident}:scroll") {0.0}
            }
        }
        let resolvedKey = lazyKeyOrIndex(key)
        this.keyForIndex = resolvedKey
        this.scrollBar = ScrollBar("LazyList:${ident}:thumb")
        let resolved: (LazyExtentIndex, ?LazyMeasuredExtentCache, UInt64, UInt64) = match (extentModel) {
            case Some(model) =>
                let contentRevision = model.revision()
                (model.currentIndex(), None, contentRevision, model.structuralRevision())
            case None => match (measuredHeight) {
                case Some(estimate) =>
                    let cache = localState<LazyMeasuredExtentCache>("LazyList:${ident}:measuredExtentCache") {
                        LazyMeasuredExtentCache()
                    }.value
                    let contentRevision = match (revision) {
                        case Some(value) => value
                        case None => UInt64(0)
                    }
                    let prepared = cache.prepare(this.count, estimate, max(0.0, spacing), contentRevision, key.isSome(),
                        resolvedKey)
                    (prepared, Some(cache), cache.contentRevision(), cache.structuralRevision())
                case None =>
                    let cache = localState<LazyExtentCache>("LazyList:${ident}:extentCache") {LazyExtentCache()}.value
                    let prepared = cache.prepare(this.count, heightOf, max(0.0, spacing), revision)
                    let contentRevision = match (revision) {
                        case Some(value) => value
                        case None => UInt64(0)
                    }
                    (prepared, None, contentRevision, contentRevision)
            }
        }
        let (resolvedExtents, measurementCache, effectiveRevision, structuralRevision) = resolved
        this.measuredExtentCache = measurementCache
        this.viewportMemory = localState<LazyViewportMemory>("LazyList:${ident}:viewport") {
            LazyViewportMemory(effectiveRevision)
        }.value
        this.builtMaterializationGeneration = if (phaseSplitEnabled) {
            this.viewportMemory.buildMaterializationGeneration()
        } else {
            this.viewportMemory.currentMaterializationGeneration()
        }
        this.extents = resolvedExtents
        let content = resolvedExtents.contentExtent()
        let (scrollSnapshot, scrollRevision) = if (phaseSplitEnabled) {
            this.scrollStateValue.phaseHintValueRevisionSnapshot()
        } else {
            this.scrollStateValue.valueRevisionSnapshot()
        }
        this.builtScrollRevision = scrollRevision
        let current = clampScrollOffset(scrollSnapshot, content, this.viewportMemory.viewportExtent)
        let geometry = LazyItemGeometry(this.count, resolvedKey, {index => resolvedExtents.topOf(index)},
            {index => resolvedExtents.heightAt(index)}, content)
        let anchored = lazyResolveAnchoredScroll(this.viewportMemory, effectiveRevision, structuralRevision, current,
            geometry)
        this.frameScroll = lazyResolveControllerScroll(controller, this.viewportMemory, anchored, geometry)
        let insets = lazyAdaptiveOverscan(this.overscan, this.frameScroll,
            this.viewportMemory.materializationOriginScroll, this.viewportMemory.viewportExtent)
        let (first, last) = resolvedExtents.visibleRange(this.frameScroll, this.viewportMemory.viewportExtent, insets)
        this.materializedFirst = first
        this.materializedLast = last
        this.visibleItems = buildLazyChildren("LazyList:${ident}", first, last, resolvedKey, item)
        this.paintOverflow = aggregateLazyPaintOutsets(visibleItems)
        this.viewportMemory.materializationOriginScroll = this.frameScroll
        emit(this)
    }

    /**
     * Builds index-addressed, self-sizing rows. `estimatedHeight` is used only until a row enters
     * the materialized window; its measured intrinsic height is then retained and updates the
     * Fenwick extent index in O(log N). Increment `revision` after insert/remove/reorder.
     */
    public static func measured( // cjcheck-ignore: param-count # named viewport controls keep the declarative call readable
        count: Int64,
        estimatedHeight!: Float32 = 64.0,
        spacing!: Float32 = 0.0,
        scroll!: ?State<Float32> = None,
        key!: ?((Int64) -> String) = None,
        id!: ?String = None,
        revision!: UInt64 = UInt64(0),
        controller!: ?LazyViewportController = None,
        overscan!: Float32 = LAZY_DEFAULT_OVERSCAN_PIXELS,
        item!: (Int64) -> Unit
    ): LazyList {
        LazyList(count, {_ => max(1.0, estimatedHeight)}, spacing: spacing, scroll: scroll, key: key, id: id,
            revision: Some(revision), controller: controller, overscan: overscan, extentModel: None,
            measuredHeight: Some(estimatedHeight), item: item)
    }

    /** Data-driven self-sizing form; no per-item height model is required. */
    public static func measured<T>( // cjcheck-ignore: param-count # data, identity and viewport options stay named at the use site
        data: Array<T>,
        estimatedHeight!: Float32 = 64.0,
        spacing!: Float32 = 0.0,
        scroll!: ?State<Float32> = None,
        key!: ?((T) -> String) = None,
        id!: ?String = None,
        revision!: UInt64 = UInt64(0),
        controller!: ?LazyViewportController = None,
        overscan!: Float32 = LAZY_DEFAULT_OVERSCAN_PIXELS,
        item!: (T) -> Unit
    ): LazyList {
        let itemKey: ?((Int64) -> String) = match (key) {
            case Some(k) => Some({index => k(data[index])})
            case None => None
        }
        LazyList.measured(data.size, estimatedHeight: estimatedHeight, spacing: spacing, scroll: scroll, key: itemKey,
            id: id, revision: revision, controller: controller, overscan: overscan) {
            index => item(data[index])
        }
    }

    /** Observable-data self-sizing form; State assignments automatically version structure. */
    public static func measured<T>( // cjcheck-ignore: param-count # observable data removes manual revision while retaining named viewport controls
        data: State<Array<T>>,
        estimatedHeight!: Float32 = 64.0,
        spacing!: Float32 = 0.0,
        scroll!: ?State<Float32> = None,
        key!: ?((T) -> String) = None,
        id!: ?String = None,
        controller!: ?LazyViewportController = None,
        overscan!: Float32 = LAZY_DEFAULT_OVERSCAN_PIXELS,
        item!: (T) -> Unit
    ): LazyList {
        let (snapshot, revision) = data.valueRevisionSnapshot()
        LazyList.measured(snapshot, estimatedHeight: estimatedHeight, spacing: spacing, scroll: scroll, key: key, id: id,
            revision: revision, controller: controller, overscan: overscan, item: item)
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

    /** Observable-data height-model form; State assignments automatically version height/key snapshots. */
    public static func of<T>( // cjcheck-ignore: param-count # observable data removes manual revision while retaining named viewport controls
        data: State<Array<T>>,
        heightOf: (T) -> Float32,
        spacing!: Float32 = 0.0,
        scroll!: ?State<Float32> = None,
        key!: ?((T) -> String) = None,
        id!: ?String = None,
        controller!: ?LazyViewportController = None,
        overscan!: Float32 = LAZY_DEFAULT_OVERSCAN_PIXELS,
        item!: (T) -> Unit
    ): LazyList {
        let (snapshot, revision) = data.valueRevisionSnapshot()
        LazyList.of(snapshot, heightOf, spacing: spacing, scroll: scroll, key: key, id: id, revision: Some(revision),
            controller: controller, overscan: overscan, item: item)
    }

    /**
     * Data-driven mutable-extent form; `data.size` must match `extents.count`.
     * Throws `IllegalArgumentException` when the counts differ, an explicit `id` is empty, or both
     * `scroll` and `controller` are provided.
     */
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
        spatialClip = verticalViewportSpatialClip(rect, paintOverflow)
        viewportMemory.viewportExtent = rect.h
        let content = extents.contentExtent()
        let (requestedScroll, scrollRevision) = scrollStateValue.valueRevisionSnapshot()
        if (scrollRevision != builtScrollRevision) {
            frameScroll = clampScrollOffset(requestedScroll, content, rect.h)
        }
        if (lazyFloatChanged(frameScroll, requestedScroll)) {
            scrollStateValue.value = frameScroll
        }
        let contentWidth = if (content > rect.h) {
            max(0.0, rect.w - scrollBarGutter())
        } else {
            rect.w
        }
        if (updateMeasuredExtents(ctx, contentWidth)) {
            correctMeasuredScroll()
        }
        ctx.withSpatialClip(spatialClip) {
            => for (pair in visibleItems) {
                let (index, widget) = pair
                let y = rect.y - frameScroll + extents.topOf(index)
                widget.layout(ctx, Rect(rect.x, y, contentWidth, extents.heightAt(index)))
            }
        }
        if (measuredExtentCache.isNone()) {
            lazyRememberAnchor(viewportMemory, frameScroll, count, {offset => extents.rowAt(offset)}, keyForIndex,
                {index => extents.topOf(index)})
        }
        requestMaterializationIfNeeded(rect.h)
    }

    private func requestMaterializationIfNeeded(viewportExtent: Float32): Unit {
        if (!phaseSplitEnabled || builtMaterializationGeneration != viewportMemory.currentMaterializationGeneration()) {
            return
        }
        let insets = lazyAdaptiveOverscan(overscan, frameScroll, viewportMemory.materializationOriginScroll,
            viewportExtent)
        let (desiredFirst, desiredLast) = extents.visibleRange(frameScroll, viewportExtent, insets)
        if (desiredFirst < materializedFirst || desiredLast > materializedLast) {
            viewportMemory.requestMaterialization()
        }
    }

    private func updateMeasuredExtents(ctx: UiContext, contentWidth: Float32): Bool {
        match (measuredExtentCache) {
            case Some(cache) =>
                // Capture the top key against the committed geometry. Visible measurements may
                // change prefixes below; recording afterward could silently switch the anchor.
                lazyRememberAnchor(viewportMemory, frameScroll, count, {offset => extents.rowAt(offset)}, keyForIndex,
                    {index => extents.topOf(index)})
                let measurements = Array<(Int64, String, Float32)>(
                    visibleItems.size,
                    {
                        position =>
                            let (index, widget) = visibleItems[position]
                            (index, keyForIndex(index), widget.measure(ctx, Size(contentWidth, LAYOUT_UNBOUNDED)).h)
                    }
                )
                cache.commitMeasurements(contentWidth, ctx.uiEnvironmentKey(), measurements)
            case None => false
        }
    }

    private func correctMeasuredScroll(): Unit {
        let geometry = LazyItemGeometry(count, keyForIndex, {index => extents.topOf(index)},
            {index => extents.heightAt(index)}, extents.contentExtent())
        let corrected = lazyResolveMeasuredAnchor(viewportMemory, frameScroll, geometry)
        if (lazyFloatChanged(corrected, scrollStateValue.value)) {
            scrollStateValue.value = corrected
        }
    }

    public func draw(ctx: UiContext): Unit {
        let content = extents.contentExtent()
        // Exact on the scroll axis; cross-axis overflow comes from visible widget declarations.
        ctx.drawWithinSpatialClip(spatialClip) {
            => for (pair in visibleItems) {
                let (index, widget) = pair
                // Clip each row to its declared paint bounds, intersected with the viewport.
                let rowRect = Rect(frame.x, frame.y - frameScroll + extents.topOf(index), frame.w,
                    extents.heightAt(index))
                ctx.drawWithinSpatialClip(exactSpatialClip(widget.paintOutset().expand(rowRect))) {
                    => widget.draw(ctx)
                }
            }
        }
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
                if (!spatialClip.contains(pointerX, pointerY)) {
                    return false
                }
                if (dispatchLazyVisibleItems(visibleItems, ctx, event)) {
                    return true
                }
                return scrollByWheel(scrollStateValue, wheelY, content, viewportH)
            case UiEvent.MouseDown(button, x, y) =>
                let primary = match (button) {
                    case MouseButton.Left => true;
                    case _ => false
                }
                if (primary && scrollBar.press(ctx, frame, scrollStateValue, content, viewportH, x, y)) {
                    return true
                }
                if (!spatialClip.contains(x, y)) {
                    return false
                }
            case UiEvent.MouseMove(x, y) =>
                if (scrollBar.drag(ctx, frame, scrollStateValue, content, viewportH, y)) {
                    return true
                }
                if (!spatialClip.contains(x, y) && ctx.dragId.isEmpty()) {
                    return false
                }
            case UiEvent.MouseUp(_, x, y) =>
                if (!spatialClip.contains(x, y) && ctx.dragId.isEmpty()) {
                    return false
                }
            case _ => ()
        }
        dispatchLazyVisibleItems(visibleItems, ctx, event)
    }

    public func isFlexible(): Bool {
        true
    }

    public func focusableIds(): Array<String> {
        collectLazyFocusableIds(visibleItems)
    }

    public func paintOutset(): PaintOutset {
        paintOverflow.horizontalOnly()
    }
}
