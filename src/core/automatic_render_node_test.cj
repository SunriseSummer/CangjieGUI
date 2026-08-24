package cui.core

import sdl.{Rect, Renderer, Size, UiEvent}

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
    let noCompositionInvalidation = {=> ()}
    let noDamage = {_: Rect => ()}
    let first = AutomaticRenderNode(EmptyView(), budget, noCompositionInvalidation, noDamage)
    let second = AutomaticRenderNode(EmptyView(), budget, noCompositionInvalidation, noDamage)
    let third = AutomaticRenderNode(EmptyView(), budget, noCompositionInvalidation, noDamage)

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
