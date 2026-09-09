package cui.core

import sdl.{MouseButton, Rect, Size, UiEvent}

/**
 * A horizontally scrolling list that materializes only the columns near the viewport — the horizontal
 * counterpart of `LazyColumn`. Items have a fixed width (in logical pixels) and are built on demand by
 * index, so build, layout and draw are all O(visible) rather than O(count): a filmstrip of thousands of
 * arbitrary item widgets scrolls at the cost of a screenful.
 *
 * Because only visible items are built, per-item local state (`rememberState` / `Keyed`) lives only
 * while an item is on screen and is dropped when it scrolls off; hoist any state that must outlive
 * scrolling into the application model. The scroll offset may be owned externally (via `scroll`) or a
 * `LazyViewportController`; stable-key anchoring and adaptive pixel overscan match `LazyColumn`. The
 * mouse wheel scrolls it horizontally; a bar rides the bottom edge on overflow. Scrolling inside
 * the materialized interval is a layout/paint transform; crossing its boundary schedules one
 * stabilization rebuild.
 */
public class LazyRow <: Widget {
    private let count: Int64
    private let itemWidth: Float32
    private let spacing: Float32
    private let scrollStateValue: State<Float32>
    private let keyForIndex: (Int64) -> String
    private let viewportMemory: LazyViewportMemory
    private let scrollBar: HScrollBar
    private let overscan: Float32
    // Columns materialized this frame, each paired with its absolute index for positioning and events.
    private let visibleItems: Array<(Int64, Widget)>
    private let paintOverflow: PaintOutset
    private let materializedFirst: Int64
    private let materializedLast: Int64
    private let builtMaterializationGeneration: UInt64
    private let builtScrollRevision: UInt64
    // Layout updates the live transform; draw and events consume the same committed value.
    private var frameScroll: Float32
    private var frame = Rect.zero()
    private var spatialClip = exactSpatialClip(Rect.zero())

    /**
     * The index form: `count` columns built on demand by index. `id` is the optional container identity
     * (auto-derived by build order when omitted; an explicit one must be non-empty). Item width is in
     * logical pixels. `key` optionally gives each item a stable identity string (so its per-item state
     * follows the item across inserts/reorders); when omitted, items are keyed by index — see
     * `LazyRow.of` for the data-driven form.
     * Throws `IllegalArgumentException` when an explicit `id` is empty or both `scroll` and
     * `controller` are provided.
     */
    public init(
        count: Int64,
        itemWidth: Float32,
        spacing!: Float32 = 0.0,
        scroll!: ?State<Float32> = None,
        key!: ?((Int64) -> String) = None,
        id!: ?String = None,
        revision!: UInt64 = UInt64(0),
        controller!: ?LazyViewportController = None,
        overscan!: Float32 = LAZY_DEFAULT_OVERSCAN_PIXELS,
        item!: (Int64) -> Unit
    ) {
        let ident = resolveControlKey(id, "LazyRow")
        let resolvedItemWidth = max(1.0, itemWidth)
        let resolvedSpacing = max(0.0, spacing)
        this.count = max(0, count)
        this.itemWidth = resolvedItemWidth
        this.spacing = resolvedSpacing
        this.overscan = max(0.0, overscan)
        if (scroll.isSome() && controller.isSome()) {
            throw IllegalArgumentException("LazyRow accepts either scroll or controller, not both")
        }
        this.scrollStateValue = match (controller) {
            case Some(value) => value.state()
            case None => match (scroll) {
                case Some(value) => value
                case None => localState<Float32>("LazyRow:${ident}:scroll") {0.0}
            }
        }
        let resolvedKey = lazyKeyOrIndex(key)
        this.keyForIndex = resolvedKey
        this.viewportMemory = localState<LazyViewportMemory>("LazyRow:${ident}:viewport") {
            LazyViewportMemory(revision)
        }.value
        this.builtMaterializationGeneration = this.viewportMemory.buildMaterializationGeneration()
        this.scrollBar = HScrollBar("LazyRow:${ident}:thumb")
        // lazyContentHeight computes count*(item+spacing)-spacing along any axis; here it is the width.
        let content = lazyContentHeight(this.count, resolvedItemWidth, resolvedSpacing)
        let (scrollSnapshot, scrollRevision) = this.scrollStateValue.phaseHintValueRevisionSnapshot()
        this.builtScrollRevision = scrollRevision
        let current = clampScrollOffset(scrollSnapshot, content, this.viewportMemory.viewportExtent)
        let geometry = LazyItemGeometry(this.count, resolvedKey,
            {index => lazyFixedItemTop(index, resolvedItemWidth, resolvedSpacing)}, {_ => resolvedItemWidth}, content)
        let anchored = lazyResolveAnchoredScroll(this.viewportMemory, revision, revision, current, geometry)
        this.frameScroll = lazyResolveControllerScroll(controller, this.viewportMemory, anchored, geometry)
        let insets = lazyAdaptiveOverscan(this.overscan, this.frameScroll,
            this.viewportMemory.materializationOriginScroll, this.viewportMemory.viewportExtent)
        let (first, last) = lazyFixedVisibleRange(this.frameScroll, this.viewportMemory.viewportExtent,
            resolvedItemWidth, resolvedSpacing, this.count, insets)
        this.materializedFirst = first
        this.materializedLast = last
        this.visibleItems = buildLazyChildren("LazyRow:${ident}", first, last, resolvedKey, item)
        this.paintOverflow = aggregateLazyPaintOutsets(visibleItems)
        this.viewportMemory.materializationOriginScroll = this.frameScroll
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
    public static func of<T>( // cjcheck-ignore: param-count # declarative factory keeps named optional controls at the call site; a config wrapper would add ceremony
        data: Array<T>,
        itemWidth: Float32,
        spacing!: Float32 = 0.0,
        scroll!: ?State<Float32> = None,
        key!: ?((T) -> String) = None,
        id!: ?String = None,
        revision!: UInt64 = UInt64(0),
        controller!: ?LazyViewportController = None,
        overscan!: Float32 = LAZY_DEFAULT_OVERSCAN_PIXELS,
        item!: (T) -> Unit
    ): LazyRow {
        let itemKey: ?((Int64) -> String) = match (key) {
            case Some(k) => Some({index => k(data[index])})
            case None => None
        }
        LazyRow(data.size, itemWidth, spacing: spacing, scroll: scroll, key: itemKey, id: id, revision: revision,
            controller: controller, overscan: overscan) {
            index => item(data[index])
        }
    }

    /** Observable-data form with automatic State-revision anchoring across structural changes. */
    public static func of<T>( // cjcheck-ignore: param-count # observable data removes a revision parameter while preserving named viewport controls
        data: State<Array<T>>,
        itemWidth: Float32,
        spacing!: Float32 = 0.0,
        scroll!: ?State<Float32> = None,
        key!: ?((T) -> String) = None,
        id!: ?String = None,
        controller!: ?LazyViewportController = None,
        overscan!: Float32 = LAZY_DEFAULT_OVERSCAN_PIXELS,
        item!: (T) -> Unit
    ): LazyRow {
        let (snapshot, revision) = data.valueRevisionSnapshot()
        LazyRow.of(snapshot, itemWidth, spacing: spacing, scroll: scroll, key: key, id: id, revision: revision,
            controller: controller, overscan: overscan, item: item)
    }

    public func measure(_: UiContext, available: Size): Size {
        Size(available.w, available.h)
    }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        frame = rect
        spatialClip = horizontalViewportSpatialClip(rect, paintOverflow)
        viewportMemory.viewportExtent = rect.w
        let content = lazyContentHeight(count, itemWidth, spacing)
        let (requestedScroll, scrollRevision) = scrollStateValue.valueRevisionSnapshot()
        if (scrollRevision != builtScrollRevision) {
            frameScroll = clampScrollOffset(requestedScroll, content, rect.w)
        }
        if (lazyFloatChanged(frameScroll, requestedScroll)) {
            scrollStateValue.value = frameScroll
        }
        let stride = itemWidth + spacing
        // Reserve the bottom bar lane once the columns overflow, so the bar never covers item content.
        let contentHeight = if (content > rect.w) {
            max(0.0, rect.h - scrollBarGutter())
        } else {
            rect.h
        }
        ctx.withSpatialClip(spatialClip) {
            => for (pair in visibleItems) {
                let (index, widget) = pair
                let x = rect.x - frameScroll + Float32(index) * stride
                widget.layout(ctx, Rect(x, rect.y, itemWidth, contentHeight))
            }
        }
        requestMaterializationIfNeeded(rect.w)
        lazyRememberAnchor(viewportMemory, frameScroll, count, {offset => Int64(max(0.0, offset) / stride)}, keyForIndex,
            {index => lazyFixedItemTop(index, itemWidth, spacing)})
    }

    private func requestMaterializationIfNeeded(viewportExtent: Float32): Unit {
        if (builtMaterializationGeneration != viewportMemory.currentMaterializationGeneration()) {
            return
        }
        let insets = lazyAdaptiveOverscan(overscan, frameScroll, viewportMemory.materializationOriginScroll,
            viewportExtent)
        let (desiredFirst, desiredLast) = lazyFixedVisibleRange(frameScroll, viewportExtent, itemWidth, spacing, count,
            insets)
        if (desiredFirst < materializedFirst || desiredLast > materializedLast) {
            viewportMemory.requestMaterialization()
        }
    }

    public func draw(ctx: UiContext): Unit {
        let content = lazyContentHeight(count, itemWidth, spacing)
        let stride = itemWidth + spacing
        // Exact on the scroll axis; cross-axis overflow comes from visible widget declarations.
        ctx.drawWithinSpatialClip(spatialClip) {
            => for (pair in visibleItems) {
                let (index, widget) = pair
                // Clip each column to its declared paint bounds; the strip still bounds the scroll axis.
                let colRect = Rect(frame.x - frameScroll + Float32(index) * stride, frame.y, itemWidth, frame.h)
                ctx.drawWithinSpatialClip(exactSpatialClip(widget.paintOutset().expand(colRect))) {
                    => widget.draw(ctx)
                }
            }
        }
        drawHorizontalScrollBar(ctx, frame, frameScroll, content, frame.w, active: scrollBar.dragging(ctx))
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool { // cjcheck-ignore: long-function # flat single-match event table; each arm is one interaction, splitting would scatter the wheel/drag pairing
        let content = lazyContentHeight(count, itemWidth, spacing)
        let viewportW = frame.w
        match (event) {
            case UiEvent.Frame(_) =>
                for (pair in visibleItems) {
                    let (_, widget) = pair
                    broadcastEvent(widget, ctx, event)
                }
                return false
            case UiEvent.MouseWheel(wheelX, wheelY, pointerX, pointerY) =>
                if (!spatialClip.contains(pointerX, pointerY)) {
                    return false
                }
                if (dispatchLazyVisibleItems(visibleItems, ctx, event)) {
                    return true
                }
                let delta = if (wheelX != 0.0) {
                    -wheelX
                } else {
                    wheelY
                }
                return scrollByWheel(scrollStateValue, delta, content, viewportW)
            case UiEvent.MouseDown(button, x, y) =>
                let primary = match (button) {
                    case MouseButton.Left => true;
                    case _ => false
                }
                if (primary && scrollBar.press(ctx, frame, scrollStateValue, content, viewportW, x, y)) {
                    return true
                }
                if (!spatialClip.contains(x, y)) {
                    return false
                }
            case UiEvent.MouseMove(x, y) =>
                if (scrollBar.drag(ctx, frame, scrollStateValue, content, viewportW, x)) {
                    return true
                }
                // While a child drag is live, track the pointer past the edge to the release.
                if (!spatialClip.contains(x, y) && ctx.dragId.isEmpty()) {
                    return false
                }
            case UiEvent.MouseUp(_, x, y) =>
                if (!spatialClip.contains(x, y) && ctx.dragId.isEmpty()) {
                    return false
                }
            case _ => ()
        }
        // Route to the materialized columns, right-most first, so an item consumes its own clicks.
        dispatchLazyVisibleItems(visibleItems, ctx, event)
    }

    public func isFlexible(): Bool {
        true
    }

    public func focusableIds(): Array<String> {
        collectLazyFocusableIds(visibleItems)
    }

    public func paintOutset(): PaintOutset {
        paintOverflow.verticalOnly()
    }
}
