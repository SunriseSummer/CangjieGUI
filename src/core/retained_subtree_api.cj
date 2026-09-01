package cui.core

import sdl.{Rect, Size, UiEvent}

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
        this.record = buildRetainedChild(key, UInt64(0), cachePaint, body, hasExternalRevision: false)
        emit(this)
    }

    public init(key: String, revision: UInt64, cachePaint!: Bool = false, body!: () -> Unit) {
        this.record = buildRetainedChild(key, revision, cachePaint, body, hasExternalRevision: true)
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

    public func pointerEventScope(): PointerEventScope {
        record.child.pointerEventScope()
    }

    public func paintOutset(): PaintOutset {
        record.child.paintOutset()
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

    public func needsDetachedLayout(): Bool {
        record.child.needsDetachedLayout()
    }

    public func focusableId(): ?String {
        record.child.focusableId()
    }

    public func focusableIds(): Array<String> {
        record.focusableIds
    }
}
