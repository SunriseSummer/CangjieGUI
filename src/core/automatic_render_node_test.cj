package cui.core

import sdl.{Color, Rect, Renderer, Size, UiEvent}

private class AutomaticRenderValueObservation {
    var lastDrawn: Int64 = -1
}

private class AutomaticRenderValueProbe <: Widget {
    private let value: Int64
    private let observation: AutomaticRenderValueObservation

    init(value: Int64, observation: AutomaticRenderValueObservation) {
        this.value = value
        this.observation = observation
        emit(this)
    }

    public func measure(_: UiContext, available: Size): Size {
        available
    }

    public func layout(_: UiContext, _: Rect): Unit {}

    public func draw(_: UiContext): Unit {
        observation.lastDrawn = value
    }

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }
}

private class AutomaticRenderFixedProbe <: Widget {
    init() {
        emit(this)
    }

    public func measure(_: UiContext, available: Size): Size {
        Size(min(40.0, available.w), min(40.0, available.h))
    }

    public func layout(_: UiContext, _: Rect): Unit {}

    public func draw(_: UiContext): Unit {}

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }
}

private class AutomaticMeasureEnvironmentObservation {
    var measures: Int64 = 0
    var layouts: Int64 = 0
}

private class AutomaticMeasureEnvironmentProbe <: Widget {
    private let observation: AutomaticMeasureEnvironmentObservation
    var fail = false

    init(observation: AutomaticMeasureEnvironmentObservation) {
        this.observation = observation
    }

    public func measure(ctx: UiContext, available: Size): Size {
        observation.measures += 1
        if (fail) {
            throw IllegalStateException("automatic measure failed")
        }
        Size(min(ctx.resolve(Length(10.0, LengthUnit.Fp)), available.w), min(10.0, available.h))
    }

    public func layout(_: UiContext, _: Rect): Unit {
        observation.layouts += 1
    }

    public func draw(_: UiContext): Unit {}

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }
}

private class ScenePatchVisitCounter {
    var value: Int64 = 0
}

@Test
func automaticMeasureCacheKeysContextIdentityAndScaleRevision(): Unit {
    let observation = AutomaticMeasureEnvironmentObservation()
    let node = AutomaticRenderNode(AutomaticMeasureEnvironmentProbe(observation), AutomaticPaintBudget(),
        {_: Rect => ()})
    let available = Size(100.0, 40.0)
    let rect = Rect(0.0, 0.0, 100.0, 40.0)
    let firstContext = UiContext(Renderer.headless(), Theme.light())

    @Expect(node.measure(firstContext, available).w, Float32(10.0))
    node.layout(firstContext, rect)
    @Expect(node.measure(firstContext, available).w, Float32(10.0))
    node.layout(firstContext, rect)
    @Expect(observation.measures, Int64(1))
    @Expect(observation.layouts, Int64(1))

    firstContext.fontScale = 2.0
    @Expect(node.measure(firstContext, available).w, Float32(20.0))
    node.layout(firstContext, rect)
    firstContext.fontScale = 2.0
    @Expect(node.measure(firstContext, available).w, Float32(20.0))
    @Expect(observation.measures, Int64(2))
    @Expect(observation.layouts, Int64(2))

    let secondContext = UiContext(Renderer.headless(), Theme.light())
    secondContext.fontScale = 2.0
    @Expect(node.measure(secondContext, available).w, Float32(20.0))
    node.layout(secondContext, rect)
    @Expect(observation.measures, Int64(3))
    @Expect(observation.layouts, Int64(3))
    node.close()
}

@Test
func failedAutomaticMeasurePreservesCommittedElementMemo(): Unit {
    let observation = AutomaticMeasureEnvironmentObservation()
    let probe = AutomaticMeasureEnvironmentProbe(observation)
    let node = AutomaticRenderNode(probe, AutomaticPaintBudget(), {_: Rect => ()})
    let context = UiContext(Renderer.headless(), Theme.light())
    let committedAvailable = Size(100.0, 40.0)
    @Expect(node.measure(context, committedAvailable).w, Float32(10.0))

    probe.fail = true
    var failed = false
    try {
        let _ = node.measure(context, Size(80.0, 40.0))
    } catch (_: IllegalStateException) {
        failed = true
    }
    @Expect(failed)

    probe.fail = false
    @Expect(node.measure(context, committedAvailable).w, Float32(10.0))
    @Expect(observation.measures, Int64(2))
    node.close()
}

private class ScenePatchDrawProbe <: Widget {
    private let state: State<Int64>
    private let visits: ScenePatchVisitCounter
    private var frame = Rect.zero()

    init(state: State<Int64>, visits: ScenePatchVisitCounter) {
        this.state = state
        this.visits = visits
    }

    public func measure(_: UiContext, available: Size): Size {
        available
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        let value = state.value
        visits.value += 1
        for (index in 0..24) {
            ctx.renderer.fill(Rect(frame.x + Float32(index), frame.y, 1.0, 1.0),
                Color.rgb(value % 255, index % 255, 20))
        }
    }

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }
}

private class ScenePatchParentProbe <: Widget {
    private let first: AutomaticRenderNode
    private let second: AutomaticRenderNode
    private var frame = Rect.zero()

    init(first: AutomaticRenderNode, second: AutomaticRenderNode) {
        this.first = first
        this.second = second
    }

    public func measure(ctx: UiContext, available: Size): Size {
        let _ = first.measure(ctx, available)
        let _ = second.measure(ctx, available)
        available
    }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        frame = rect
        first.layout(ctx, rect)
        second.layout(ctx, rect)
    }

    public func draw(ctx: UiContext): Unit {
        for (index in 0..22) {
            ctx.renderer.fill(Rect(frame.x + Float32(index), frame.y + 2.0, 1.0, 1.0),
                Color.rgb(index % 255, 10, 30))
        }
        first.draw(ctx)
        second.draw(ctx)
    }

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }
}

private class SemanticClipLayoutProbe <: Widget {
    public func measure(_: UiContext, available: Size): Size {
        available
    }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        ctx.registerSemantics(SemanticsNode("clip-probe", Semantics(label: "Clip probe"), rect))
    }

    public func draw(_: UiContext): Unit {}

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }
}

private class SceneDamageTextProbe <: Widget {
    private let text: String
    private var frame = Rect.zero()

    init(text: String) {
        this.text = text
    }

    public func measure(_: UiContext, available: Size): Size {
        available
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        for (index in 0..24) {
            ctx.renderer.text(text, frame.x + Float32(index), frame.y, Color.rgb(20, 30, 40))
        }
    }

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }
}

private class SceneDamageParentProbe <: Widget {
    private let first: AutomaticRenderNode
    private let second: AutomaticRenderNode
    private var frame = Rect.zero()

    init(first: AutomaticRenderNode, second: AutomaticRenderNode) {
        this.first = first
        this.second = second
    }

    public func measure(ctx: UiContext, available: Size): Size {
        let half = Size(available.w / 2.0, available.h)
        let _ = first.measure(ctx, half)
        let _ = second.measure(ctx, half)
        available
    }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        frame = rect
        let half = rect.w / 2.0
        first.layout(ctx, Rect(rect.x, rect.y, half, rect.h))
        second.layout(ctx, Rect(rect.x + half, rect.y, rect.w - half, rect.h))
    }

    public func draw(ctx: UiContext): Unit {
        for (index in 0..22) {
            ctx.renderer.fill(Rect(frame.x + Float32(index), frame.y, 1.0, 1.0), Color.rgb(10, 20, 30))
        }
        first.draw(ctx)
        second.draw(ctx)
    }

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }
}

@Test
func failedAutomaticReconciliationKeepsCommittedRenderChild(): Unit {
    let store = StateStore()
    enableAutomaticComposition(store)
    let version = State<Int64>(1)
    let observation = AutomaticRenderValueObservation()
    let context = UiContext(Renderer.headless(), Theme.light())
    let committed = buildRoot({=> AutomaticRenderValueProbe(version.value, observation)}, store)
    committed.draw(context)
    @Expect(observation.lastDrawn, Int64(1))

    version.value = 2
    var rejected = false
    try {
        let _ = buildRoot(
            {
                =>
                    AutomaticRenderValueProbe(version.value, observation)
                    throw IllegalStateException("fail after staged render update")
            },
            store
        )
    } catch (_: IllegalStateException) {
        rejected = true
    }
    @Expect(rejected)
    committed.draw(context)
    @Expect(observation.lastDrawn, Int64(1))

    let replaced = buildRoot({=> AutomaticRenderValueProbe(version.value, observation)}, store)
    replaced.draw(context)
    @Expect(observation.lastDrawn, Int64(2))
}

@Test
func automaticPaintBudgetEvictsLeastRecentlyUsedEntry(): Unit {
    let budget = AutomaticPaintBudget(limitBytes: UInt64(160))
    let noDamage = {_: Rect => ()}
    let first = AutomaticRenderNode(EmptyView(), budget, noDamage)
    let second = AutomaticRenderNode(EmptyView(), budget, noDamage)
    let third = AutomaticRenderNode(EmptyView(), budget, noDamage)

    @Expect(budget.admit(first, UInt64(80)))
    @Expect(budget.admit(second, UInt64(80)))
    budget.touch(first)
    @Expect(budget.admit(third, UInt64(80)))

    @Expect(first.paintBudgetBytes(), UInt64(80))
    @Expect(second.paintBudgetBytes(), UInt64(0))
    @Expect(second.stats().paintBudgetEvictions, UInt64(1))
    @Expect(third.paintBudgetBytes(), UInt64(80))
}

@Test
func cancelledAutomaticRenderReconciliationReleasesOnlyStagedSceneSlots(): Unit {
    let arena = ElementArena()
    let owner = arena.mount("reconcile-owner", arena.rootId, ElementKind.Automatic)
    let scene = arena.sceneFacet(owner)
    let budget = AutomaticPaintBudget()
    let noDamage = {_: Rect => ()}
    let previous = wrapAutomaticChildren([EmptyView()], scene, budget, noDamage)
    let staged = reconcileAutomaticChildren(previous, [EmptyView(), EmptyView()], scene, budget, noDamage)
    @Expect(scene.liveCount(), Int64(2))

    staged.cancel()
    @Expect(scene.liveCount(), Int64(1))
    closeAutomaticRenderChildren(previous)
    @Expect(scene.liveCount(), Int64(0))
    arena.release(owner)
}

@Test
func automaticRootReplacementDoesNotWidenExplicitRetainedDamage(): Unit {
    let store = StateStore()
    enableAutomaticComposition(store)
    let changed = State<Int64>(0)
    let context = UiContext(Renderer.headless(), Theme.light())
    let viewport = Rect(0.0, 0.0, 160.0, 64.0)
    let body: () -> Unit = {
        => HStack {
            RetainedSubtree("left") {
                let _ = changed.value
                AutomaticRenderFixedProbe()
            }
            RetainedSubtree("right") {AutomaticRenderFixedProbe()}
        }
    }
    let initial = buildRoot(body, store)
    initial.layout(context, viewport)
    consumeFullRetainedFrameDamage(store)

    changed.value = 1
    let updated = buildRoot(body, store)
    updated.layout(context, viewport)
    match (takeRetainedFrameDamage(store, viewport, true)) {
        case RetainedFrameDamage.Region(damage) => @Expect(damage.w * damage.h < viewport.w * viewport.h * 0.70)
        case RetainedFrameDamage.FullFrame => @Fail("automatic root replacement widened explicit local damage")
    }
}

@Test
func hierarchicalScenePatchRedrawsDirtyChildWithoutFlatteningCleanSibling(): Unit {
    let budget = AutomaticPaintBudget()
    let noDamage = {_: Rect => ()}
    let firstState = State<Int64>(1)
    let secondState = State<Int64>(2)
    let firstVisits = ScenePatchVisitCounter()
    let secondVisits = ScenePatchVisitCounter()
    let first = AutomaticRenderNode(ScenePatchDrawProbe(firstState, firstVisits), budget, noDamage)
    let second = AutomaticRenderNode(ScenePatchDrawProbe(secondState, secondVisits), budget, noDamage)
    let root = AutomaticRenderNode(ScenePatchParentProbe(first, second), budget, noDamage)
    let context = UiContext(Renderer.headless(), Theme.light())
    let rect = Rect(0.0, 0.0, 100.0, 40.0)
    let _ = root.measure(context, Size(rect.w, rect.h))
    root.layout(context, rect)
    for (_ in 0..4) {
        root.draw(context)
    }
    let stableFirst = firstVisits.value
    let stableSecond = secondVisits.value
    @Expect(root.stats().paintCommandCount, Int64(24))

    firstState.value = 3
    root.draw(context)
    @Expect(firstVisits.value, stableFirst + 1)
    @Expect(secondVisits.value, stableSecond)
    @Expect(root.stats().paintCommandCount, Int64(24))

    root.close()
    first.close()
    second.close()
}

@Test
func automaticLayoutCacheIncludesAncestorSemanticClip(): Unit {
    let context = UiContext(Renderer.headless(), Theme.light())
    let noDamage = {_: Rect => ()}
    let node = AutomaticRenderNode(SemanticClipLayoutProbe(), AutomaticPaintBudget(), noDamage)
    let bounds = Rect(0.0, 0.0, 100.0, 100.0)

    context.clearSemantics()
    context.withSemanticClip(Rect(0.0, 0.0, 100.0, 40.0)) {=> node.layout(context, bounds)}
    context.commitSemantics()
    @Expect(context.semanticsTreeSnapshot().node("clip-probe").getOrThrow().visibleBounds.bottom(), Float32(40.0))

    context.clearSemantics()
    context.withSemanticClip(Rect(0.0, 0.0, 100.0, 60.0)) {=> node.layout(context, bounds)}
    context.commitSemantics()
    @Expect(context.semanticsTreeSnapshot().node("clip-probe").getOrThrow().visibleBounds.bottom(), Float32(60.0))
    node.close()
}

@Test
func hierarchicalSceneDamageReplaysOnlyIntersectingChildSlot(): Unit {
    let budget = AutomaticPaintBudget()
    let noDamage = {_: Rect => ()}
    let first = AutomaticRenderNode(SceneDamageTextProbe("left"), budget, noDamage)
    let second = AutomaticRenderNode(SceneDamageTextProbe("right"), budget, noDamage)
    let root = AutomaticRenderNode(SceneDamageParentProbe(first, second), budget, noDamage)
    let renderer = Renderer.headless()
    let context = UiContext(renderer, Theme.light())
    let rect = Rect(0.0, 0.0, 200.0, 40.0)
    let _ = root.measure(context, Size(rect.w, rect.h))
    root.layout(context, rect)
    for (_ in 0..4) {
        root.draw(context)
    }
    @Expect(root.stats().paintCommandCount, Int64(24))

    let beforeDamage = renderer.textDrawCount()
    context.setRetainedDamage(Some(Rect(0.0, 0.0, 90.0, 40.0)))
    root.draw(context)
    context.setRetainedDamage(None)
    @Expect(renderer.textDrawCount() - beforeDamage, UInt64(24))

    let beforeFull = renderer.textDrawCount()
    root.draw(context)
    @Expect(renderer.textDrawCount() - beforeFull, UInt64(48))

    root.close()
    first.close()
    second.close()
}
