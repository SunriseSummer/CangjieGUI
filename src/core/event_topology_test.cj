package cui.core

import sdl.{MouseButton, Rect, Renderer, Size, UiEvent}

private class PointerTopologyProbe {
    let visits: Array<Int64>
    let target: Int64
    let consumeOutside: Bool

    init(count: Int64, target: Int64, consumeOutside!: Bool = false) {
        visits = Array<Int64>(count, repeat: 0)
        this.target = target
        this.consumeOutside = consumeOutside
    }

    func visit(index: Int64, inside: Bool): Bool {
        visits[index] += 1
        (inside && index == target) || consumeOutside
    }
}

private class GlobalListenerProbe {
    var visits: Int64 = 0

    func consume(): EventOutcome {
        visits += 1
        EventOutcome.Consume
    }
}

private class EventTopologyLayoutFailure {
    var enabled = false
}

private class TransactionalEventTopologyWidget <: Widget {
    private let index: Int64
    private let visits: Array<Int64>
    private let failure: EventTopologyLayoutFailure

    init(index: Int64, visits: Array<Int64>, failure: EventTopologyLayoutFailure) {
        this.index = index
        this.visits = visits
        this.failure = failure
        emit(this)
    }

    public func measure(_: UiContext, _: Size): Size {
        Size(10.0, 10.0)
    }

    public func layout(_: UiContext, _: Rect): Unit {
        if (failure.enabled && index == 1) {
            throw IllegalStateException("event topology layout failed")
        }
    }

    public func draw(_: UiContext): Unit {}

    public func handle(_: UiContext, event: UiEvent): Bool {
        match (event) {
            case UiEvent.MouseDown(MouseButton.Left, _, _) =>
                visits[index] += 1
                index == 0
            case _ => false
        }
    }

    public func acceptsStretch(_: Axis): Bool {
        false
    }

    public func pointerEventScope(): PointerEventScope {
        PointerEventScope.LayoutBounds
    }
}

private class SelfWritingEventTopologyWidget <: Widget {
    private let source: State<Int64>

    init(source: State<Int64>) {
        this.source = source
        emit(this)
    }

    public func measure(_: UiContext, _: Size): Size {
        Size(10.0, 10.0)
    }

    public func layout(_: UiContext, _: Rect): Unit {
        if (source.value == 0) {
            source.value = 1
        }
    }

    public func draw(_: UiContext): Unit {}

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }

    public func acceptsStretch(_: Axis): Bool {
        false
    }

    public func pointerEventScope(): PointerEventScope {
        PointerEventScope.LayoutBounds
    }
}

private class PointerTopologyWidget <: Widget {
    private let index: Int64
    private let probe: PointerTopologyProbe
    private let bounded: Bool
    private var frame = Rect.zero()

    init(index: Int64, probe: PointerTopologyProbe, bounded!: Bool = true) {
        this.index = index
        this.probe = probe
        this.bounded = bounded
        emit(this)
    }

    public func measure(_: UiContext, _: Size): Size {
        Size(10.0, 10.0)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(_: UiContext): Unit {}

    public func handle(_: UiContext, event: UiEvent): Bool {
        match (event) {
            case UiEvent.MouseDown(MouseButton.Left, x, y) => probe.visit(index, frame.contains(x, y))
            case UiEvent.MouseMove(x, y) => probe.visit(index, frame.contains(x, y))
            case _ => false
        }
    }

    public func acceptsStretch(_: Axis): Bool {
        false
    }

    public func pointerEventScope(): PointerEventScope {
        if (bounded) {
            PointerEventScope.LayoutBounds
        } else {
            PointerEventScope.Unbounded
        }
    }
}

@Test
func indexedGridVisitsOnlyTheSpatialCandidate(): Unit {
    let context = UiContext(Renderer.headless(), Theme.light())
    let probe = PointerTopologyProbe(2, 0)
    let grid = Grid(2) {
        PointerTopologyWidget(0, probe)
        PointerTopologyWidget(1, probe)
    }.spacing(0.0)

    grid.layout(context, Rect(0.0, 0.0, 40.0, 10.0))
    @Expect(grid.handle(context, UiEvent.MouseDown(MouseButton.Left, 5.0, 5.0)))
    @Expect(probe.visits[0], Int64(1))
    @Expect(probe.visits[1], Int64(0))
}

@Test
func unboundedCompatibilityChildCannotBePruned(): Unit {
    let context = UiContext(Renderer.headless(), Theme.light())
    let probe = PointerTopologyProbe(2, 0, consumeOutside: true)
    let grid = Grid(2) {
        PointerTopologyWidget(0, probe)
        PointerTopologyWidget(1, probe, bounded: false)
    }.spacing(0.0)

    grid.layout(context, Rect(0.0, 0.0, 40.0, 10.0))
    @Expect(grid.handle(context, UiEvent.MouseDown(MouseButton.Left, 5.0, 5.0)))
    @Expect(probe.visits[0], Int64(0))
    @Expect(probe.visits[1], Int64(1))
}

@Test
func pointerLayoutModifierOptsCustomSubtreeIntoPruning(): Unit {
    let context = UiContext(Renderer.headless(), Theme.light())
    let probe = PointerTopologyProbe(2, 0, consumeOutside: true)
    let grid = Grid(2) {
        PointerTopologyWidget(0, probe)
        let _ = PointerTopologyWidget(1, probe, bounded: false).pointerEventsWithinLayout()
    }.spacing(0.0)

    grid.layout(context, Rect(0.0, 0.0, 40.0, 10.0))
    @Expect(grid.handle(context, UiEvent.MouseDown(MouseButton.Left, 5.0, 5.0)))
    @Expect(probe.visits[0], Int64(1))
    @Expect(probe.visits[1], Int64(0))
}

@Test
func globalEventListenerRemainsUnboundedAroundBoundedChild(): Unit {
    let context = UiContext(Renderer.headless(), Theme.light())
    let probe = PointerTopologyProbe(2, 0)
    let global = GlobalListenerProbe()
    let grid = Grid(2) {
        PointerTopologyWidget(0, probe)
        let _ = PointerTopologyWidget(1, probe).onEvent(
            phase: EventPhase.Bubble,
            scope: EventScope.Global,
            handler: {
                _, _ => global.consume()
            }
        )
    }.spacing(0.0)

    grid.layout(context, Rect(0.0, 0.0, 40.0, 10.0))
    @Expect(grid.handle(context, UiEvent.MouseDown(MouseButton.Left, 5.0, 5.0)))
    @Expect(global.visits, Int64(1))
    @Expect(probe.visits[0], Int64(0))
    @Expect(probe.visits[1], Int64(1))
}

@Test
func activePointerCaptureBypassesSpatialPruning(): Unit {
    let context = UiContext(Renderer.headless(), Theme.light())
    let probe = PointerTopologyProbe(2, -1)
    let grid = Grid(2) {
        PointerTopologyWidget(0, probe)
        PointerTopologyWidget(1, probe)
    }.spacing(0.0)

    grid.layout(context, Rect(0.0, 0.0, 40.0, 10.0))
    context.press("capture-owner")
    @Expect(!grid.handle(context, UiEvent.MouseMove(5.0, 5.0)))
    @Expect(probe.visits[0], Int64(1))
    @Expect(probe.visits[1], Int64(1))
}

@Test
func overlappingBoundedChildrenPreserveDeepestLinearSemantics(): Unit {
    let context = UiContext(Renderer.headless(), Theme.light())
    let probe = PointerTopologyProbe(4, 0)
    let stack = ZStack {
        for (index in 0..4) {
            PointerTopologyWidget(index, probe)
        }
    }

    stack.layout(context, Rect(0.0, 0.0, 10.0, 10.0))
    @Expect(stack.handle(context, UiEvent.MouseDown(MouseButton.Left, 5.0, 5.0)))
    for (index in 0..4) {
        @Expect(probe.visits[index], Int64(1))
    }
}

@Test
func boundedContainerPropagatesScopeOnlyWhenChildrenStayInside(): Unit {
    let context = UiContext(Renderer.headless(), Theme.light())
    let probe = PointerTopologyProbe(2, -1)
    let contained = ZStack {
        PointerTopologyWidget(0, probe)
        PointerTopologyWidget(1, probe)
    }
    contained.layout(context, Rect(0.0, 0.0, 10.0, 10.0))
    @Expect(isLayoutBounds(contained.pointerEventScope()))

    let overflowing = Grid(1) {
        PointerTopologyWidget(0, probe)
        PointerTopologyWidget(1, probe)
    }.spacing(0.0)
    overflowing.layout(context, Rect(0.0, 0.0, 10.0, 10.0))
    @Expect(!isLayoutBounds(overflowing.pointerEventScope()))
}

@Test
func failedLayoutKeepsPreviouslyCommittedEventTopology(): Unit {
    let context = UiContext(Renderer.headless(), Theme.light())
    let visits = Array<Int64>(2, repeat: 0)
    let failure = EventTopologyLayoutFailure()
    let grid = Grid(2) {
        TransactionalEventTopologyWidget(0, visits, failure)
        TransactionalEventTopologyWidget(1, visits, failure)
    }.spacing(0.0)

    grid.layout(context, Rect(0.0, 0.0, 40.0, 10.0))
    failure.enabled = true
    @Expect(eventTopologyLayoutFailed(grid, context, Rect(100.0, 0.0, 40.0, 10.0)))
    @Expect(grid.handle(context, UiEvent.MouseDown(MouseButton.Left, 5.0, 5.0)))
    @Expect(visits[0], Int64(1))
    @Expect(visits[1], Int64(0))

    failure.enabled = false
    grid.layout(context, Rect(100.0, 0.0, 40.0, 10.0))
    @Expect(!grid.handle(context, UiEvent.MouseDown(MouseButton.Left, 5.0, 5.0)))
    @Expect(visits[0], Int64(1))
    @Expect(visits[1], Int64(0))
}

@Test
func automaticContainerCommitsEventTopologyIntoElementSpace(): Unit {
    let arena = ElementArena()
    let owner = arena.mount("event-space-owner", arena.rootId, ElementKind.Automatic)
    let sceneNode = arena.sceneFacet(owner).acquire(0)
    let context = UiContext(Renderer.headless(), Theme.light())
    let probe = PointerTopologyProbe(2, 0)
    let grid = Grid(2) {
        PointerTopologyWidget(0, probe)
        PointerTopologyWidget(1, probe)
    }.spacing(0.0)
    let render = AutomaticRenderNode(grid, sceneNode, AutomaticPaintBudget(), {_: Rect => ()})

    render.layout(context, Rect(0.0, 0.0, 40.0, 10.0))
    let committed = arena.spaceFacet(owner).resolveScene(sceneNode.id).getOrThrow().snapshot()
    let firstTopology = committed.eventTopology.getOrThrow()
    @Expect(firstTopology.childCount, Int64(2))
    @Expect(firstTopology.hasIndex)
    @Expect(firstTopology.revision > UInt64(0))

    render.layout(context, Rect(0.0, 0.0, 40.0, 10.0))
    let stable = arena.spaceFacet(owner).resolveScene(sceneNode.id).getOrThrow().snapshot()
    @Expect(stable.eventTopology.getOrThrow().revision, firstTopology.revision)

    render.layout(context, Rect(20.0, 0.0, 40.0, 10.0))
    let moved = arena.spaceFacet(owner).resolveScene(sceneNode.id).getOrThrow().snapshot()
    @Expect(moved.eventTopology.getOrThrow().revision > firstTopology.revision)
    @Expect(sameAutomaticRect(firstTopology.containerBounds, Rect(0.0, 0.0, 40.0, 10.0)))
    @Expect(sameAutomaticRect(moved.eventTopology.getOrThrow().containerBounds, Rect(20.0, 0.0, 40.0, 10.0)))

    let staleTopology = sceneNode.eventTopology(2)
    render.update(EmptyView())
    render.layout(context, Rect(20.0, 0.0, 40.0, 10.0))
    let cleared = arena.spaceFacet(owner).resolveScene(sceneNode.id).getOrThrow().snapshot()
    @Expect(cleared.eventTopology.isNone())
    @Expect(releasedEventTopologyRejectsUse(staleTopology))
    render.close()
    arena.release(owner)
}

@Test
func stateWriteDuringAutomaticLayoutCannotPublishEventTopologyAlone(): Unit {
    let arena = ElementArena()
    let owner = arena.mount("event-layout-transaction", arena.rootId, ElementKind.Automatic)
    let sceneNode = arena.sceneFacet(owner).acquire(0)
    let context = UiContext(Renderer.headless(), Theme.light())
    let source = State<Int64>(0)
    let grid = Grid(1) {
        SelfWritingEventTopologyWidget(source)
    }
    let render = AutomaticRenderNode(grid, sceneNode, AutomaticPaintBudget(), {_: Rect => ()})

    render.layout(context, Rect(10.0, 20.0, 40.0, 10.0))

    let snapshot = arena.spaceFacet(owner).resolveScene(sceneNode.id).getOrThrow().snapshot()
    @Expect(!snapshot.layoutCommitted)
    @Expect(snapshot.eventTopology.isNone())
    render.close()
    arena.release(owner)
}

@Test
func invalidatedAutomaticRelayoutPreservesCommittedEventTopology(): Unit {
    let arena = ElementArena()
    let owner = arena.mount("event-relayout-transaction", arena.rootId, ElementKind.Automatic)
    let sceneNode = arena.sceneFacet(owner).acquire(0)
    let context = UiContext(Renderer.headless(), Theme.light())
    let source = State<Int64>(1)
    let grid = Grid(1) {
        SelfWritingEventTopologyWidget(source)
    }
    let render = AutomaticRenderNode(grid, sceneNode, AutomaticPaintBudget(), {_: Rect => ()})

    render.layout(context, Rect(0.0, 0.0, 40.0, 10.0))
    let committed = arena.spaceFacet(owner).resolveScene(sceneNode.id).getOrThrow().snapshot()
    source.value = 0
    render.layout(context, Rect(100.0, 0.0, 40.0, 10.0))

    let invalidated = arena.spaceFacet(owner).resolveScene(sceneNode.id).getOrThrow().snapshot()
    @Expect(!invalidated.layoutCommitted)
    @Expect(invalidated.eventTopology.getOrThrow().revision, committed.eventTopology.getOrThrow().revision)
    @Expect(sameAutomaticRect(invalidated.eventTopology.getOrThrow().containerBounds,
        committed.eventTopology.getOrThrow().containerBounds))

    render.layout(context, Rect(100.0, 0.0, 40.0, 10.0))
    let retried = arena.spaceFacet(owner).resolveScene(sceneNode.id).getOrThrow().snapshot()
    @Expect(retried.layoutCommitted)
    @Expect(retried.eventTopology.getOrThrow().revision > committed.eventTopology.getOrThrow().revision)
    @Expect(sameAutomaticRect(retried.eventTopology.getOrThrow().containerBounds,
        Rect(100.0, 0.0, 40.0, 10.0)))
    render.close()
    arena.release(owner)
}

@Test
func invalidatedAutomaticLeafLayoutCannotClearCommittedEventTopology(): Unit {
    let arena = ElementArena()
    let owner = arena.mount("event-clear-transaction", arena.rootId, ElementKind.Automatic)
    let sceneNode = arena.sceneFacet(owner).acquire(0)
    let context = UiContext(Renderer.headless(), Theme.light())
    let probe = PointerTopologyProbe(1, 0)
    let grid = Grid(1) {
        PointerTopologyWidget(0, probe)
    }
    let render = AutomaticRenderNode(grid, sceneNode, AutomaticPaintBudget(), {_: Rect => ()})
    let bounds = Rect(0.0, 0.0, 40.0, 10.0)

    render.layout(context, bounds)
    let committed = arena.spaceFacet(owner).resolveScene(sceneNode.id).getOrThrow().snapshot()
    let source = State<Int64>(0)
    render.update(SelfWritingEventTopologyWidget(source))
    render.layout(context, bounds)

    let invalidated = arena.spaceFacet(owner).resolveScene(sceneNode.id).getOrThrow().snapshot()
    @Expect(invalidated.eventTopology.getOrThrow().revision, committed.eventTopology.getOrThrow().revision)
    render.layout(context, bounds)
    @Expect(arena.spaceFacet(owner).resolveScene(sceneNode.id).getOrThrow().snapshot().eventTopology.isNone())
    render.close()
    arena.release(owner)
}

@Test
func changedChildCountTopologyPublishesOnlyAfterCommit(): Unit {
    let arena = ElementArena()
    let owner = arena.mount("event-count-owner", arena.rootId, ElementKind.Automatic)
    let sceneNode = arena.sceneFacet(owner).acquire(0)
    let context = UiContext(Renderer.headless(), Theme.light())
    let bounds = Rect(0.0, 0.0, 20.0, 10.0)
    let first = sceneNode.eventTopology(2)
    first.beginLayout()
    first.commitLayout([EmptyView(), EmptyView()], bounds)
    @Expect(arena.spaceFacet(owner).resolveScene(sceneNode.id).getOrThrow().snapshot().eventTopology.isNone())
    sceneNode.publishLayout(ElementLayoutCommit(bounds, None, PaintOutset(), context.uiEnvironmentKey(),
        ElementLayoutEffects(None<OverlaySnapshot>, None<SemanticFragment>,
            eventTopology: sceneNode.stagedEventTopologyCommit())))
    let committed = arena.spaceFacet(owner).resolveScene(sceneNode.id).getOrThrow().snapshot()
    @Expect(committed.eventTopology.getOrThrow().childCount, Int64(2))

    let staged = sceneNode.eventTopology(3)
    staged.beginLayout()
    let duringFailure = arena.spaceFacet(owner).resolveScene(sceneNode.id).getOrThrow().snapshot()
    @Expect(duringFailure.eventTopology.getOrThrow().childCount, Int64(2))
    @Expect(duringFailure.eventTopology.getOrThrow().revision,
        committed.eventTopology.getOrThrow().revision)

    @Expect(sceneNode.eventTopology(2).childCount(), Int64(2))
    @Expect(releasedEventTopologyRejectsUse(staged))
    sceneNode.close()
    arena.release(owner)
}

private func eventTopologyLayoutFailed(grid: Grid, context: UiContext, rect: Rect): Bool {
    try {
        grid.layout(context, rect)
        false
    } catch (error: IllegalStateException) {
        error.message == "event topology layout failed"
    }
}

func releasedEventTopologyRejectsUse(topology: ChildEventTopology): Bool {
    try {
        let _ = topology.pointerEventScope()
        false
    } catch (_: IllegalStateException) {
        true
    }
}

private func isLayoutBounds(scope: PointerEventScope): Bool {
    match (scope) {
        case PointerEventScope.LayoutBounds => true
        case PointerEventScope.Unbounded => false
    }
}
