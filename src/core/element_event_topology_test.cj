package cui.core

import sdl.{Rect, Renderer}

@Test
func elementLayoutRejectsSameSizedForeignEventTopologyCommit(): Unit {
    let arena = ElementArena()
    let owner = arena.mount("event-foreign-owner", arena.rootId, ElementKind.Automatic)
    let sceneNode = arena.sceneFacet(owner).acquire(0)
    let context = UiContext(Renderer.headless(), Theme.light())
    let bounds = Rect(0.0, 0.0, 20.0, 10.0)
    let staged = sceneNode.eventTopology(1)
    staged.beginLayout()
    staged.commitLayout([EmptyView()], bounds)
    let outsider = ChildEventTopology(1, deferredPublication: true)
    outsider.beginLayout()
    outsider.commitLayout([EmptyView()], bounds)

    @Expect(foreignEventTopologyCommitWasRejected(sceneNode, context, bounds, outsider))
    @Expect(arena.spaceFacet(owner).resolveScene(sceneNode.id).getOrThrow().snapshot().eventTopology.isNone())
    @Expect(!releasedEventTopologyRejectsUse(outsider))

    sceneNode.discardStagedEventTopology()
    outsider.close()
    sceneNode.close()
    arena.release(owner)
}

private func foreignEventTopologyCommitWasRejected(
    node: ElementSceneNode,
    context: UiContext,
    bounds: Rect,
    outsider: ChildEventTopology
): Bool {
    try {
        node.publishLayout(ElementLayoutCommit(bounds, None, PaintOutset(), context.uiEnvironmentKey(),
            ElementLayoutEffects(None<OverlaySnapshot>, None<SemanticFragment>,
                eventTopology: ElementEventTopologyCommit.Replace(outsider))))
        false
    } catch (_: IllegalStateException) {
        true
    }
}
