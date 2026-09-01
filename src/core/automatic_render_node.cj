package cui.core

import sdl.{Rect, Size, UiEvent}

private let activeAutomaticRenderNode = ThreadLocal<AutomaticRenderNode>()

// Automatic display lists are deliberately selective. A tiny tree costs less to call directly
// than to retain, while an unbounded command buffer can pin textures and turn a speed feature into
// a memory leak. Rejected/dynamic candidates are sampled again with bounded backoff so a subtree
// can change character without paying recorder cost on every frame.
private let AUTOMATIC_PAINT_WARMUP_FRAMES: Int64 = 2
private let AUTOMATIC_PAINT_MIN_COMMANDS: Int64 = 24
private let AUTOMATIC_PAINT_MAX_BYTES: UInt64 = UInt64(8 * 1024 * 1024)
private let AUTOMATIC_PAINT_REJECT_BYPASS_FRAMES: Int64 = 64
private let AUTOMATIC_PAINT_DYNAMIC_BYPASS_INITIAL_FRAMES: Int64 = 32
private let AUTOMATIC_PAINT_DYNAMIC_BYPASS_MAX_FRAMES: Int64 = 256

/*
 * A persistent phase proxy for one emitted widget slot. The wrapped widget value may change after
 * a successful composition commit. The proxy keeps phase dependencies and event identity stable;
 * its Element scene slot owns measure, layout geometry, overlay/semantics replay and paint output.
 */
class AutomaticRenderNode <: Widget {
    private var child: Widget
    private let sceneNode: ElementSceneNode
    private let paintBudget: AutomaticPaintBudget
    private let invalidateDamage: (Rect) -> Unit
    private var parent: ?AutomaticRenderNode = None
    private var measureDependencies: ?PhaseStateDependencies = None
    private var layoutDependencies: ?PhaseStateDependencies = None
    private var paintDependencies: ?PhaseStateDependencies = None
    private var paintWarmupRemaining = AUTOMATIC_PAINT_WARMUP_FRAMES
    private var paintEstablished = false
    private var paintBypassRemaining: Int64 = 0
    private var paintDynamicWindow: Int64 = 0
    private var layoutHits: UInt64 = UInt64(0)
    private var paintHits: UInt64 = UInt64(0)
    private var paintRecordAttempts: UInt64 = UInt64(0)
    private var paintDynamicBypasses: UInt64 = UInt64(0)
    private var paintRejectedCandidates: UInt64 = UInt64(0)
    private var paintBudgetEvictions: UInt64 = UInt64(0)
    private var reservedPaintBytes: UInt64 = UInt64(0)
    private var paintLastUse: UInt64 = UInt64(0)
    private var eventTopologyVisited = false
    private var closed = false

    init(child: Widget, paintBudget: AutomaticPaintBudget, invalidateDamage: (Rect) -> Unit) {
        this(child, detachedElementSceneNode(), paintBudget, invalidateDamage)
    }

    init(child: Widget, sceneNode: ElementSceneNode, paintBudget: AutomaticPaintBudget, invalidateDamage: (Rect) -> Unit) {
        this.child = child
        this.sceneNode = sceneNode
        this.paintBudget = paintBudget
        this.invalidateDamage = invalidateDamage
        this.measureDependencies = Some(PhaseStateDependencies({=> invalidateMeasureFromState()}))
        this.layoutDependencies = Some(PhaseStateDependencies({=> invalidateLayoutFromState()}))
        this.paintDependencies = Some(PhaseStateDependencies({=> invalidatePaintFromState()}))
    }

    func update(next: Widget): Unit {
        if (sameWidget(child, next)) {
            return
        }
        child = next
        // Dependencies guard the last committed phase result, not the transient Widget value.
        // Keep that frontier until the replacement phase commits; collection will reuse an equal
        // trace or atomically reconcile a changed one, while failure preserves the old commit.
        invalidateMeasure()
    }

    func close(): Unit {
        if (closed) {
            return
        }
        measureStateDependencies().close()
        layoutStateDependencies().close()
        paintStateDependencies().close()
        invalidatePaintCache(resetWarmup: true)
        sceneNode.close()
        parent = None
        closed = true
    }

    public func measure(ctx: UiContext, available: Size): Size {
        attachToActiveParent()
        let environment = ctx.uiEnvironmentKey()
        if (sceneNode.measureMatches(available, environment)) {
            return sceneNode.measuredSize()
        }
        let hadCommittedMeasure = sceneNode.hasMeasure()
        let dependencies = measureStateDependencies()
        let measured = withActiveNode({=> collectPhaseStateReads(dependencies, {=> child.measure(ctx, available)})})
        if (hadCommittedMeasure) {
            noteDamage()
            invalidatePaintCache(resetWarmup: true)
        }
        if (!dependencies.collectionWasInvalidated) {
            sceneNode.publishMeasure(available, environment, measured)
        } else {
            sceneNode.invalidateMeasure()
        }
        measured
    }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        attachToActiveParent()
        let spatialVisibility = ctx.currentSpatialVisibility()
        let paintOutset = child.paintOutset()
        let environment = ctx.uiEnvironmentKey()
        if (sceneNode.layoutMatches(rect, spatialVisibility, paintOutset, environment)) {
            sceneNode.replayLayout(ctx)
            layoutHits += UInt64(1)
            return
        }
        let paintEnvironmentChanged = if (sceneNode.hasLayout()) {
            !sceneNode.layoutEnvironmentMatches(environment)
        } else {
            false
        }
        let overlayStart = ctx.overlayRegistrationCount()
        let semanticStart = ctx.semanticRegistrationCount()
        let dependencies = layoutStateDependencies()
        try {
            withActiveNode {
                =>
                    eventTopologyVisited = false
                    collectPhaseStateReads(dependencies, {=> child.layout(ctx, rect)})
                    if (!dependencies.collectionWasInvalidated) {
                        let eventTopology = if (eventTopologyVisited) {
                            sceneNode.stagedEventTopologyCommit()
                        } else {
                            ElementEventTopologyCommit.Clear
                        }
                        let geometryChanged = !sceneNode.paintGeometryMatches(rect, paintOutset)
                        let paintInputsChanged = geometryChanged || paintEnvironmentChanged
                        if (paintInputsChanged) {
                            noteDamage()
                            invalidatePaintCache(resetWarmup: true)
                        }
                        sceneNode.publishLayout(
                            ElementLayoutCommit(rect, spatialVisibility, paintOutset, environment,
                                ElementLayoutEffects(ctx.overlaySnapshotIfAnyFrom(overlayStart),
                                    ctx.semanticFragmentIfAnyFrom(semanticStart), eventTopology: eventTopology)))
                        if (paintInputsChanged) {
                            noteDamage()
                        }
                    } else {
                        sceneNode.invalidateLayout()
                    }
            }
        } finally {
            sceneNode.discardStagedEventTopology()
        }
    }

    public func draw(ctx: UiContext): Unit {
        if (sceneNode.hasCommands() && !ctx.retainedPaintIntersects(automaticPaintRect())) {
            return
        }
        if (sceneNode.hasCommands()) {
            if (sceneNode.replay(ctx.renderer, ctx.retainedDamageRegion())) {
                paintHits += UInt64(1)
                paintBudget.touch(this)
            } else {
                clearLocalPaintCache(resetWarmup: false)
                recordAndDraw(ctx)
            }
        } else if (ctx.retainedPartialDamageActive()) {
            drawDirect(ctx)
        } else if (paintWarmupRemaining > 0) {
            paintWarmupRemaining -= 1
            drawDirect(ctx)
        } else if (paintBypassRemaining > 0) {
            paintBypassRemaining -= 1
            drawDirect(ctx)
        } else {
            recordAndDraw(ctx)
        }
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        child.handle(ctx, event)
    }

    public func pointerEventScope(): PointerEventScope {
        child.pointerEventScope()
    }

    public func paintOutset(): PaintOutset {
        child.paintOutset()
    }

    public func isFlexible(): Bool {
        child.isFlexible()
    }

    public func flexWeight(): Float32 {
        child.flexWeight()
    }

    public func acceptsStretch(axis: Axis): Bool {
        child.acceptsStretch(axis)
    }

    public func participatesInLayout(): Bool {
        child.participatesInLayout()
    }

    public func needsDetachedLayout(): Bool {
        child.needsDetachedLayout()
    }

    public func focusableId(): ?String {
        child.focusableId()
    }

    public func focusableIds(): Array<String> {
        child.focusableIds()
    }

    private func withActiveNode<T>(body: () -> T): T {
        let previous = activeAutomaticRenderNode.get()
        activeAutomaticRenderNode.set(Some(this))
        try {
            body()
        } finally {
            activeAutomaticRenderNode.set(previous)
        }
    }

    private func attachToActiveParent(): Unit {
        match (activeAutomaticRenderNode.get()) {
            case Some(candidate) =>
                if (!sameAutomaticNode(candidate, this)) {
                    parent = Some(candidate)
                }
            case None => parent = None
        }
    }

    private func invalidateMeasure(): Unit {
        var shouldPropagate = sceneNode.hasMeasure()
        if (!shouldPropagate) {
            shouldPropagate = sceneNode.hasLayout()
        }
        sceneNode.invalidateMeasure()
        clearLocalPaintCache(resetWarmup: true)
        if (shouldPropagate) {
            match (parent) {
                case Some(value) => value.invalidateMeasure()
                case None => ()
            }
        }
    }

    private func invalidateLayout(): Unit {
        let shouldPropagate = sceneNode.hasLayout()
        sceneNode.invalidateLayout()
        clearLocalPaintCache(resetWarmup: true)
        if (shouldPropagate) {
            match (parent) {
                case Some(value) => value.invalidateLayout()
                case None => ()
            }
        }
    }

    private func invalidateMeasureFromState(): Unit {
        noteDamage()
        invalidateMeasure()
    }

    private func invalidateLayoutFromState(): Unit {
        noteDamage()
        invalidateLayout()
    }

    private func invalidatePaintFromState(): Unit {
        noteDamage()
        invalidatePaintCache(resetWarmup: false)
    }

    private func measureStateDependencies(): PhaseStateDependencies {
        requiredPhaseStateDependencies(measureDependencies, "Automatic measure")
    }

    private func layoutStateDependencies(): PhaseStateDependencies {
        requiredPhaseStateDependencies(layoutDependencies, "Automatic layout")
    }

    private func paintStateDependencies(): PhaseStateDependencies {
        requiredPhaseStateDependencies(paintDependencies, "Automatic paint")
    }

    private func drawDirect(ctx: UiContext): Unit {
        collectPhaseStateReads(paintStateDependencies(), {=> child.draw(ctx)})
    }

    private func recordAndDraw(ctx: UiContext): Unit {
        paintRecordAttempts += UInt64(1)
        let dependencies = paintStateDependencies()
        let (commands, dynamicReason) = ctx.trackRetainedPaint {
            ctx.renderer.recordCommands {
                collectPhaseStateReads(dependencies, {=> child.draw(ctx)})
            }
        }
        sceneNode.observePaintBounds(commands.paintBounds())
        let stats = commands.stats()
        let cacheWorthy = stats.commandCount >= AUTOMATIC_PAINT_MIN_COMMANDS || commands.hasSceneReferences()
        let cacheEligible = sceneNode.hasLayout() && !dependencies.collectionWasInvalidated && dynamicReason.isNone() &&
            commands.isReplayable(ctx.renderer) && cacheWorthy && stats.estimatedBytes <= AUTOMATIC_PAINT_MAX_BYTES
        let admittedToPaintBudget = if (cacheEligible) {
            // Admission mutates the global LRU and may evict another node, so keep that effect
            // explicit and execute it only after every pure eligibility predicate succeeds.
            paintBudget.admit(this, stats.estimatedBytes)
        } else {
            false
        }
        if (admittedToPaintBudget) {
            sceneNode.publish(commands)
            paintEstablished = true
            paintDynamicWindow = 0
            paintBypassRemaining = 0
            if (!sceneNode.replay(ctx.renderer, ctx.retainedDamageRegion())) {
                clearLocalPaintCache(resetWarmup: true)
                drawDirect(ctx)
            }
        } else {
            sceneNode.invalidateCommands(resetBounds: false)
            paintEstablished = false
            let replayed = commands.replay(ctx.renderer)
            if (!replayed) {
                collectPhaseStateReads(dependencies, {=> child.draw(ctx)})
            }
            match (dynamicReason) {
                case Some(_) => scheduleDynamicPaintBypass()
                case None =>
                    paintRejectedCandidates += UInt64(1)
                    paintBypassRemaining = AUTOMATIC_PAINT_REJECT_BYPASS_FRAMES
            }
        }
    }

    private func scheduleDynamicPaintBypass(): Unit {
        paintDynamicBypasses += UInt64(1)
        paintDynamicWindow = if (paintDynamicWindow <= 0) {
            AUTOMATIC_PAINT_DYNAMIC_BYPASS_INITIAL_FRAMES
        } else {
            min(AUTOMATIC_PAINT_DYNAMIC_BYPASS_MAX_FRAMES, paintDynamicWindow * 2)
        }
        paintBypassRemaining = paintDynamicWindow
    }

    private func invalidatePaintCache(resetWarmup!: Bool): Unit {
        let wasPatchBoundary = sceneNode.hasCommands()
        clearLocalPaintCache(resetWarmup: resetWarmup)
        if (!wasPatchBoundary) {
            match (parent) {
                case Some(value) => value.invalidatePaintCache(resetWarmup: resetWarmup)
                case None => ()
            }
        }
    }

    private func clearLocalPaintCache(resetWarmup!: Bool): Unit {
        paintBudget.release(this)
        sceneNode.invalidateCommands(resetBounds: resetWarmup)
        paintBypassRemaining = 0
        paintDynamicWindow = 0
        if (resetWarmup && !paintEstablished) {
            paintWarmupRemaining = AUTOMATIC_PAINT_WARMUP_FRAMES
        }
    }

    private func automaticPaintRect(): Rect {
        sceneNode.paintBounds()
    }

    func noteDamage(): Unit {
        let rect = automaticPaintRect()
        if (rect.w > 0.0 && rect.h > 0.0) {
            invalidateDamage(rect)
        }
    }

    func invalidateDescendantMeasure(): Unit {
        invalidateMeasure()
    }

    func invalidateDescendantLayout(): Unit {
        invalidateLayout()
    }

    func invalidateDescendantPaint(): Unit {
        invalidatePaintCache(resetWarmup: false)
    }

    func stats(): AutomaticRenderStats {
        let (commandCount, estimatedBytes) = sceneNode.commandStats()
        AutomaticRenderStats(1, layoutHits, paintHits, paintRecordAttempts, paintDynamicBypasses,
            paintRejectedCandidates, paintBudgetEvictions, commandCount, estimatedBytes, paintBypassRemaining,
            sceneNode.contentRevision())
    }

    func ownerElementId(): ElementId {
        sceneNode.id.owner
    }

    func eventTopologyFor(widget: Widget, childCount: Int64): ?ChildEventTopology {
        if (sameWidget(child, widget)) {
            eventTopologyVisited = true
            Some(sceneNode.eventTopology(childCount))
        } else {
            None
        }
    }

    func acceptPaintBudget(bytes: UInt64, lastUse: UInt64): Unit {
        reservedPaintBytes = bytes
        paintLastUse = lastUse
    }

    func touchPaintBudget(lastUse: UInt64): Unit {
        paintLastUse = lastUse
    }

    func releasePaintBudget(): Unit {
        reservedPaintBytes = UInt64(0)
    }

    func evictPaintForBudget(): Unit {
        sceneNode.invalidateCommands(resetBounds: false)
        reservedPaintBytes = UInt64(0)
        paintBypassRemaining = AUTOMATIC_PAINT_REJECT_BYPASS_FRAMES
        paintBudgetEvictions += UInt64(1)
    }

    func paintBudgetBytes(): UInt64 {
        reservedPaintBytes
    }

    func paintBudgetLastUse(): UInt64 {
        paintLastUse
    }
}

func activeAutomaticElementId(): ElementId {
    match (activeAutomaticRenderNode.get()) {
        case Some(node) => node.ownerElementId()
        case None => ElementId.detached()
    }
}

func activeAutomaticEventTopology(
    widget: Widget,
    childCount: Int64,
    fallback: ChildEventTopology
): ChildEventTopology {
    match (activeAutomaticRenderNode.get()) {
        case Some(node) => match (node.eventTopologyFor(widget, childCount)) {
            case Some(topology) => topology
            case None => fallback
        }
        case None => fallback
    }
}
