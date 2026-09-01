package cui.core

import sdl.{Rect, Size}

// A dynamic draw is sampled again after a short delay in case it becomes static. Repeated dynamic
// results exponentially reduce recorder overhead, but every invalidation resets the latch promptly.
private let RETAINED_PAINT_BYPASS_INITIAL_FRAMES: Int64 = 32
private let RETAINED_PAINT_BYPASS_MAX_FRAMES: Int64 = 256

/* Shared across fresh RetainedSubtree wrappers produced by successive declarative builds. */
class RetainedRecord {
    var revision: UInt64
    private var cachePaint: Bool
    var child: Widget
    var focusableIds: Array<String>
    var focusFragment: FocusSnapshot
    var frameSubscribers: FrameSubscriptionSnapshot
    let mountScope: StateMountScope
    private let sceneNode: ElementSceneNode
    private var damageSink: ?((Rect) -> Unit) = None
    private var measureDependencies: ?PhaseStateDependencies = None
    private var layoutDependencies: ?PhaseStateDependencies = None
    private var paintDependencies: ?PhaseStateDependencies = None
    private var lastInvalidationReason = "mounted"
    private var buildHits: UInt64 = 0
    private var layoutHits: UInt64 = 0
    private var paintHits: UInt64 = 0
    private var paintRecordAttempts: UInt64 = 0
    private var paintDynamicBypasses: UInt64 = 0
    private var paintBypassFrames: UInt64 = 0
    private var paintBypassWindow: Int64 = 0
    private var paintBypassRemaining: Int64 = 0
    private var closed = false

    init(revision: UInt64, cachePaint: Bool, child: Widget) {
        this(revision, cachePaint, child, StateMountScope(), detachedFocusTargets(child.focusableIds()),
            emptyFrameSubscriptionSnapshot())
    }

    init(revision: UInt64, cachePaint: Bool, child: Widget, mountScope: StateMountScope) {
        this(revision, cachePaint, child, mountScope, detachedFocusTargets(child.focusableIds()),
            emptyFrameSubscriptionSnapshot())
    }

    init(
        revision: UInt64,
        cachePaint: Bool,
        child: Widget,
        mountScope: StateMountScope,
        focusTargets: Array<FocusTarget>,
        frameSubscribers: FrameSubscriptionSnapshot
    ) {
        this(revision, cachePaint, child, mountScope, focusTargets, frameSubscribers, detachedElementSceneNode())
    }

    init(
        revision: UInt64,
        cachePaint: Bool,
        child: Widget,
        mountScope: StateMountScope,
        focusTargets: Array<FocusTarget>,
        frameSubscribers: FrameSubscriptionSnapshot,
        sceneNode: ElementSceneNode
    ) {
        this(revision, cachePaint, child, mountScope, focusSnapshotFromDeclarations(focusTargets), frameSubscribers,
            sceneNode)
    }

    init(
        revision: UInt64,
        cachePaint: Bool,
        child: Widget,
        mountScope: StateMountScope,
        focusFragment: FocusSnapshot,
        frameSubscribers: FrameSubscriptionSnapshot,
        sceneNode: ElementSceneNode
    ) {
        this.revision = revision
        this.cachePaint = cachePaint
        this.child = child
        this.mountScope = mountScope
        this.sceneNode = sceneNode
        this.focusableIds = child.focusableIds()
        this.focusFragment = focusFragment
        this.frameSubscribers = frameSubscribers
        this.measureDependencies = Some(PhaseStateDependencies({=> invalidateMeasure()}))
        this.layoutDependencies = Some(PhaseStateDependencies({=> invalidateLayout()}))
        this.paintDependencies = Some(PhaseStateDependencies({=> invalidatePaint()}))
        mountScope.attachOwner(this)
    }

    func matches(revision: UInt64, cachePaint: Bool): Bool {
        this.revision == revision && this.cachePaint == cachePaint
    }

    func replace(
        revision: UInt64,
        cachePaint: Bool,
        child: Widget,
        focusFragment: FocusSnapshot,
        frameSubscribers: FrameSubscriptionSnapshot
    ): Unit {
        notePaintDamage()
        clearPaintCommands()
        closePhaseDependencies()
        this.revision = revision
        this.cachePaint = cachePaint
        this.child = child
        this.focusableIds = child.focusableIds()
        this.focusFragment = focusFragment
        this.frameSubscribers = frameSubscribers
        sceneNode.invalidateMeasure()
        lastInvalidationReason = "build output replaced"
    }

    func close(): Unit {
        if (closed) {
            return
        }
        notePaintDamage()
        clearPaintCommands()
        closePhaseDependencies()
        sceneNode.close()
        closed = true
    }

    func recordBuildHit(): Unit {
        buildHits += UInt64(1)
    }

    func attachDamageSink(sink: (Rect) -> Unit): Unit {
        damageSink = Some(sink)
    }

    func noteBuildInvalidationDamage(): Unit {
        notePaintDamage()
    }

    func measure(ctx: UiContext, available: Size): Size {
        let environment = ctx.uiEnvironmentKey()
        if (sceneNode.measureMatches(available, environment)) {
            return sceneNode.measuredSize()
        }
        let hadCommittedMeasure = sceneNode.hasMeasure()
        let dependencies = measureStateDependencies()
        let measured = collectPhaseStateReads(dependencies, {=> child.measure(ctx, available)})
        if (hadCommittedMeasure) {
            notePaintDamage()
            clearPaintCommands()
        }
        if (!dependencies.collectionWasInvalidated) {
            sceneNode.publishMeasure(available, environment, measured)
        } else {
            sceneNode.invalidateMeasure()
        }
        measured
    }

    func layout(ctx: UiContext, rect: Rect): Unit {
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
        collectPhaseStateReads(dependencies, {=> child.layout(ctx, rect)})
        if (!dependencies.collectionWasInvalidated) {
            let geometryChanged = !sceneNode.paintGeometryMatches(rect, paintOutset)
            let paintInputsChanged = geometryChanged || paintEnvironmentChanged
            if (paintInputsChanged) {
                notePaintDamage()
                clearPaintCommands()
            }
            sceneNode.publishLayout(
                ElementLayoutCommit(rect, spatialVisibility, paintOutset, environment,
                    ElementLayoutEffects(ctx.overlaySnapshotIfAnyFrom(overlayStart),
                        ctx.semanticFragmentIfAnyFrom(semanticStart))))
            if (paintInputsChanged) {
                notePaintDamage()
            }
        } else {
            sceneNode.invalidateLayout()
        }
    }

    func draw(ctx: UiContext): Unit {
        if (cachePaint && sceneNode.hasCommands() && !ctx.retainedPaintIntersects(sceneNode.paintBounds())) {
            return
        }
        if (sceneNode.hasCommands()) {
            if (sceneNode.replay(ctx.renderer, ctx.retainedDamageRegion())) {
                paintHits += UInt64(1)
            } else {
                sceneNode.invalidateCommands(resetBounds: false)
                recordAndDraw(ctx)
            }
        } else if (cachePaint) {
            if (paintBypassRemaining > 0) {
                drawDuringPaintBypass(ctx)
            } else {
                recordAndDraw(ctx)
            }
        } else {
            child.draw(ctx)
        }
    }

    func stats(): RetainedSubtreeStats {
        let (paintCommandCount, paintEstimatedBytes) = sceneNode.commandStats()
        RetainedSubtreeStats(buildHits, layoutHits, paintHits, mountScope.buildDependencyCount(),
            mountScope.buildInvalidations, frameSubscribers.size, measureStateDependencies().size,
            layoutStateDependencies().size, paintStateDependencies().size, paintCommandCount: paintCommandCount,
            paintEstimatedBytes: paintEstimatedBytes, paintRecordAttempts: paintRecordAttempts,
            paintDynamicBypasses: paintDynamicBypasses, paintBypassFrames: paintBypassFrames,
            paintBypassRemaining: paintBypassRemaining)
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
        if (sceneNode.hasLayout() && !dependencies.collectionWasInvalidated && dynamicReason.isNone() &&
            commands.isReplayable(ctx.renderer)) {
            sceneNode.publish(commands)
            resetPaintBypass()
            if (!sceneNode.replay(ctx.renderer, ctx.retainedDamageRegion())) {
                sceneNode.invalidateCommands(resetBounds: false)
                collectPhaseStateReads(dependencies, {=> child.draw(ctx)})
            }
        } else {
            sceneNode.invalidateCommands(resetBounds: false)
            let replayed = commands.replay(ctx.renderer)
            match (dynamicReason) {
                case Some(reason) =>
                    schedulePaintBypass()
                    lastInvalidationReason = "paint command cache bypassed: ${reason}"
                case None => ()
            }
            if (!replayed) {
                collectPhaseStateReads(dependencies, {=> child.draw(ctx)})
            }
        }
    }

    private func drawDuringPaintBypass(ctx: UiContext): Unit {
        paintBypassRemaining -= 1
        paintBypassFrames += UInt64(1)
        let dependencies = paintStateDependencies()
        collectPhaseStateReads(dependencies, {=> child.draw(ctx)})
        if (dependencies.collectionWasInvalidated) {
            lastInvalidationReason = "paint bypass draw invalidated its State dependencies"
        }
    }

    private func schedulePaintBypass(): Unit {
        paintDynamicBypasses += UInt64(1)
        paintBypassWindow = if (paintBypassWindow <= 0) {
            RETAINED_PAINT_BYPASS_INITIAL_FRAMES
        } else {
            min(RETAINED_PAINT_BYPASS_MAX_FRAMES, paintBypassWindow * 2)
        }
        paintBypassRemaining = paintBypassWindow
    }

    private func resetPaintBypass(): Unit {
        paintBypassWindow = 0
        paintBypassRemaining = 0
    }

    private func clearPaintCommands(): Unit {
        sceneNode.invalidateCommands(resetBounds: false)
        resetPaintBypass()
    }

    private func notePaintDamage(): Unit {
        let layoutBounds = sceneNode.layoutBounds()
        if (layoutBounds.w <= 0.0 || layoutBounds.h <= 0.0) {
            return
        }
        let layoutDamage = child.paintOutset().expand(layoutBounds)
        let damage = unionRect(layoutDamage, sceneNode.paintBounds().inset(-1.0))
        match (damageSink) {
            case Some(sink) => sink(damage)
            case None => ()
        }
    }

    func invalidateDescendantMeasure(): Unit {
        notePaintDamage()
        sceneNode.invalidateMeasure()
        clearPaintCommands()
        lastInvalidationReason = "descendant measure invalidated"
    }

    func invalidateDescendantLayout(): Unit {
        notePaintDamage()
        sceneNode.invalidateLayout()
        clearPaintCommands()
        lastInvalidationReason = "descendant layout invalidated"
    }

    func invalidateDescendantPaint(): Unit {
        notePaintDamage()
        clearPaintCommands()
        lastInvalidationReason = "descendant paint invalidated"
    }

    private func invalidateMeasure(): Unit {
        invalidateDescendantMeasure()
        lastInvalidationReason = "measure State dependency changed"
        mountScope.invalidateAncestorMeasure()
    }

    private func invalidateLayout(): Unit {
        invalidateDescendantLayout()
        lastInvalidationReason = "layout State dependency changed"
        mountScope.invalidateAncestorLayout()
    }

    private func invalidatePaint(): Unit {
        invalidateDescendantPaint()
        lastInvalidationReason = "paint State dependency changed"
        mountScope.invalidateAncestorPaint()
    }

    func diagnosticMeasureDirty(): Bool {
        !sceneNode.hasMeasure()
    }

    func diagnosticLayoutDirty(): Bool {
        !sceneNode.hasLayout()
    }

    func diagnosticPaintDirty(): Bool {
        cachePaint && !sceneNode.hasCommands() && paintBypassRemaining <= 0
    }

    func diagnosticInvalidationReason(): String {
        lastInvalidationReason
    }

    func diagnosticBounds(): Rect {
        sceneNode.layoutBounds()
    }

    private func closePhaseDependencies(): Unit {
        match (measureDependencies) {
            case Some(dependencies) => dependencies.close()
            case None => ()
        }
        match (layoutDependencies) {
            case Some(dependencies) => dependencies.close()
            case None => ()
        }
        match (paintDependencies) {
            case Some(dependencies) => dependencies.close()
            case None => ()
        }
    }

    private func measureStateDependencies(): PhaseStateDependencies {
        requiredPhaseStateDependencies(measureDependencies, "Retained measure")
    }

    private func layoutStateDependencies(): PhaseStateDependencies {
        requiredPhaseStateDependencies(layoutDependencies, "Retained layout")
    }

    private func paintStateDependencies(): PhaseStateDependencies {
        requiredPhaseStateDependencies(paintDependencies, "Retained paint")
    }
}
