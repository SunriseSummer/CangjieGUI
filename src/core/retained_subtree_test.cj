package cui.core

import sdl.{Color, Rect, Size, SdlWindow, UiEvent, WindowSpec}

private class RetainedProbe <: Widget {
    private let measures: BuildCounter
    private let layouts: BuildCounter
    private let draws: BuildCounter

    init(measures: BuildCounter, layouts: BuildCounter, draws: BuildCounter) {
        this.measures = measures
        this.layouts = layouts
        this.draws = draws
        emit(this)
    }

    public func measure(_: UiContext, available: Size): Size {
        measures.value += 1
        available
    }

    public func layout(_: UiContext, _: Rect): Unit {
        layouts.value += 1
    }

    public func draw(_: UiContext): Unit {
        draws.value += 1
    }

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }
}

private class BuildCounter {
    var value: Int64 = 0
}

private class CommandPaintProbe <: Widget {
    private let draws: BuildCounter
    private let dynamic: Bool
    private let paintState: ?State<Int64>
    private var frame = Rect.zero()

    init(draws: BuildCounter, dynamic!: Bool = false, paintState!: ?State<Int64> = None) {
        this.draws = draws
        this.dynamic = dynamic
        this.paintState = paintState
        emit(this)
    }

    public func measure(_: UiContext, available: Size): Size {
        available
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        draws.value += 1
        match (paintState) {
            case Some(value) => let _ = value.value
            case None => ()
        }
        if (dynamic) {
            ctx.requestFrame()
        }
        ctx.renderer.fill(frame, Color.rgb(30, 50, 70))
    }

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }
}

private class RetainedOverlayProbe <: Widget {
    init() {
        emit(this)
    }

    public func measure(_: UiContext, available: Size): Size {
        available
    }

    public func layout(ctx: UiContext, _: Rect): Unit {
        ctx.setOverlay(Overlay(handleEvent: {_, _ => false}, render: {_ => ()}, owner: "retained-probe"))
    }

    public func draw(_: UiContext): Unit {}

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }
}

private class RetainedOverlayCollisionProbe <: Widget {
    private let handledBy: State<Int64>

    init(handledBy: State<Int64>) {
        this.handledBy = handledBy
        emit(this)
    }

    public func measure(_: UiContext, available: Size): Size {
        available
    }

    public func layout(ctx: UiContext, _: Rect): Unit {
        ctx.setOverlay(
            Overlay(
                handleEvent: {
                    _, _ =>
                        handledBy.value = 2
                        true
                },
                render: {_ => ()},
                owner: "shared-owner"
            )
        )
    }

    public func draw(_: UiContext): Unit {}

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }
}

@Test
func retainedSubtreeSkipsBuildMeasureAndLayoutButReplaysDraw(): Unit {
    let store = StateStore()
    let ctx = testContext()
    let builds = BuildCounter()
    let measures = BuildCounter()
    let layouts = BuildCounter()
    let draws = BuildCounter()
    let captured = State<?RetainedSubtree>(None)
    let rect = Rect(0.0, 0.0, 200.0, 80.0)

    let first = buildRetainedProbe(store, UInt64(7), builds, measures, layouts, draws, captured)
    let _ = first.measure(ctx, Size(200.0, 80.0))
    first.layout(ctx, rect)
    first.draw(ctx)

    let second = buildRetainedProbe(store, UInt64(7), builds, measures, layouts, draws, captured)
    let _ = second.measure(ctx, Size(200.0, 80.0))
    second.layout(ctx, rect)
    second.draw(ctx)

    @Expect(builds.value, Int64(1))
    @Expect(measures.value, Int64(1))
    @Expect(layouts.value, Int64(1))
    @Expect(draws.value, Int64(2))
    let stats = captured.value.getOrThrow().cacheStats()
    @Expect(stats.buildHits, UInt64(1))
    @Expect(stats.layoutHits, UInt64(1))
}

@Test
func retainedSubtreeRevisionRebuildsAndInvalidatesGeometryCaches(): Unit {
    let store = StateStore()
    let ctx = testContext()
    let builds = BuildCounter()
    let measures = BuildCounter()
    let layouts = BuildCounter()
    let draws = BuildCounter()
    let captured = State<?RetainedSubtree>(None)

    let first = buildRetainedProbe(store, UInt64(1), builds, measures, layouts, draws, captured)
    let _ = first.measure(ctx, Size(100.0, 40.0))
    first.layout(ctx, Rect(0.0, 0.0, 100.0, 40.0))
    let second = buildRetainedProbe(store, UInt64(2), builds, measures, layouts, draws, captured)
    let _ = second.measure(ctx, Size(100.0, 40.0))
    second.layout(ctx, Rect(0.0, 0.0, 100.0, 40.0))

    @Expect(builds.value, Int64(2))
    @Expect(measures.value, Int64(2))
    @Expect(layouts.value, Int64(2))
}

@Test
func retainedSubtreeKeepsRememberedStateMountedAcrossBuildHit(): Unit {
    let store = StateStore()
    let captured = State<?State<Int64>>(None)
    let body = {
        => let _ = buildRoot({
            => RetainedSubtree("stateful", UInt64(0)) {
                captured.value = Some(rememberState<Int64>("local") {3})
                Spacer()
            }
        }, store)
    }

    body()
    let first = captured.value.getOrThrow()
    first.value = 9
    body() // retained body is skipped; its nested State must still be marked mounted
    let _ = buildRoot({=> Spacer()}, store)
    body()

    let remounted = captured.value.getOrThrow()
    @Expect(!refEq((first as Object).getOrThrow(), (remounted as Object).getOrThrow())) // cjcheck-ignore: unchecked-cast # identity is the assertion
    @Expect(remounted.value, Int64(3))
}

@Test
func retainedParentHitKeepsNestedRetainedIdentityMounted(): Unit {
    let store = StateStore()
    let nestedBuilds = BuildCounter()
    let build = {
        revision: UInt64 => let _ = buildRoot({
            => RetainedSubtree("parent", revision) {
                RetainedSubtree("nested", UInt64(0)) {
                    nestedBuilds.value += 1
                    Spacer()
                }
            }
        }, store)
    }

    build(UInt64(0))
    build(UInt64(0))
    build(UInt64(1))

    @Expect(nestedBuilds.value, Int64(1))
}

@Test
func failedRetainedRevisionRebuildPreservesCommittedRecord(): Unit {
    let store = StateStore()
    let builds = BuildCounter()
    let build = {
        revision: UInt64 => buildRoot({
            => RetainedSubtree("atomic", revision) {
                builds.value += 1
                Spacer()
            }
        }, store)
    }

    let _ = build(UInt64(0))
    var rejected = false
    try {
        let _ = buildRoot(
            {
                =>
                    RetainedSubtree("atomic", UInt64(1)) {
                        builds.value += 1
                        Spacer()
                    }
                    throw IllegalStateException("fail after retained rebuild")
            },
            store
        )
    } catch (_: IllegalStateException) {
        rejected = true
    }
    let _ = build(UInt64(0))

    @Expect(rejected)
    // The failed body ran, but the last frame is a hit on the previously committed revision.
    @Expect(builds.value, Int64(2))
}

@Test
func failedParentRebuildDoesNotPruneNestedMountScope(): Unit {
    let store = StateStore()
    let nestedBuilds = BuildCounter()
    let mounted = {
        revision: UInt64 => buildRoot({
            => RetainedSubtree("transaction-parent", revision) {
                RetainedSubtree("transaction-child", UInt64(0)) {
                    nestedBuilds.value += 1
                    Spacer()
                }
            }
        }, store)
    }

    let _ = mounted(UInt64(0))
    var rejected = false
    try {
        let _ = buildRoot(
            {
                =>
                    RetainedSubtree("transaction-parent", UInt64(1)) {Spacer()}
                    throw IllegalStateException("abort before ownership commit")
            },
            store
        )
    } catch (_: IllegalStateException) {
        rejected = true
    }
    let _ = mounted(UInt64(0))
    @Expect(rejected)
    @Expect(nestedBuilds.value, Int64(1))

    // A successful unmount still releases the whole nested ownership tree.
    let _ = buildRoot({=> Spacer()}, store)
    let _ = mounted(UInt64(0))
    @Expect(nestedBuilds.value, Int64(2))
}

@Test
func retainedLayoutReplaysOverlayRegistrationsOnCacheHit(): Unit {
    let store = StateStore()
    let ctx = testContext()
    let rect = Rect(0.0, 0.0, 120.0, 60.0)
    let first = buildRoot({=> RetainedSubtree("overlay", UInt64(0)) {RetainedOverlayProbe()}}, store)
    first.layout(ctx, rect)
    @Expect(ctx.overlayCount(), Int64(1))

    ctx.clearActiveOverlay()
    let second = buildRoot({=> RetainedSubtree("overlay", UInt64(0)) {RetainedOverlayProbe()}}, store)
    second.layout(ctx, rect)
    @Expect(ctx.overlayCount(), Int64(1))
}

@Test
func retainedLayoutReplaysOverlayReplacementWithUnchangedStackSize(): Unit {
    let store = StateStore()
    let ctx = testContext()
    let handledBy = State<Int64>(0)
    let body: () -> Unit = {
        => RetainedSubtree("overlay-collision", UInt64(0)) {
            RetainedOverlayCollisionProbe(handledBy)
        }
    }
    let outer = {
        => Overlay(
            handleEvent: {
                _, _ =>
                    handledBy.value = 1
                    true
            },
            render: {_ => ()},
            owner: "shared-owner"
        )
    }
    let rect = Rect(0.0, 0.0, 100.0, 40.0)

    let first = buildRoot(body, store)
    ctx.setOverlay(outer())
    first.layout(ctx, rect)
    @Expect(ctx.overlayCount(), Int64(1))

    ctx.clearActiveOverlay()
    let second = buildRoot(body, store)
    ctx.setOverlay(outer())
    second.layout(ctx, rect)
    @Expect(ctx.overlayCount(), Int64(1))
    let _ = ctx.dispatchOverlay(UiEvent.Unknown(UInt32(0)))
    @Expect(handledBy.value, Int64(2))
}

@Test
func retainedSubtreeRejectsEmptyAndDuplicateKeys(): Unit {
    let store = StateStore()
    let emptyRejected = State<Bool>(false)
    let duplicateRejected = State<Bool>(false)
    try {
        let _ = buildRoot({=> RetainedSubtree("", UInt64(0)) {Spacer()}}, store)
    } catch (_: IllegalArgumentException) {
        emptyRejected.value = true
    }
    try {
        let _ = buildRoot(
            {
                =>
                    RetainedSubtree("same", UInt64(0)) {Spacer()}
                    RetainedSubtree("same", UInt64(0)) {Spacer()}
            },
            store
        )
    } catch (_: IllegalStateException) {
        duplicateRejected.value = true
    }

    @Expect(emptyRejected.value)
    @Expect(duplicateRejected.value)
}

@Test
func retainedPaintCommandBufferReplacesSecondTreeDraw(): Unit {
    let window = SdlWindow(WindowSpec("Retained paint cache", 180, 100, vsync: false, supersample: 2))
    let store = StateStore()
    try {
        let ctx = UiContext(window.renderer, Theme.light())
        let draws = BuildCounter()
        let captured = State<?RetainedSubtree>(None)
        let rect = Rect(0.0, 0.0, 180.0, 100.0)

        let first = buildPaintCachedProbe(store, draws, captured)
        first.layout(ctx, rect)
        window.renderer.beginScene(180.0, 100.0, Color.rgb(20, 30, 40))
        first.draw(ctx)
        window.renderer.endScene()

        let second = buildPaintCachedProbe(store, draws, captured)
        second.layout(ctx, rect)
        window.renderer.beginScene(180.0, 100.0, Color.rgb(20, 30, 40))
        second.draw(ctx)
        window.renderer.endScene()

        @Expect(draws.value, Int64(1))
        let stats = captured.value.getOrThrow().cacheStats()
        @Expect(stats.paintHits, UInt64(1))
        @Expect(stats.paintCommandCount, Int64(1))
        @Expect(stats.paintEstimatedBytes > UInt64(0))
    } finally {
        store.clear() // cached texture must be released before its renderer
        window.close()
    }
}

@Test
func retainedPaintBypassesCacheForDynamicContextProtocols(): Unit {
    let store = StateStore()
    let ctx = testContext()
    let draws = BuildCounter()
    let captured = State<?RetainedSubtree>(None)
    let widget = buildRoot({=>
        let retained = RetainedSubtree("dynamic-paint", cachePaint: true) {
            CommandPaintProbe(draws, dynamic: true)
        }
        captured.value = Some(retained)
    }, store)
    widget.layout(ctx, Rect(0.0, 0.0, 100.0, 50.0))

    var frame: Int64 = 0
    while (frame < 40) {
        widget.draw(ctx)
        frame += 1
    }

    @Expect(draws.value, Int64(40))
    let stats = captured.value.getOrThrow().cacheStats()
    @Expect(stats.paintHits, UInt64(0))
    @Expect(stats.paintCommandCount, Int64(0))
    @Expect(stats.paintRecordAttempts, UInt64(2))
    @Expect(stats.paintDynamicBypasses, UInt64(2))
    @Expect(stats.paintBypassFrames, UInt64(38))
    @Expect(stats.paintBypassRemaining, Int64(58))
}

@Test
func retainedDynamicPaintBypassResetsImmediatelyWhenPaintStateInvalidates(): Unit {
    let store = StateStore()
    let ctx = testContext()
    let draws = BuildCounter()
    let paintState = State<Int64>(0)
    let captured = State<?RetainedSubtree>(None)
    let widget = buildRoot({=>
        let retained = RetainedSubtree("dynamic-paint-state", cachePaint: true) {
            CommandPaintProbe(draws, dynamic: true, paintState: paintState)
        }
        captured.value = Some(retained)
    }, store)
    widget.layout(ctx, Rect(0.0, 0.0, 100.0, 50.0))
    widget.draw(ctx)
    @Expect(captured.value.getOrThrow().cacheStats().paintBypassRemaining, Int64(32))

    paintState.value = 1
    @Expect(captured.value.getOrThrow().cacheStats().paintBypassRemaining, Int64(0))
    widget.draw(ctx)
    let stats = captured.value.getOrThrow().cacheStats()
    @Expect(stats.paintRecordAttempts, UInt64(2))
    @Expect(stats.paintDynamicBypasses, UInt64(2))
}

@Test
func nestedRetainedPaintBuffersFlattenIntoParentRecording(): Unit {
    let store = StateStore()
    let ctx = testContext()
    let draws = BuildCounter()
    let outerCaptured = State<?RetainedSubtree>(None)
    let innerCaptured = State<?RetainedSubtree>(None)
    let widget = buildRoot({=>
        let outer = RetainedSubtree("outer-paint", cachePaint: true) {
            let inner = RetainedSubtree("inner-paint", cachePaint: true) {
                CommandPaintProbe(draws)
            }
            innerCaptured.value = Some(inner)
        }
        outerCaptured.value = Some(outer)
    }, store)
    widget.layout(ctx, Rect(0.0, 0.0, 100.0, 50.0))

    widget.draw(ctx)
    widget.draw(ctx)

    @Expect(draws.value, Int64(1))
    @Expect(innerCaptured.value.getOrThrow().cacheStats().paintCommandCount, Int64(1))
    @Expect(outerCaptured.value.getOrThrow().cacheStats().paintCommandCount, Int64(1))
    @Expect(outerCaptured.value.getOrThrow().cacheStats().paintHits, UInt64(1))
}

private func buildRetainedProbe(
    store: StateStore,
    revision: UInt64,
    builds: BuildCounter,
    measures: BuildCounter,
    layouts: BuildCounter,
    draws: BuildCounter,
    captured: State<?RetainedSubtree>
): Widget {
    buildRoot(
        {
            =>
                let retained = RetainedSubtree("probe", revision) {
                    builds.value += 1
                    RetainedProbe(measures, layouts, draws)
                }
                captured.value = Some(retained)
        },
        store
    )
}

private func buildPaintCachedProbe(
    store: StateStore,
    draws: BuildCounter,
    captured: State<?RetainedSubtree>
): Widget {
    buildRoot(
        {
            =>
                let retained = RetainedSubtree("paint", UInt64(0), cachePaint: true) {
                    CommandPaintProbe(draws)
                }
                captured.value = Some(retained)
        },
        store
    )
}
