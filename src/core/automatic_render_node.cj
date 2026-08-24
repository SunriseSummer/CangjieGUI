package cui.core

import std.collection.ArrayList
import sdl.{Rect, RenderCommandBuffer, Size, UiEvent}

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
 * a successful composition commit, while the proxy keeps constraints, geometry, overlay replay,
 * phase dependencies, and event identity stable across frames.
 */
class AutomaticRenderNode <: Widget {
    private var child: Widget
    private let paintBudget: AutomaticPaintBudget
    private let invalidateComposition: () -> Unit
    private let invalidateDamage: (Rect) -> Unit
    private var parent: ?AutomaticRenderNode = None
    private var measuredAvailable = Size.zero()
    private var measured = Size.zero()
    private var measureValid = false
    private var laidOutRect = Rect.zero()
    private var layoutValid = false
    private var layoutOverlays: Array<Overlay> = []
    private var measureDependencies: ?PhaseStateDependencies = None
    private var layoutDependencies: ?PhaseStateDependencies = None
    private var paintDependencies: ?PhaseStateDependencies = None
    private var paintCommands: ?RenderCommandBuffer = None
    private var paintBounds: ?Rect = None
    private var paintWarmupRemaining = AUTOMATIC_PAINT_WARMUP_FRAMES
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

    init(child: Widget, paintBudget: AutomaticPaintBudget, invalidateComposition: () -> Unit,
        invalidateDamage: (Rect) -> Unit) {
        this.child = child
        this.paintBudget = paintBudget
        this.invalidateComposition = invalidateComposition
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
        measureStateDependencies().close()
        layoutStateDependencies().close()
        paintStateDependencies().close()
        invalidateMeasure()
    }

    func close(): Unit {
        measureStateDependencies().close()
        layoutStateDependencies().close()
        paintStateDependencies().close()
        invalidatePaintCache(resetWarmup: true)
        parent = None
    }

    public func measure(ctx: UiContext, available: Size): Size {
        attachToActiveParent()
        if (measureValid && sameAutomaticSize(measuredAvailable, available)) {
            return measured
        }
        measuredAvailable = available
        let dependencies = measureStateDependencies()
        measured = withActiveNode({=> collectPhaseStateReads(dependencies, {=> child.measure(ctx, available)})})
        measureValid = !dependencies.collectionWasInvalidated
        layoutValid = false
        measured
    }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        attachToActiveParent()
        if (layoutValid && sameAutomaticRect(laidOutRect, rect)) {
            for (overlay in layoutOverlays) {
                ctx.setOverlay(overlay)
            }
            layoutHits += UInt64(1)
            return
        }
        let overlayStart = ctx.overlayRegistrationCount()
        let dependencies = layoutStateDependencies()
        withActiveNode {
            =>
                collectPhaseStateReads(dependencies, {=> child.layout(ctx, rect)})
                let geometryChanged = !sameAutomaticRect(laidOutRect, rect)
                if (geometryChanged) {
                    noteDamage()
                    invalidatePaintCache(resetWarmup: true)
                }
                laidOutRect = rect
                if (geometryChanged) {
                    noteDamage()
                }
                layoutValid = !dependencies.collectionWasInvalidated
                layoutOverlays = ctx.overlayRegistrationsFrom(overlayStart)
        }
    }

    public func draw(ctx: UiContext): Unit {
        if (paintCommands.isSome() && !ctx.retainedPaintIntersects(automaticPaintRect())) {
            return
        }
        match (paintCommands) {
            case Some(commands) =>
                if (commands.replay(ctx.renderer)) {
                    paintHits += UInt64(1)
                    paintBudget.touch(this)
                } else {
                    invalidatePaintCache(resetWarmup: true)
                    drawDirect(ctx)
                }
            case None =>
                if (ctx.retainedPartialDamageActive()) {
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
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        child.handle(ctx, event)
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
        let shouldPropagate = measureValid || layoutValid
        measureValid = false
        layoutValid = false
        clearLocalPaintCache(resetWarmup: true)
        if (shouldPropagate) {
            match (parent) {
                case Some(value) => value.invalidateMeasure()
                case None => ()
            }
        }
    }

    private func invalidateLayout(): Unit {
        let shouldPropagate = layoutValid
        layoutValid = false
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
        invalidateComposition()
    }

    private func invalidateLayoutFromState(): Unit {
        noteDamage()
        invalidateLayout()
        invalidateComposition()
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
        paintBounds = commands.paintBounds()
        let replayed = commands.replay(ctx.renderer)
        let stats = commands.stats()
        if (layoutValid && !dependencies.collectionWasInvalidated && dynamicReason.isNone() && replayed &&
            stats.commandCount >= AUTOMATIC_PAINT_MIN_COMMANDS && stats.estimatedBytes <= AUTOMATIC_PAINT_MAX_BYTES &&
            paintBudget.admit(this, stats.estimatedBytes)) {
            paintCommands = Some(commands)
            paintDynamicWindow = 0
            paintBypassRemaining = 0
        } else {
            paintCommands = None
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
        clearLocalPaintCache(resetWarmup: resetWarmup)
        match (parent) {
            case Some(value) => value.invalidatePaintCache(resetWarmup: resetWarmup)
            case None => ()
        }
    }

    private func clearLocalPaintCache(resetWarmup!: Bool): Unit {
        paintBudget.release(this)
        paintCommands = None
        paintBounds = None
        paintBypassRemaining = 0
        paintDynamicWindow = 0
        if (resetWarmup) {
            paintWarmupRemaining = AUTOMATIC_PAINT_WARMUP_FRAMES
        }
    }

    private func automaticPaintRect(): Rect {
        match (paintBounds) {
            case Some(value) => value
            case None => laidOutRect
        }
    }

    func noteDamage(): Unit {
        let rect = automaticPaintRect()
        if (rect.w > 0.0 && rect.h > 0.0) {
            invalidateDamage(rect.inset(-CUI_SHADOW_CLEARANCE))
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
        let commandCount = match (paintCommands) {
            case Some(value) => value.stats().commandCount
            case None => 0
        }
        let estimatedBytes = match (paintCommands) {
            case Some(value) => value.stats().estimatedBytes
            case None => UInt64(0)
        }
        AutomaticRenderStats(1, layoutHits, paintHits, paintRecordAttempts, paintDynamicBypasses,
            paintRejectedCandidates, paintBudgetEvictions, commandCount, estimatedBytes, paintBypassRemaining)
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
        paintCommands = None
        paintBounds = None
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

/* One existing proxy update, staged until the root composition transaction commits. */
class PendingAutomaticRenderUpdate {
    let node: AutomaticRenderNode
    let child: Widget

    init(node: AutomaticRenderNode, child: Widget) {
        this.node = node
        this.child = child
    }

    func commit(): Unit {
        node.update(child)
    }
}

/* Reconciliation output and deferred mutations for one automatic composition record. */
class AutomaticRenderReconciliation {
    let children: Array<Widget>
    private let updates: Array<PendingAutomaticRenderUpdate>
    private let removed: Array<AutomaticRenderNode>

    init(
        children: Array<Widget>,
        updates: Array<PendingAutomaticRenderUpdate>,
        removed: Array<AutomaticRenderNode>
    ) {
        this.children = children
        this.updates = updates
        this.removed = removed
    }

    func commit(): Unit {
        for (update in updates) {
            update.commit()
        }
        for (node in removed) {
            node.close()
        }
    }
}

func wrapAutomaticChildren(
    children: Array<Widget>,
    paintBudget: AutomaticPaintBudget,
    invalidateComposition: () -> Unit,
    invalidateDamage: (Rect) -> Unit
): Array<Widget> {
    Array<Widget>(children.size,
        {index => AutomaticRenderNode(children[index], paintBudget, invalidateComposition, invalidateDamage)})
}

func reconcileAutomaticChildren(
    previous: Array<Widget>,
    next: Array<Widget>,
    paintBudget: AutomaticPaintBudget,
    invalidateComposition: () -> Unit,
    invalidateDamage: (Rect) -> Unit
): AutomaticRenderReconciliation {
    let children = ArrayList<Widget>()
    let updates = ArrayList<PendingAutomaticRenderUpdate>()
    let removed = ArrayList<AutomaticRenderNode>()
    var index: Int64 = 0
    while (index < next.size) {
        if (index < previous.size) {
            match (previous[index] as AutomaticRenderNode) {
                case Some(node) =>
                    children.add(node)
                    updates.add(PendingAutomaticRenderUpdate(node, next[index]))
                case None => children.add(
                    AutomaticRenderNode(next[index], paintBudget, invalidateComposition, invalidateDamage))
            }
        } else {
            children.add(AutomaticRenderNode(next[index], paintBudget, invalidateComposition, invalidateDamage))
        }
        index += 1
    }
    while (index < previous.size) {
        match (previous[index] as AutomaticRenderNode) {
            case Some(node) => removed.add(node)
            case None => ()
        }
        index += 1
    }
    AutomaticRenderReconciliation(children.toArray(), updates.toArray(), removed.toArray())
}

func closeAutomaticRenderChildren(children: Array<Widget>): Unit {
    for (child in children) {
        match (child as AutomaticRenderNode) {
            case Some(node) => node.close()
            case None => ()
        }
    }
}

func automaticRenderNodes(children: Array<Widget>): Array<AutomaticRenderNode> {
    let result = ArrayList<AutomaticRenderNode>()
    for (child in children) {
        match (child as AutomaticRenderNode) {
            case Some(node) => result.add(node)
            case None => ()
        }
    }
    result.toArray()
}
