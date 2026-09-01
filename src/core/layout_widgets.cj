package cui.core

import sdl.{Rect, Size, UiEvent}

/** Aggregates of the fixed-measure pass, shared between the layout passes. */
struct FixedPass {
    let mainTotal: Float32
    let weightTotal: Float32
    let flexCount: Int64
    let participating: Int64

    init(mainTotal: Float32, weightTotal: Float32, flexCount: Int64, participating: Int64) {
        this.mainTotal = mainTotal
        this.weightTotal = weightTotal
        this.flexCount = flexCount
        this.participating = participating
    }
}

/*
 * Flex layout engine shared by VStack and HStack. Internal on purpose: it takes a
 * ready-made child array and never registers itself with a builder block, so callers
 * (the stack facades and buildChild) stay in control of what is emitted.
 *
 * Both axes run the same algorithm through main/cross accessors. Layout measures every
 * participating child exactly once per pass: non-flexible children while summing the
 * fixed extent, flexible children after their share of the leftover space is known.
 */
class Stack <: Widget {
    private let axis: Axis
    private let children: Array<Widget>
    private var spacing: Length
    private let contentPadding: LengthInsets
    private var flexible: Bool
    private var mainAlignment = MainAxisAlignment.Start
    private var crossAlignment = CrossAxisAlignment.Stretch
    // One build instance is measured and then laid out synchronously. Remembering that exact
    // constraint removes the otherwise duplicate child-measure traversal between the two phases;
    // a changed rect misses conservatively. The cache dies with the immediate-mode instance.
    private var measureCacheReady: Bool = false
    private var measureCacheAvailable = Size(-1.0, -1.0)
    private var measureCacheInnerAvailable = Size(-1.0, -1.0)
    private var measureCacheResult = Size.zero()
    private var measureCacheEnvironment: ?UiEnvironmentKey = None
    private let childMeasureCache: Array<Size>
    private let childMeasureValid: Array<Bool>
    // Transient layout-owned bounds used only by the following draw. They do not survive the
    // immediate Stack instance and therefore cannot diverge from retained Element geometry.
    private let childLayoutBounds: Array<Rect>
    private let childLayoutValid: Array<Bool>
    private let paintOverflow: PaintOutset
    private var eventTopology: ChildEventTopology

    init(
        axis: Axis,
        children: Array<Widget>,
        spacing!: Length = vpLength(CUI_GAP),
        padding!: LengthInsets = LengthInsets.zero(),
        flexible!: Bool = true
    ) {
        this.axis = axis
        this.children = children
        this.spacing = spacing
        this.contentPadding = padding
        this.flexible = flexible
        this.childMeasureCache = Array<Size>(children.size, {_ => Size.zero()})
        this.childMeasureValid = Array<Bool>(children.size, repeat: false)
        this.childLayoutBounds = Array<Rect>(children.size, {_ => Rect.zero()})
        this.childLayoutValid = Array<Bool>(children.size, repeat: false)
        this.paintOverflow = aggregatePaintOutsets(children)
        this.eventTopology = ChildEventTopology(children.size)
    }

    func setSpacing(value: Length): Unit {
        spacing = value
    }

    func setFlexible(value!: Bool): Unit {
        flexible = value
    }

    func setMainAlignment(value: MainAxisAlignment): Unit {
        mainAlignment = value
    }

    func setCrossAlignment(value: CrossAxisAlignment): Unit {
        crossAlignment = value
    }

    func bindEventTopology(owner: Widget): Unit {
        eventTopology = activeAutomaticEventTopology(owner, children.size, eventTopology)
    }

    // Content size along the main axis is the sum of child extents; the cross axis hugs
    // the tallest/widest child. This lets a container opt out of filling (flexible: false)
    // and be laid out at exactly the size of what it holds, e.g. a compact toolbar row.
    public func measure(ctx: UiContext, available: Size): Size {
        let environment = ctx.uiEnvironmentKey()
        if (measureCacheMatches(available, environment)) {
            return measureCacheResult
        }
        measureCacheReady = false
        for (index in 0..childMeasureValid.size) {
            childMeasureValid[index] = false
        }
        let padding = ctx.resolve(contentPadding)
        let inner = Size(
            max(0.0, available.w - padding.horizontal()),
            max(0.0, available.h - padding.vertical())
        )
        var along: Float32 = 0.0
        var cross: Float32 = 0.0
        var participating: Int64 = 0
        for (index in 0..children.size) {
            let child = children[index]
            if (!child.participatesInLayout()) {
                continue
            }
            participating += 1
            let size = child.measure(ctx, inner)
            childMeasureCache[index] = size
            childMeasureValid[index] = true
            along += mainOf(size)
            cross = max(cross, crossOf(size))
        }
        along += gapTotal(resolvedGap(ctx), participating)
        let result = match (axis) {
            case Axis.Horizontal => Size(along + padding.horizontal(), cross + padding.vertical())
            case Axis.Vertical => Size(cross + padding.horizontal(), along + padding.vertical())
        }
        measureCacheAvailable = available
        measureCacheInnerAvailable = inner
        measureCacheResult = result
        measureCacheEnvironment = Some(environment)
        measureCacheReady = true
        result
    }

    /*
     * Three passes, each child measured exactly once: size the non-flexible children,
     * share the leftover space among flexible ones, then place everything.
     */
    public func layout(ctx: UiContext, rect: Rect): Unit {
        eventTopology.beginLayout()
        for (index in 0..childLayoutValid.size) {
            childLayoutValid[index] = false
        }
        let inner = rect.inset(ctx.resolve(contentPadding))
        let gap = resolvedGap(ctx)
        let count = children.size
        let extents = Array<Float32>(count, {_ => Float32(0.0)})
        let crossSizes = Array<Float32>(count, {_ => Float32(0.0)})

        let fixed = measureFixedChildren(ctx, inner, extents, crossSizes)
        let gaps = gapTotal(gap, fixed.participating)
        let remaining = max(0.0, mainExtent(inner) - fixed.mainTotal - gaps)
        let flexTotal = measureFlexibleChildren(ctx, inner, gap, remaining, fixed, extents, crossSizes)
        placeChildren(ctx, inner, gap, fixed.mainTotal + flexTotal + gaps, fixed.participating, extents, crossSizes)
        eventTopology.commitLayout(children, rect)
    }

    /** Measures non-flexible children into the slot arrays; returns totals and weights. */
    private func measureFixedChildren(
        ctx: UiContext,
        inner: Rect,
        extents: Array<Float32>,
        crossSizes: Array<Float32>
    ): FixedPass {
        var mainTotal: Float32 = 0.0
        var weightTotal: Float32 = 0.0
        var flexCount: Int64 = 0
        var participating: Int64 = 0
        for (i in 0..children.size) {
            let child = children[i]
            if (!child.participatesInLayout()) {
                continue
            }
            participating += 1
            if (child.isFlexible()) {
                weightTotal += child.flexWeight()
                flexCount += 1
            } else {
                let measured = cachedChildMeasure(ctx, child, i, Size(inner.w, inner.h))
                extents[i] = mainOf(measured)
                crossSizes[i] = crossOf(measured)
                mainTotal += extents[i]
            }
        }
        FixedPass(mainTotal, weightTotal, flexCount, participating)
    }

    private func cachedChildMeasure(
        ctx: UiContext,
        child: Widget,
        index: Int64,
        available: Size
    ): Size {
        if (measureCacheReady && childMeasureValid[index] && sameLayoutSize(measureCacheInnerAvailable, available)) {
            return childMeasureCache[index]
        }
        child.measure(ctx, available)
    }

    private func measureCacheMatches(available: Size, environment: UiEnvironmentKey): Bool {
        measureCacheReady && sameLayoutSize(measureCacheAvailable, available) && measureCacheEnvironmentMatches(
            environment)
    }

    private func measureCacheEnvironmentMatches(environment: UiEnvironmentKey): Bool {
        match (measureCacheEnvironment) {
            case Some(value) => sameUiEnvironment(value, environment)
            case None => false
        }
    }

    /** Distributes `remaining` main-axis space to flexible children; returns their total. */
    private func measureFlexibleChildren(
        ctx: UiContext,
        inner: Rect,
        gap: Float32,
        remaining: Float32,
        fixed: FixedPass,
        extents: Array<Float32>,
        crossSizes: Array<Float32>
    ): Float32 {
        let unit = flexUnit(remaining, fixed.weightTotal, fixed.flexCount, gap)
        var flexTotal: Float32 = 0.0
        for (i in 0..children.size) {
            let child = children[i]
            if (!child.participatesInLayout() || !child.isFlexible()) {
                continue
            }
            extents[i] = flexExtent(child.flexWeight(), unit, gap)
            let measured = child.measure(ctx, constrained(inner, extents[i]))
            crossSizes[i] = crossOf(measured)
            flexTotal += extents[i]
        }
        flexTotal
    }

    private func placeChildren(
        ctx: UiContext,
        inner: Rect,
        gap: Float32,
        childrenExtent: Float32,
        participating: Int64,
        extents: Array<Float32>,
        crossSizes: Array<Float32>
    ): Unit {
        let plan = arrangementPlan(mainExtent(inner), childrenExtent, participating, gap)
        var cursor = mainOrigin(inner) + plan[0]
        for (i in 0..children.size) {
            let child = children[i]
            if (!child.participatesInLayout()) {
                layoutDetachedIfNeeded(child, ctx)
                continue
            }
            let cross = crossPlacement(inner, crossSizes[i], child.acceptsStretch(crossAxis()))
            let bounds = childRect(cursor, extents[i], cross[0], cross[1])
            child.layout(ctx, bounds)
            childLayoutBounds[i] = bounds
            childLayoutValid[i] = true
            eventTopology.noteChildLayout(i, bounds, child)
            cursor += extents[i] + plan[1]
        }
    }

    public func draw(ctx: UiContext): Unit {
        match (ctx.currentSpatialPaintBounds()) {
            case Some(clip) => for (index in 0..children.size) {
                let child = children[index]
                if (!childLayoutValid[index] || paintBoundsIntersect(
                    child.paintOutset().expand(childLayoutBounds[index]), clip)) {
                    child.draw(ctx)
                }
            }
            case None => for (child in children) {
                child.draw(ctx)
            }
        }
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        eventTopology.dispatch(children, ctx, event)
    }

    public func pointerEventScope(): PointerEventScope {
        eventTopology.pointerEventScope()
    }

    public func paintOutset(): PaintOutset {
        paintOverflow
    }

    public func isFlexible(): Bool {
        flexible
    }

    public func focusableIds(): Array<String> {
        collectFocusableIds(children)
    }

    /** Leading inset and per-gap step realising the configured main-axis alignment. */
    private func arrangementPlan(
        available: Float32,
        childrenExtent: Float32,
        count: Int64,
        gap: Float32
    ): Array<Float32> {
        if (count == 0) {
            return [0.0, gap]
        }
        let extra = max(0.0, available - childrenExtent)
        match (mainAlignment) {
            case MainAxisAlignment.Start => [0.0, gap]
            case MainAxisAlignment.Center => [extra / 2.0, gap]
            case MainAxisAlignment.End => [extra, gap]
            case MainAxisAlignment.SpaceBetween =>
                if (count > 1) {
                    [0.0, gap + extra / Float32(count - 1)]
                } else {
                    [0.0, gap]
                }
            case MainAxisAlignment.SpaceAround =>
                let distributed = extra / Float32(count)
                [distributed / 2.0, gap + distributed]
            case MainAxisAlignment.SpaceEvenly =>
                let distributed = extra / Float32(count + 1)
                [distributed, gap + distributed]
        }
    }

    /** Cross-axis origin and extent for one child. */
    private func crossPlacement(inner: Rect, measured: Float32, canStretch: Bool): Array<Float32> {
        let origin = crossOrigin(inner)
        let available = crossExtent(inner)
        let extent = min(available, measured)
        match (crossAlignment) {
            case CrossAxisAlignment.Stretch =>
                if (canStretch) {
                    [origin, available]
                } else {
                    [origin, extent]
                }
            case CrossAxisAlignment.Start => [origin, extent]
            case CrossAxisAlignment.Center => [origin + max(0.0, available - extent) / 2.0, extent]
            case CrossAxisAlignment.End => [origin + max(0.0, available - extent), extent]
        }
    }

    /*
     * Size of one weight unit. Leftover space is shared among flexible children in
     * proportion to flexWeight. A child of weight w also absorbs the (w - 1) gaps it
     * spans (see flexExtent), so those gaps are removed from the shared pool first —
     * that keeps a weight-2 cell exactly aligned with two single cells plus their gap.
     */
    private func flexUnit(remaining: Float32, weightTotal: Float32, flexCount: Int64, gap: Float32): Float32 {
        if (weightTotal <= 0.0) {
            return 0.0
        }
        let absorbedGaps = gap * (weightTotal - Float32(flexCount))
        max(0.0, remaining - absorbedGaps) / weightTotal
    }

    private func flexExtent(weight: Float32, unit: Float32, gap: Float32): Float32 {
        max(0.0, unit * weight + gap * (weight - 1.0))
    }

    private func resolvedGap(ctx: UiContext): Float32 {
        max(0.0, ctx.resolve(spacing))
    }

    private func gapTotal(gap: Float32, count: Int64): Float32 {
        gapExtent(count, gap)
    }

    private func mainOf(size: Size): Float32 {
        match (axis) {
            case Axis.Vertical => size.h
            case Axis.Horizontal => size.w
        }
    }

    private func crossOf(size: Size): Float32 {
        match (axis) {
            case Axis.Vertical => size.w
            case Axis.Horizontal => size.h
        }
    }

    private func mainExtent(rect: Rect): Float32 {
        match (axis) {
            case Axis.Vertical => rect.h
            case Axis.Horizontal => rect.w
        }
    }

    private func crossExtent(rect: Rect): Float32 {
        match (axis) {
            case Axis.Vertical => rect.w
            case Axis.Horizontal => rect.h
        }
    }

    private func mainOrigin(rect: Rect): Float32 {
        match (axis) {
            case Axis.Vertical => rect.y
            case Axis.Horizontal => rect.x
        }
    }

    private func crossOrigin(rect: Rect): Float32 {
        match (axis) {
            case Axis.Vertical => rect.x
            case Axis.Horizontal => rect.y
        }
    }

    private func crossAxis(): Axis {
        match (axis) {
            case Axis.Vertical => Axis.Horizontal
            case Axis.Horizontal => Axis.Vertical
        }
    }

    /** The child's available box when its main-axis extent is already decided. */
    private func constrained(inner: Rect, mainSize: Float32): Size {
        match (axis) {
            case Axis.Vertical => Size(inner.w, mainSize)
            case Axis.Horizontal => Size(mainSize, inner.h)
        }
    }

    private func childRect(mainPos: Float32, mainSize: Float32, crossPos: Float32, crossSize: Float32): Rect {
        match (axis) {
            case Axis.Vertical => Rect(crossPos, mainPos, crossSize, mainSize)
            case Axis.Horizontal => Rect(mainPos, crossPos, mainSize, crossSize)
        }
    }
}

private func paintBoundsIntersect(left: Rect, right: Rect): Bool {
    let overlap = left.intersection(right)
    overlap.w > 0.0 && overlap.h > 0.0
}

private func sameLayoutSize(left: Size, right: Size): Bool {
    left.w.toBits() == right.w.toBits() && left.h.toBits() == right.h.toBits()
}
