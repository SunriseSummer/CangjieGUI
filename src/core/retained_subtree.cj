package cui.core

import sdl.{Rect, RenderCommandBuffer, Size, UiEvent}

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
    var frameSubscribers: Array<FrameSubscriber>
    private var measuredAvailable = Size.zero()
    private var measured = Size.zero()
    private var measureValid = false
    private var laidOutRect = Rect.zero()
    private var layoutValid = false
    private var layoutOverlays: Array<Overlay> = []
    let mountScope: StateMountScope
    private var paintCommands: ?RenderCommandBuffer = None
    private var paintBounds: ?Rect = None
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

    init(revision: UInt64, cachePaint: Bool, child: Widget) {
        this(revision, cachePaint, child, StateMountScope(), [])
    }

    init(revision: UInt64, cachePaint: Bool, child: Widget, mountScope: StateMountScope) {
        this(revision, cachePaint, child, mountScope, [])
    }

    init(
        revision: UInt64,
        cachePaint: Bool,
        child: Widget,
        mountScope: StateMountScope,
        frameSubscribers: Array<FrameSubscriber>
    ) {
        this.revision = revision
        this.cachePaint = cachePaint
        this.child = child
        this.mountScope = mountScope
        this.focusableIds = child.focusableIds()
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
        frameSubscribers: Array<FrameSubscriber>
    ): Unit {
        notePaintDamage()
        clearPaintCommands()
        closePhaseDependencies()
        this.revision = revision
        this.cachePaint = cachePaint
        this.child = child
        this.focusableIds = child.focusableIds()
        this.frameSubscribers = frameSubscribers
        measureValid = false
        layoutValid = false
        layoutOverlays = []
        lastInvalidationReason = "build output replaced"
    }

    func close(): Unit {
        notePaintDamage()
        clearPaintCommands()
        closePhaseDependencies()
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
        if (measureValid && sameSize(measuredAvailable, available)) {
            return measured
        }
        clearPaintCommands()
        measuredAvailable = available
        let dependencies = measureStateDependencies()
        measured = collectPhaseStateReads(dependencies, {=> child.measure(ctx, available)})
        measureValid = !dependencies.collectionWasInvalidated
        layoutValid = false
        measured
    }

    func layout(ctx: UiContext, rect: Rect): Unit {
        if (layoutValid && sameRect(laidOutRect, rect)) {
            for (overlay in layoutOverlays) {
                ctx.setOverlay(overlay)
            }
            layoutHits += UInt64(1)
            return
        }
        let overlayStart = ctx.overlayRegistrationCount()
        let dependencies = layoutStateDependencies()
        collectPhaseStateReads(dependencies, {=> child.layout(ctx, rect)})
        let geometryChanged = !sameRect(laidOutRect, rect)
        if (geometryChanged) {
            notePaintDamage()
            clearPaintCommands()
        }
        laidOutRect = rect
        if (geometryChanged) {
            notePaintDamage()
        }
        layoutValid = !dependencies.collectionWasInvalidated
        layoutOverlays = ctx.overlayRegistrationsFrom(overlayStart)
    }

    func draw(ctx: UiContext): Unit {
        if (cachePaint && paintCommands.isSome() && !ctx.retainedPaintIntersects(laidOutRect)) {
            return
        }
        match (paintCommands) {
            case Some(commands) =>
                if (commands.replay(ctx.renderer)) {
                    paintHits += UInt64(1)
                } else {
                    paintCommands = None
                    recordAndDraw(ctx)
                }
            case None =>
                if (cachePaint) {
                    if (paintBypassRemaining > 0) {
                        drawDuringPaintBypass(ctx)
                    } else {
                        recordAndDraw(ctx)
                    }
                } else {
                    child.draw(ctx)
                }
        }
    }

    func stats(): RetainedSubtreeStats {
        let paintCommandCount = match (paintCommands) {
            case Some(commands) => commands.stats().commandCount
            case None => 0
        }
        let paintEstimatedBytes = match (paintCommands) {
            case Some(commands) => commands.stats().estimatedBytes
            case None => UInt64(0)
        }
        RetainedSubtreeStats(buildHits, layoutHits, paintHits, mountScope.buildDependencies.size,
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
        paintBounds = commands.paintBounds()
        let replayed = commands.replay(ctx.renderer)
        if (layoutValid && !dependencies.collectionWasInvalidated && dynamicReason.isNone() && replayed) {
            paintCommands = Some(commands)
            resetPaintBypass()
        } else {
            paintCommands = None
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
        paintCommands = None
        resetPaintBypass()
    }

    private func notePaintDamage(): Unit {
        if (laidOutRect.w <= 0.0 || laidOutRect.h <= 0.0) {
            return
        }
        let layoutDamage = laidOutRect.inset(-CUI_SHADOW_CLEARANCE)
        let damage = match (paintBounds) {
            case Some(paint) => unionRect(layoutDamage, paint.inset(-1.0))
            case None => layoutDamage
        }
        match (damageSink) {
            case Some(sink) => sink(damage)
            case None => ()
        }
    }

    func invalidateDescendantMeasure(): Unit {
        notePaintDamage()
        measureValid = false
        layoutValid = false
        clearPaintCommands()
        lastInvalidationReason = "descendant measure invalidated"
    }

    func invalidateDescendantLayout(): Unit {
        notePaintDamage()
        layoutValid = false
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
        !measureValid
    }

    func diagnosticLayoutDirty(): Bool {
        !layoutValid
    }

    func diagnosticPaintDirty(): Bool {
        cachePaint && paintCommands.isNone() && paintBypassRemaining <= 0
    }

    func diagnosticInvalidationReason(): String {
        lastInvalidationReason
    }

    func diagnosticBounds(): Rect {
        laidOutRect
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

/** Cache-hit counters for diagnostics and performance tests. */
public struct RetainedSubtreeStats {
    public let buildHits: UInt64
    public let layoutHits: UInt64
    public let paintHits: UInt64
    public let buildDependencyCount: Int64
    public let buildInvalidations: UInt64
    public let frameSubscriberCount: Int64
    public let measureDependencyCount: Int64
    public let layoutDependencyCount: Int64
    public let paintDependencyCount: Int64
    public let paintCommandCount: Int64
    public let paintEstimatedBytes: UInt64
    public let paintRecordAttempts: UInt64
    public let paintDynamicBypasses: UInt64
    public let paintBypassFrames: UInt64
    public let paintBypassRemaining: Int64

    public init(buildHits: UInt64, layoutHits: UInt64, paintHits: UInt64) {
        this(buildHits, layoutHits, paintHits, 0, UInt64(0))
    }

    public init(
        buildHits: UInt64,
        layoutHits: UInt64,
        paintHits: UInt64,
        buildDependencyCount: Int64,
        buildInvalidations: UInt64
    ) {
        this(buildHits, layoutHits, paintHits, buildDependencyCount, buildInvalidations, 0, 0, 0, 0,
            paintCommandCount: 0, paintEstimatedBytes: UInt64(0))
    }

    public init(
        buildHits: UInt64,
        layoutHits: UInt64,
        paintHits: UInt64,
        buildDependencyCount: Int64,
        buildInvalidations: UInt64,
        measureDependencyCount: Int64,
        layoutDependencyCount: Int64,
        paintDependencyCount: Int64
    ) {
        this(buildHits, layoutHits, paintHits, buildDependencyCount, buildInvalidations, 0, measureDependencyCount,
            layoutDependencyCount, paintDependencyCount, paintCommandCount: 0, paintEstimatedBytes: UInt64(0))
    }

    public init(
        buildHits: UInt64,
        layoutHits: UInt64,
        paintHits: UInt64,
        buildDependencyCount: Int64,
        buildInvalidations: UInt64,
        frameSubscriberCount: Int64,
        measureDependencyCount: Int64,
        layoutDependencyCount: Int64,
        paintDependencyCount: Int64,
        paintCommandCount!: Int64 = 0,
        paintEstimatedBytes!: UInt64 = UInt64(0),
        paintRecordAttempts!: UInt64 = UInt64(0),
        paintDynamicBypasses!: UInt64 = UInt64(0),
        paintBypassFrames!: UInt64 = UInt64(0),
        paintBypassRemaining!: Int64 = 0
    ) {
        this.buildHits = buildHits
        this.layoutHits = layoutHits
        this.paintHits = paintHits
        this.buildDependencyCount = buildDependencyCount
        this.buildInvalidations = buildInvalidations
        this.frameSubscriberCount = frameSubscriberCount
        this.measureDependencyCount = measureDependencyCount
        this.layoutDependencyCount = layoutDependencyCount
        this.paintDependencyCount = paintDependencyCount
        this.paintCommandCount = paintCommandCount
        this.paintEstimatedBytes = paintEstimatedBytes
        this.paintRecordAttempts = paintRecordAttempts
        this.paintDynamicBypasses = paintDynamicBypasses
        this.paintBypassFrames = paintBypassFrames
        this.paintBypassRemaining = paintBypassRemaining
    }
}

/**
 * A retained build boundary inside CUI's declarative tree. The key-only initializer tracks State
 * values read while executing the body and rebuilds when one changes. The revision initializer adds
 * an explicit invalidation input for ordinary captured values and non-build phase dependencies.
 * A stable boundary reuses the widget subtree and can skip unchanged measure/layout as well.
 * Remembered state, focus stops, events, and overlays remain live.
 * `cachePaint: true` records value-based renderer commands and transparently replays them on later
 * draws. State reads during recording invalidate only paint; explicit revision remains available for
 * ordinary captured values and resource changes.
 */
public class RetainedSubtree <: Widget {
    private let record: RetainedRecord

    /** Creates a boundary whose build-phase State reads automatically invalidate its body. */
    public init(key: String, cachePaint!: Bool = false, body!: () -> Unit) {
        this.record = buildRetainedChild(key, UInt64(0), cachePaint, body)
        emit(this)
    }

    public init(key: String, revision: UInt64, cachePaint!: Bool = false, body!: () -> Unit) {
        this.record = buildRetainedChild(key, revision, cachePaint, body)
        emit(this)
    }

    /** Cache hits accumulated by this retained identity since it was first mounted. */
    public func cacheStats(): RetainedSubtreeStats {
        record.stats()
    }

    public func measure(ctx: UiContext, available: Size): Size {
        record.measure(ctx, available)
    }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        record.layout(ctx, rect)
    }

    public func draw(ctx: UiContext): Unit {
        record.draw(ctx)
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        record.child.handle(ctx, event)
    }

    public func isFlexible(): Bool {
        record.child.isFlexible()
    }

    public func flexWeight(): Float32 {
        record.child.flexWeight()
    }

    public func acceptsStretch(axis: Axis): Bool {
        record.child.acceptsStretch(axis)
    }

    public func participatesInLayout(): Bool {
        record.child.participatesInLayout()
    }

    public func focusableId(): ?String {
        record.child.focusableId()
    }

    public func focusableIds(): Array<String> {
        record.focusableIds
    }
}

private func sameSize(left: Size, right: Size): Bool {
    left.w == right.w && left.h == right.h
}

private func sameRect(left: Rect, right: Rect): Bool {
    left.x == right.x && left.y == right.y && left.w == right.w && left.h == right.h
}
