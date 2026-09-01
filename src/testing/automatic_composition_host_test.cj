package cui.testing

import sdl.{Color, Rect, Size, UiEvent}
import cui.core.{AutomaticScopeDiagnostics, HStack, Label, Observable, Overlay, Panel, RetainedSubtree, Spacer, State,
    UiContext, VStack, Widget, derive, emit}

private class AutomaticBuildObservation {
    var calls: Int64 = 0
    var lastValue: Int64 = -1

    func record(value: Int64): Unit {
        calls += 1
        lastValue = value
    }
}

private class AutomaticPhaseObservation {
    var measures: Int64 = 0
    var layouts: Int64 = 0
    var draws: Int64 = 0
    var paintValue: Int64 = -1
}

private class AutomaticPhaseProbe <: Widget {
    private let measureState: State<Int64>
    private let layoutState: State<Int64>
    private let paintState: State<Int64>
    private let observation: AutomaticPhaseObservation

    init(measureState: State<Int64>, layoutState: State<Int64>, paintState: State<Int64>,
        observation: AutomaticPhaseObservation) {
        this.measureState = measureState
        this.layoutState = layoutState
        this.paintState = paintState
        this.observation = observation
        emit(this)
    }

    public func measure(_: UiContext, available: Size): Size {
        observation.measures += 1
        let _ = measureState.value
        available
    }

    public func layout(_: UiContext, _: Rect): Unit {
        observation.layouts += 1
        let _ = layoutState.value
    }

    public func draw(_: UiContext): Unit {
        observation.draws += 1
        observation.paintValue = paintState.value
    }

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }
}

private class AutomaticCommandPaintProbe <: Widget {
    private let paintState: State<Int64>
    private let observation: AutomaticBuildObservation
    private let dynamic: Bool
    private var frame = Rect.zero()

    init(paintState: State<Int64>, observation: AutomaticBuildObservation, dynamic!: Bool = false) {
        this.paintState = paintState
        this.observation = observation
        this.dynamic = dynamic
        emit(this)
    }

    public func measure(_: UiContext, available: Size): Size {
        available
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        observation.record(paintState.value)
        if (dynamic) {
            ctx.requestFrame()
        }
        for (index in 0..32) {
            ctx.renderer.fill(Rect(frame.x + Float32(index), frame.y, 1.0, 1.0), Color.rgb(20, 30, 40))
        }
    }

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }
}

private class AutomaticOverlayProbe <: Widget {
    private let observation: AutomaticBuildObservation

    init(observation: AutomaticBuildObservation) {
        this.observation = observation
        emit(this)
    }

    public func measure(_: UiContext, available: Size): Size {
        available
    }

    public func layout(ctx: UiContext, _: Rect): Unit {
        observation.record(0)
        ctx.setOverlay(Overlay(handleEvent: {_, _ => false}, render: {_ => ()}, owner: "automatic-overlay"))
    }

    public func draw(_: UiContext): Unit {}

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }
}

@Test
func ordinaryDeclarativeBodyIsAutomaticallyReusedWhenClean(): Unit {
    let host = WidgetTestHost()
    let builds = AutomaticBuildObservation()
    let body: () -> Unit = {
        =>
            builds.record(0)
            VStack {Label("stable")}
    }
    let rect = Rect(0.0, 0.0, 200.0, 80.0)
    let _ = host.frame(rect, body: body)
    let _ = host.frame(rect, body: body)

    @Expect(builds.calls, Int64(1))
    let diagnostics = host.retainedDiagnostics()
    @Expect(diagnostics.automaticScopes.size > 0)
    @Expect(automaticBuildHits(diagnostics.automaticScopes) > UInt64(0))
    @Expect(diagnostics.describe().contains("automatic-scopes="))
}

@Test
func automaticCompositionRebuildsDirtyPathButSkipsCleanSiblingBody(): Unit {
    let host = WidgetTestHost()
    let value = State<Int64>(0)
    let rootBuilds = AutomaticBuildObservation()
    let changedBuilds = AutomaticBuildObservation()
    let stableBuilds = AutomaticBuildObservation()
    let body: () -> Unit = {
        =>
            rootBuilds.record(0)
            VStack {
                HStack {
                    changedBuilds.record(value.value)
                    Label("changed ${value.value}")
                }
                HStack {
                    stableBuilds.record(0)
                    Label("stable")
                }
            }
    }
    let rect = Rect(0.0, 0.0, 240.0, 100.0)
    let _ = host.frame(rect, body: body)
    value.value = 1
    let _ = host.frame(rect, body: body)

    @Expect(rootBuilds.calls, Int64(2))
    @Expect(changedBuilds.calls, Int64(2))
    @Expect(changedBuilds.lastValue, Int64(1))
    @Expect(stableBuilds.calls, Int64(1))
}

@Test
func automaticScopeOwnsOneLazyDerivedDependencyEdge(): Unit {
    let states = Array<State<Int64>>(16, {index => State<Int64>(index)})
    let sources = Array<Observable<Int64>>(states.size, {index => states[index]})
    let computes = AutomaticBuildObservation()
    let total = derive<Int64, Int64>(sources, {
        values =>
            var result: Int64 = 0
            for (value in values) {
                result += value
            }
            computes.record(result)
            result
    })
    let host = WidgetTestHost()
    let body: () -> Unit = {=> Label("${total.value}")}
    let rect = Rect(0.0, 0.0, 200.0, 80.0)

    let _ = host.frame(rect, body: body)
    var maximumDependencies: Int64 = 0
    for (scope in host.retainedDiagnostics().automaticScopes) {
        maximumDependencies = max(maximumDependencies, scope.buildDependencyCount)
    }
    @Expect(maximumDependencies, Int64(1))
    @Expect(computes.calls, Int64(1))

    states[15].value = 100
    @Expect(computes.calls, Int64(1))
    let _ = host.frame(rect, body: body)
    @Expect(computes.calls, Int64(2))
    @Expect(computes.lastValue, Int64(205))
}

@Test
func automaticRootRenderNodeCachesCompositionAndRerunsOnlyDirtyPhase(): Unit {
    let host = WidgetTestHost()
    let measureState = State<Int64>(0)
    let layoutState = State<Int64>(0)
    let paintState = State<Int64>(0)
    let builds = AutomaticBuildObservation()
    let observation = AutomaticPhaseObservation()
    let body: () -> Unit = {
        =>
            builds.record(0)
            VStack {Panel {AutomaticPhaseProbe(measureState, layoutState, paintState, observation)}}
    }
    let rect = Rect(0.0, 0.0, 200.0, 80.0)
    let _ = host.frame(rect, body: body)
    let initialMeasures = observation.measures
    let initialLayouts = observation.layouts
    @Expect(builds.calls, Int64(1))

    let _ = host.frame(rect, body: body)
    @Expect(observation.measures, initialMeasures)
    @Expect(observation.layouts, initialLayouts)
    @Expect(observation.draws, Int64(2))
    @Expect(builds.calls, Int64(1))

    paintState.value = 3
    let _ = host.frame(rect, body: body)
    @Expect(observation.measures, initialMeasures)
    @Expect(observation.layouts, initialLayouts)
    @Expect(observation.paintValue, Int64(3))
    @Expect(builds.calls, Int64(1))

    layoutState.value = 4
    let beforeLayoutMeasures = observation.measures
    let beforeLayoutLayouts = observation.layouts
    let _ = host.frame(rect, body: body)
    @Expect(observation.measures > beforeLayoutMeasures)
    @Expect(observation.layouts > beforeLayoutLayouts)
    @Expect(builds.calls, Int64(1))

    measureState.value = 5
    let beforeMeasureMeasures = observation.measures
    let beforeMeasureLayouts = observation.layouts
    let _ = host.frame(rect, body: body)
    @Expect(observation.measures > beforeMeasureMeasures)
    @Expect(observation.layouts > beforeMeasureLayouts)
    @Expect(builds.calls, Int64(1))
}

@Test
func automaticRenderLayoutHitReplaysOverlayRegistration(): Unit {
    let host = WidgetTestHost()
    let layouts = AutomaticBuildObservation()
    let body: () -> Unit = {=> AutomaticOverlayProbe(layouts)}
    let rect = Rect(0.0, 0.0, 160.0, 60.0)

    let _ = host.frame(rect, body: body)
    @Expect(host.context.overlayCount(), Int64(1))
    let _ = host.frame(rect, body: body)
    @Expect(layouts.calls, Int64(1))
    @Expect(host.context.overlayCount(), Int64(1))
}

@Test
func automaticDisplayListPromotesStableExpensivePaintAndInvalidatesFromState(): Unit {
    let host = WidgetTestHost()
    let paintState = State<Int64>(0)
    let draws = AutomaticBuildObservation()
    let body: () -> Unit = {=> AutomaticCommandPaintProbe(paintState, draws)}
    let rect = Rect(0.0, 0.0, 160.0, 60.0)

    for (_ in 0..5) {
        let _ = host.frame(rect, body: body)
    }
    @Expect(draws.calls, Int64(3))
    let cached = automaticRenderTotals(host.retainedDiagnostics().automaticScopes)
    @Expect(cached[0] > UInt64(0))
    @Expect(cached[1] >= UInt64(2))
    @Expect(cached[2] >= UInt64(24))

    paintState.value = 7
    let _ = host.frame(rect, body: body)
    @Expect(draws.calls, Int64(4))
    @Expect(draws.lastValue, Int64(7))
}

@Test
func automaticDisplayListBacksOffWhenPaintUsesDynamicProtocol(): Unit {
    let host = WidgetTestHost()
    let paintState = State<Int64>(0)
    let draws = AutomaticBuildObservation()
    let body: () -> Unit = {=> AutomaticCommandPaintProbe(paintState, draws, dynamic: true)}
    let rect = Rect(0.0, 0.0, 160.0, 60.0)

    for (_ in 0..12) {
        let _ = host.frame(rect, body: body)
    }
    @Expect(draws.calls, Int64(12))
    let totals = automaticRenderTotals(host.retainedDiagnostics().automaticScopes)
    @Expect(totals[1], UInt64(0))
    @Expect(totals[3], UInt64(1))
    @Expect(totals[4], UInt64(1))
}

@Test
func nestedAutomaticDisplayListInvalidationPropagatesToCachedRoot(): Unit {
    let host = WidgetTestHost()
    let paintState = State<Int64>(0)
    let draws = AutomaticBuildObservation()
    let body: () -> Unit = {
        => Panel {
            VStack {
                for (_ in 0..18) {
                    Panel {AutomaticCommandPaintProbe(paintState, draws)}
                }
            }
        }
    }
    let rect = Rect(0.0, 0.0, 320.0, 500.0)
    for (_ in 0..5) {
        let _ = host.frame(rect, body: body)
    }
    let cached = automaticRenderTotals(host.retainedDiagnostics().automaticScopes)
    @Expect(cached[0] >= UInt64(2))
    @Expect(cached[2] > UInt64(0))

    paintState.value = 7
    let _ = host.frame(rect, body: body)
    @Expect(draws.lastValue, Int64(7))
}

@Test
func retainedPaintStateInvalidatesCachedAutomaticAncestor(): Unit {
    let host = WidgetTestHost()
    let paintState = State<Int64>(0)
    let draws = AutomaticBuildObservation()
    let body: () -> Unit = {
        => Panel {
            VStack {
                RetainedSubtree("paint-state", cachePaint: true) {
                    AutomaticCommandPaintProbe(paintState, draws)
                }
            }
        }
    }
    let rect = Rect(0.0, 0.0, 320.0, 120.0)
    for (_ in 0..5) {
        let _ = host.frame(rect, body: body)
    }
    let cached = automaticRenderTotals(host.retainedDiagnostics().automaticScopes)
    @Expect(cached[2] > UInt64(0))

    paintState.value = 7
    let _ = host.frame(rect, body: body)
    @Expect(draws.lastValue, Int64(7))
}

@Test
func automaticRenderPromotionSkipsUnchangedComplexSiblingLayout(): Unit {
    let host = WidgetTestHost()
    let changed = State<Int64>(0)
    let stable = AutomaticPhaseObservation()
    let measureState = State<Int64>(0)
    let layoutState = State<Int64>(0)
    let paintState = State<Int64>(0)
    let body: () -> Unit = {
        => VStack {
            Panel {
                VStack {
                    for (_ in 0..18) {
                        Panel {AutomaticPhaseProbe(measureState, layoutState, paintState, stable)}
                    }
                }
            }
            HStack {Label("changed ${changed.value}")}
        }
    }
    let rect = Rect(0.0, 0.0, 320.0, 600.0)
    let _ = host.frame(rect, body: body)
    let initialMeasures = stable.measures
    let initialLayouts = stable.layouts
    changed.value = 1
    let _ = host.frame(rect, body: body)

    @Expect(stable.measures, initialMeasures)
    @Expect(stable.layouts, initialLayouts)
    let totals = automaticRenderTotals(host.retainedDiagnostics().automaticScopes)
    @Expect(totals[0] >= UInt64(2))
}

@Test
func automaticRenderPromotionDoesNotWrapEveryNodeInADeepCheapChain(): Unit {
    let host = WidgetTestHost()
    let _ = host.frame(Rect(0.0, 0.0, 240.0, 400.0)) {buildAutomaticPanelChain(24)}
    let totals = automaticRenderTotals(host.retainedDiagnostics().automaticScopes)

    @Expect(totals[0], UInt64(1))
}

@Test
func automaticPromotedScopeProducesLocalDamageForBuildState(): Unit {
    let host = WidgetTestHost()
    let changed = State<Int64>(0)
    let body: () -> Unit = {
        => VStack {
            Panel(flexible: false) {
                VStack {
                    for (index in 0..18) {
                        Panel {
                            Label(if (index == 0) {
                            "changed ${changed.value}"
                        } else {
                            "stable ${index}"
                        })
                        }
                    }
                }
            }.height(200.0)
            Spacer()
        }
    }
    let viewport = Rect(0.0, 0.0, 400.0, 800.0)
    let _ = host.frame(viewport, body: body)
    changed.value = 1
    let diagnostics = host.retainedDiagnostics()

    @Expect(!diagnostics.fullDamagePending)
    match (diagnostics.pendingDamage) {
        case Some(damage) =>
            @Expect(damage.w > 0.0)
            @Expect(damage.h > 0.0)
            @Expect(damage.w * damage.h < viewport.w * viewport.h * 0.70)
        case None => @Fail("promoted automatic scope should report its previous paint bounds")
    }
}

@Test
func automaticCompositionRefreshesChildrenWhenParentCaptureChanges(): Unit {
    let host = WidgetTestHost()
    let value = State<Int64>(0)
    let childBuilds = AutomaticBuildObservation()
    let body: () -> Unit = {
        => VStack {
            let captured = value.value
            Panel {
                childBuilds.record(captured)
                Label("${captured}")
            }
        }
    }
    let rect = Rect(0.0, 0.0, 200.0, 80.0)
    let _ = host.frame(rect, body: body)
    value.value = 7
    let _ = host.frame(rect, body: body)

    @Expect(childBuilds.calls, Int64(2))
    @Expect(childBuilds.lastValue, Int64(7))
}

private func automaticBuildHits(scopes: Array<AutomaticScopeDiagnostics>): UInt64 {
    var hits = UInt64(0)
    for (scope in scopes) {
        hits += scope.buildHits
    }
    hits
}

// [render nodes, paint hits, cached commands, record attempts, dynamic bypasses]
private func automaticRenderTotals(scopes: Array<AutomaticScopeDiagnostics>): Array<UInt64> {
    let totals = Array<UInt64>(5, repeat: UInt64(0))
    for (scope in scopes) {
        totals[0] += UInt64(scope.renderNodeCount)
        totals[1] += scope.paintHits
        totals[2] += UInt64(scope.paintCommandCount)
        totals[3] += scope.paintRecordAttempts
        totals[4] += scope.paintDynamicBypasses
    }
    totals
}

private func buildAutomaticPanelChain(depth: Int64): Unit {
    if (depth <= 0) {
        Label("leaf")
        return
    }
    Panel {buildAutomaticPanelChain(depth - 1)}
}
