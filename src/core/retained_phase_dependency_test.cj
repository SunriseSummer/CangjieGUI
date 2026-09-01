package cui.core

import sdl.{Color, Rect, Size, SdlWindow, UiEvent, WindowSpec}

private class PhaseVisitCounter {
    var measures: Int64 = 0
    var layouts: Int64 = 0
    var draws: Int64 = 0
}

private class PhaseDependencyProbe <: Widget {
    private let measureState: State<Int64>
    private let layoutState: State<Int64>
    private let paintState: State<Int64>
    private let visits: PhaseVisitCounter

    init(
        measureState: State<Int64>,
        layoutState: State<Int64>,
        paintState: State<Int64>,
        visits: PhaseVisitCounter
    ) {
        this.measureState = measureState
        this.layoutState = layoutState
        this.paintState = paintState
        this.visits = visits
        emit(this)
    }

    public func measure(_: UiContext, available: Size): Size {
        visits.measures += 1
        let _ = measureState.value
        available
    }

    public func layout(_: UiContext, _: Rect): Unit {
        visits.layouts += 1
        let _ = layoutState.value
    }

    public func draw(_: UiContext): Unit {
        visits.draws += 1
        let _ = paintState.value
    }

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }
}

private class RetainedMeasureEnvironmentProbe <: Widget {
    private let visits: PhaseVisitCounter
    var fail = false

    init(visits: PhaseVisitCounter) {
        this.visits = visits
    }

    public func measure(ctx: UiContext, available: Size): Size {
        visits.measures += 1
        if (fail) {
            throw IllegalStateException("retained measure failed")
        }
        Size(min(ctx.resolve(Length(12.0, LengthUnit.Fp)), available.w), min(12.0, available.h))
    }

    public func layout(_: UiContext, _: Rect): Unit {
        visits.layouts += 1
    }

    public func draw(_: UiContext): Unit {}

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }
}

private class SelfWritingMeasureProbe <: Widget {
    private let source: State<Int64>
    private let visits: PhaseVisitCounter

    init(source: State<Int64>, visits: PhaseVisitCounter) {
        this.source = source
        this.visits = visits
    }

    public func measure(_: UiContext, available: Size): Size {
        visits.measures += 1
        if (source.value == 0) {
            source.value = 1
        }
        available
    }

    public func layout(_: UiContext, _: Rect): Unit {}

    public func draw(_: UiContext): Unit {}

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }
}

private class TransactionalLayoutProbe <: Widget {
    private let primary: State<Int64>
    private let abandoned: State<Int64>
    private let visits: PhaseVisitCounter
    var useAbandoned = false
    var fail = false

    init(primary: State<Int64>, abandoned: State<Int64>, visits: PhaseVisitCounter) {
        this.primary = primary
        this.abandoned = abandoned
        this.visits = visits
        emit(this)
    }

    public func measure(_: UiContext, available: Size): Size {
        available
    }

    public func layout(_: UiContext, _: Rect): Unit {
        visits.layouts += 1
        if (useAbandoned) {
            let _ = abandoned.value
        } else {
            let _ = primary.value
        }
        if (fail) {
            throw IllegalStateException("phase dependency probe layout failure")
        }
    }

    public func draw(_: UiContext): Unit {}

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }
}

@Test
func retainedMeasureCacheKeysContextIdentityAndScaleRevision(): Unit {
    let visits = PhaseVisitCounter()
    let record = RetainedRecord(UInt64(0), false, RetainedMeasureEnvironmentProbe(visits))
    let available = Size(100.0, 40.0)
    let rect = Rect(0.0, 0.0, 100.0, 40.0)
    let firstContext = testContext()

    @Expect(record.measure(firstContext, available).w, Float32(12.0))
    record.layout(firstContext, rect)
    @Expect(record.measure(firstContext, available).w, Float32(12.0))
    record.layout(firstContext, rect)
    @Expect(visits.measures, Int64(1))
    @Expect(visits.layouts, Int64(1))

    firstContext.fontScale = 2.0
    @Expect(record.measure(firstContext, available).w, Float32(24.0))
    record.layout(firstContext, rect)
    @Expect(record.measure(firstContext, available).w, Float32(24.0))
    @Expect(visits.measures, Int64(2))
    @Expect(visits.layouts, Int64(2))

    let secondContext = testContext()
    secondContext.fontScale = 2.0
    @Expect(record.measure(secondContext, available).w, Float32(24.0))
    record.layout(secondContext, rect)
    @Expect(visits.measures, Int64(3))
    @Expect(visits.layouts, Int64(3))
    record.close()
}

@Test
func failedRetainedMeasurePreservesCommittedElementMemo(): Unit {
    let visits = PhaseVisitCounter()
    let probe = RetainedMeasureEnvironmentProbe(visits)
    let record = RetainedRecord(UInt64(0), false, probe)
    let context = testContext()
    let committedAvailable = Size(100.0, 40.0)
    @Expect(record.measure(context, committedAvailable).w, Float32(12.0))

    probe.fail = true
    var failed = false
    try {
        let _ = record.measure(context, Size(80.0, 40.0))
    } catch (_: IllegalStateException) {
        failed = true
    }
    @Expect(failed)

    probe.fail = false
    @Expect(record.measure(context, committedAvailable).w, Float32(12.0))
    @Expect(visits.measures, Int64(2))
    record.close()
}

@Test
func stateWriteDuringMeasureCannotPublishStaleElementMemo(): Unit {
    let source = State<Int64>(0)
    let visits = PhaseVisitCounter()
    let record = RetainedRecord(UInt64(0), false, SelfWritingMeasureProbe(source, visits))
    let context = testContext()
    let available = Size(100.0, 40.0)

    let _ = record.measure(context, available)
    @Expect(source.value, Int64(1))
    @Expect(visits.measures, Int64(1))
    let _ = record.measure(context, available)
    @Expect(visits.measures, Int64(2))
    let _ = record.measure(context, available)
    @Expect(visits.measures, Int64(2))
    record.close()
}

private class SelfWritingLayoutProbe <: Widget {
    private let source: State<Int64>
    private let visits: PhaseVisitCounter

    init(source: State<Int64>, visits: PhaseVisitCounter) {
        this.source = source
        this.visits = visits
        emit(this)
    }

    public func measure(_: UiContext, available: Size): Size {
        available
    }

    public func layout(_: UiContext, _: Rect): Unit {
        visits.layouts += 1
        if (source.value == 0) {
            source.value = 1
        }
    }

    public func draw(_: UiContext): Unit {}

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }
}

private class SelfWritingPaintProbe <: Widget {
    private let source: State<Int64>
    private let visits: PhaseVisitCounter

    init(source: State<Int64>, visits: PhaseVisitCounter) {
        this.source = source
        this.visits = visits
        emit(this)
    }

    public func measure(_: UiContext, available: Size): Size {
        available
    }

    public func layout(_: UiContext, _: Rect): Unit {}

    public func draw(_: UiContext): Unit {
        visits.draws += 1
        if (source.value == 0) {
            source.value = 1
        }
    }

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }
}

@Test
func retainedMeasureAndLayoutDependenciesInvalidateOnlyRequiredPhases(): Unit {
    let store = StateStore()
    let ctx = testContext()
    let measureState = State<Int64>(0)
    let layoutState = State<Int64>(0)
    let paintState = State<Int64>(0)
    let visits = PhaseVisitCounter()
    let body: () -> Unit = {
        => RetainedSubtree("phase-dependencies") {
            PhaseDependencyProbe(measureState, layoutState, paintState, visits)
        }
    }
    let available = Size(180.0, 90.0)
    let rect = Rect(0.0, 0.0, 180.0, 90.0)

    let first = buildRoot(body, store)
    let _ = first.measure(ctx, available)
    first.layout(ctx, rect)
    let second = buildRoot(body, store)
    let _ = second.measure(ctx, available)
    second.layout(ctx, rect)
    @Expect(visits.measures, Int64(1))
    @Expect(visits.layouts, Int64(1))

    layoutState.value = 1
    let third = buildRoot(body, store)
    let _ = third.measure(ctx, available)
    third.layout(ctx, rect)
    @Expect(visits.measures, Int64(1))
    @Expect(visits.layouts, Int64(2))

    measureState.value = 1
    let fourth = buildRoot(body, store)
    let _ = fourth.measure(ctx, available)
    fourth.layout(ctx, rect)
    @Expect(visits.measures, Int64(2))
    @Expect(visits.layouts, Int64(3))
}

@Test
func nestedLayoutDependencyInvalidatesCleanRetainedParent(): Unit {
    let store = StateStore()
    let ctx = testContext()
    let geometry = State<Int64>(0)
    let inert = State<Int64>(0)
    let visits = PhaseVisitCounter()
    let body: () -> Unit = {
        => RetainedSubtree("phase-parent") {
            RetainedSubtree("phase-child") {
                PhaseDependencyProbe(inert, geometry, inert, visits)
            }
        }
    }
    let rect = Rect(0.0, 0.0, 200.0, 100.0)

    let first = buildRoot(body, store)
    first.layout(ctx, rect)
    let second = buildRoot(body, store)
    second.layout(ctx, rect)
    @Expect(visits.layouts, Int64(1))

    geometry.value = 1
    let third = buildRoot(body, store)
    third.layout(ctx, rect)
    @Expect(visits.layouts, Int64(2))
}

@Test
func failedLayoutCollectionPreservesCommittedDependencies(): Unit {
    let store = StateStore()
    let ctx = testContext()
    let primary = State<Int64>(0)
    let abandoned = State<Int64>(0)
    let visits = PhaseVisitCounter()
    let captured = State<?TransactionalLayoutProbe>(None)
    let body: () -> Unit = {
        => RetainedSubtree("phase-transaction") {
            let probe = TransactionalLayoutProbe(primary, abandoned, visits)
            captured.value = Some(probe)
        }
    }
    let firstRect = Rect(0.0, 0.0, 100.0, 50.0)
    let secondRect = Rect(0.0, 0.0, 110.0, 50.0)

    let first = buildRoot(body, store)
    first.layout(ctx, firstRect)
    let probe = captured.value.getOrThrow()
    probe.useAbandoned = true
    probe.fail = true
    var rejected = false
    try {
        first.layout(ctx, secondRect)
    } catch (_: IllegalStateException) {
        rejected = true
    }
    probe.useAbandoned = false
    probe.fail = false
    first.layout(ctx, secondRect)
    abandoned.value = 1
    first.layout(ctx, secondRect)

    @Expect(rejected)
    @Expect(visits.layouts, Int64(3))
}

@Test
func stateWriteDuringLayoutPreventsFalseCacheHit(): Unit {
    let store = StateStore()
    let ctx = testContext()
    let source = State<Int64>(0)
    let visits = PhaseVisitCounter()
    let widget = buildRoot({=> RetainedSubtree("self-writing-layout") {
        SelfWritingLayoutProbe(source, visits)
    }}, store)
    let rect = Rect(0.0, 0.0, 100.0, 50.0)

    widget.layout(ctx, rect)
    widget.layout(ctx, rect)
    widget.layout(ctx, rect)

    @Expect(visits.layouts, Int64(2))
}

@Test
func stateWriteDuringRetainedLayoutDoesNotPublishUncommittedElementGeometry(): Unit {
    let arena = ElementArena()
    let owner = arena.mount("retained-layout-transaction", arena.rootId, ElementKind.Retained)
    let sceneNode = arena.sceneFacet(owner).acquire(0)
    let source = State<Int64>(0)
    let visits = PhaseVisitCounter()
    let record = RetainedRecord(UInt64(0), false, SelfWritingLayoutProbe(source, visits), StateMountScope(), [],
        emptyFrameSubscriptionSnapshot(), sceneNode)
    let context = testContext()

    record.layout(context, Rect(10.0, 20.0, 100.0, 40.0))

    let snapshot = arena.spaceFacet(owner).resolveScene(sceneNode.id).getOrThrow().snapshot()
    @Expect(sameAutomaticRect(snapshot.layoutBounds, Rect.zero()))
    record.close()
    arena.release(owner)
}

@Test
func retainedPaintDependencyInvalidatesCachedTexture(): Unit {
    let window = SdlWindow(WindowSpec("Retained phase paint", 160, 90, vsync: false, supersample: 2))
    let store = StateStore()
    try {
        let ctx = UiContext(window.renderer, Theme.light())
        let inert = State<Int64>(0)
        let paint = State<Int64>(0)
        let visits = PhaseVisitCounter()
        let rect = Rect(0.0, 0.0, 160.0, 90.0)
        let body: () -> Unit = {
            => RetainedSubtree("phase-paint", cachePaint: true) {
                PhaseDependencyProbe(inert, inert, paint, visits)
            }
        }

        let first = buildRoot(body, store)
        first.layout(ctx, rect)
        window.renderer.beginScene(160.0, 90.0, Color.rgb(20, 30, 40))
        first.draw(ctx)
        window.renderer.endScene()

        let second = buildRoot(body, store)
        second.layout(ctx, rect)
        window.renderer.beginScene(160.0, 90.0, Color.rgb(20, 30, 40))
        second.draw(ctx)
        window.renderer.endScene()
        @Expect(visits.draws, Int64(1))

        paint.value = 1
        let third = buildRoot(body, store)
        third.layout(ctx, rect)
        window.renderer.beginScene(160.0, 90.0, Color.rgb(20, 30, 40))
        third.draw(ctx)
        window.renderer.endScene()
        @Expect(visits.draws, Int64(2))
    } finally {
        store.clear()
        window.close()
    }
}

@Test
func stateWriteDuringPaintDoesNotSnapshotStaleResult(): Unit {
    let window = SdlWindow(WindowSpec("Retained self-writing paint", 120, 70, vsync: false, supersample: 2))
    let store = StateStore()
    try {
        let ctx = UiContext(window.renderer, Theme.light())
        let source = State<Int64>(0)
        let visits = PhaseVisitCounter()
        let rect = Rect(0.0, 0.0, 120.0, 70.0)
        let widget = buildRoot({=> RetainedSubtree("self-writing-paint", cachePaint: true) {
            SelfWritingPaintProbe(source, visits)
        }}, store)
        widget.layout(ctx, rect)

        window.renderer.beginScene(120.0, 70.0, Color.rgb(10, 20, 30))
        widget.draw(ctx)
        widget.draw(ctx)
        widget.draw(ctx)
        window.renderer.endScene()

        @Expect(visits.draws, Int64(2))
    } finally {
        store.clear()
        window.close()
    }
}
