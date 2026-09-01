package cui.core

import sdl.{Rect, Renderer, Size, UiEvent}

private class AutomaticSelfWritingLayoutProbe <: Widget {
    private let source: State<Int64>

    init(source: State<Int64>) {
        this.source = source
    }

    public func measure(_: UiContext, available: Size): Size {
        available
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
}

private class ContextBoundSemanticLayoutProbe <: Widget {
    private let id: String
    private let label: State<String>

    init(id: String, label: State<String>) {
        this.id = id
        this.label = label
    }

    public func measure(_: UiContext, available: Size): Size {
        available
    }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        ctx.registerSemanticProvider(id, rect, [], {=> Semantics(label: label.value)}, {_ => false})
    }

    public func draw(_: UiContext): Unit {}

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }
}

@Test
func stateWriteDuringAutomaticLayoutDoesNotPublishUncommittedElementGeometry(): Unit {
    let arena = ElementArena()
    let owner = arena.mount("automatic-layout-transaction", arena.rootId, ElementKind.Automatic)
    let sceneNode = arena.sceneFacet(owner).acquire(0)
    let source = State<Int64>(0)
    let node = AutomaticRenderNode(AutomaticSelfWritingLayoutProbe(source), sceneNode, AutomaticPaintBudget(),
        {_: Rect => ()})
    let context = UiContext(Renderer.headless(), Theme.light())

    node.layout(context, Rect(10.0, 20.0, 100.0, 40.0))

    let snapshot = arena.spaceFacet(owner).resolveScene(sceneNode.id).getOrThrow().snapshot()
    @Expect(sameAutomaticRect(snapshot.layoutBounds, Rect.zero()))
    node.close()
    arena.release(owner)
}

@Test
func automaticSemanticLayoutCacheDoesNotCrossContexts(): Unit {
    let label = State<String>("automatic-old")
    let node = AutomaticRenderNode(ContextBoundSemanticLayoutProbe("automatic-context", label),
        AutomaticPaintBudget(), {_: Rect => ()})
    let moved = semanticLayoutCacheMovesToLatestContext({ctx, rect => node.layout(ctx, rect)}, label,
        "automatic-context")
    node.close()
    @Expect(moved)
}

@Test
func retainedSemanticLayoutCacheDoesNotCrossContexts(): Unit {
    let label = State<String>("retained-old")
    let record = RetainedRecord(UInt64(0), false, ContextBoundSemanticLayoutProbe("retained-context", label))
    let moved = semanticLayoutCacheMovesToLatestContext({ctx, rect => record.layout(ctx, rect)}, label,
        "retained-context")
    record.close()
    @Expect(moved)
}

private func semanticLayoutCacheMovesToLatestContext(
    layout: (UiContext, Rect) -> Unit,
    label: State<String>,
    semanticId: String
): Bool {
    let first = UiContext(Renderer.headless(), Theme.light())
    let second = UiContext(Renderer.headless(), Theme.light())
    let rect = Rect(0.0, 0.0, 120.0, 40.0)

    first.clearSemantics()
    layout(first, rect)
    first.commitSemantics()
    second.clearSemantics()
    layout(second, rect)
    second.commitSemantics()
    let labelMatches = second.semanticsTreeSnapshot().node(semanticId).getOrThrow().properties.label == label.value

    first.resetSemantics()
    label.value = "latest"
    labelMatches && second.takeFrameRequest()
}
