package cui.core

import sdl.{Rect, Renderer, Size}

@Test
func elementArenaStructureRevisionTracksOnlySuccessfulTopologyMutations(): Unit {
    let arena = ElementArena()
    let initial = arena.structureRevision()
    let parent = arena.mount("revision-parent", arena.rootId, ElementKind.Automatic)
    let mounted = arena.structureRevision()
    @Expect(mounted > initial)
    let child = arena.mount("revision-child", parent, ElementKind.Retained)
    let childMounted = arena.structureRevision()
    @Expect(childMounted > mounted)

    @Expect(releasingElementWithChildFails(arena, parent))
    @Expect(arena.structureRevision(), childMounted)
    arena.release(child)
    let childReleased = arena.structureRevision()
    @Expect(childReleased > childMounted)
    arena.release(parent)
    @Expect(arena.structureRevision() > childReleased)
}

@Test
func elementArenaRejectsStaleHandleAfterSlotReuse(): Unit {
    let arena = ElementArena()
    let first = arena.mount("first", arena.rootId, ElementKind.Automatic)
    @Expect(arena.liveCount(), Int64(2))
    @Expect(arena.resolve(first).isSome())

    arena.release(first)
    let second = arena.mount("second", arena.rootId, ElementKind.Retained)

    @Expect(second.slot, first.slot)
    @Expect(second.generation != first.generation)
    @Expect(arena.resolve(first).isNone())
    @Expect(arena.resolve(second).isSome())
}

@Test
func elementArenaRequiresChildrenToUnmountBeforeParent(): Unit {
    let arena = ElementArena()
    let parent = arena.mount("parent", arena.rootId, ElementKind.Automatic)
    let child = arena.mount("child", parent, ElementKind.Retained)

    @Expect(releasingElementWithChildFails(arena, parent))
    arena.release(child)
    arena.release(parent)
    @Expect(arena.liveCount(), Int64(1))
}

private func releasingElementWithChildFails(arena: ElementArena, id: ElementId): Bool {
    try {
        arena.release(id)
        false
    } catch (_: IllegalStateException) {
        true
    }
}

@Test
func elementArenaFacetsTrackCompatibilityRecordsAndClear(): Unit {
    let store = StateStore()
    enableAutomaticComposition(store)
    let _ = buildRoot({=> RetainedSubtree("bridge") {Spacer()}}, store)

    for ((_, record) in store.automaticEntries) {
        let element = store.elementArena.resolve(record.mountScope.elementId).getOrThrow()
        @Expect(element.automatic.isSome())
    }
    for ((_, record) in store.retainedEntries) {
        let element = store.elementArena.resolve(record.mountScope.elementId).getOrThrow()
        @Expect(element.retained.isSome())
    }
    @Expect(store.elementArena.liveCount() > 1)

    store.clear()
    @Expect(store.elementArena.liveCount(), Int64(1))
}

@Test
func failedBuildRollsBackNewElementIdentities(): Unit {
    let store = StateStore()
    enableAutomaticComposition(store)

    @Expect(failingElementBuildWasRejected(store))
    @Expect(store.elementArena.liveCount(), Int64(1))
}

@Test
func elementSceneFacetRejectsStaleSlotAndBlocksOwnerRelease(): Unit {
    let arena = ElementArena()
    let owner = arena.mount("scene-owner", arena.rootId, ElementKind.Automatic)
    let scene = arena.sceneFacet(owner)
    let first = scene.acquire(0)
    let stale = first.id

    @Expect(releasingElementWithChildFails(arena, owner))
    first.close()
    let second = scene.acquire(0)
    @Expect(second.id.slot, stale.slot)
    @Expect(second.id.generation != stale.generation)
    @Expect(scene.resolve(stale).isNone())
    @Expect(scene.resolve(second.id).isSome())
    let space = arena.spaceFacet(owner)
    @Expect(space.resolveScene(stale).isNone())
    @Expect(space.resolveScene(second.id).isSome())
    @Expect(updatingReleasedSceneNodeFails(first))

    second.close()
    @Expect(space.liveSceneCount(), Int64(0))
    arena.release(owner)
    @Expect(arena.liveCount(), Int64(1))
}

@Test
func elementSpaceOwnsImmutableSceneGeometrySnapshots(): Unit {
    let arena = ElementArena()
    let owner = arena.mount("space-owner", arena.rootId, ElementKind.Automatic)
    let node = arena.sceneFacet(owner).acquire(0)
    let space = arena.spaceFacet(owner)
    let context = UiContext(Renderer.headless(), Theme.light())
    let initialRevision = space.spatialRevision()

    node.publishLayout(ElementLayoutCommit(Rect(10.0, 20.0, 100.0, 40.0),
        Some(Rect(0.0, 0.0, 100.0, 45.0)), PaintOutset(), context.uiEnvironmentKey(),
        ElementLayoutEffects(None<OverlaySnapshot>, None<SemanticFragment>)))
    node.observePaintBounds(Some(Rect(8.0, 18.0, 104.0, 44.0)))
    let committed = space.resolveScene(node.id).getOrThrow().snapshot()
    @Expect(committed.layoutCommitted)
    @Expect(sameAutomaticRect(committed.layoutBounds, Rect(10.0, 20.0, 100.0, 40.0)))
    @Expect(sameAutomaticRect(committed.visibleBounds, Rect(10.0, 20.0, 90.0, 25.0)))
    @Expect(sameAutomaticRect(committed.paintBounds, Rect(8.0, 18.0, 104.0, 44.0)))
    @Expect(space.spatialRevision() > initialRevision)

    node.publishLayout(ElementLayoutCommit(Rect(30.0, 40.0, 120.0, 60.0), None,
        PaintOutset(left: 7.0, top: 5.0, right: 11.0, bottom: 13.0), context.uiEnvironmentKey(),
        ElementLayoutEffects(None<OverlaySnapshot>, None<SemanticFragment>)))
    let moved = space.resolveScene(node.id).getOrThrow().snapshot()
    @Expect(sameAutomaticRect(committed.layoutBounds, Rect(10.0, 20.0, 100.0, 40.0)))
    @Expect(sameAutomaticRect(moved.layoutBounds, Rect(30.0, 40.0, 120.0, 60.0)))
    @Expect(sameAutomaticRect(moved.paintBounds, Rect(23.0, 35.0, 138.0, 78.0)))

    node.invalidateLayout()
    let invalidated = space.resolveScene(node.id).getOrThrow().snapshot()
    @Expect(!invalidated.layoutCommitted)
    @Expect(sameAutomaticRect(invalidated.layoutBounds, moved.layoutBounds))
    @Expect(invalidated.revision > moved.revision)
    let invalidatedRevision = invalidated.revision
    node.invalidateLayout()
    @Expect(space.resolveScene(node.id).getOrThrow().snapshot().revision, invalidatedRevision)

    node.close()
    @Expect(space.resolveScene(node.id).isNone())
    arena.release(owner)
}

@Test
func elementSpacePublishesAndInvalidatesOneImmutableMeasureSnapshot(): Unit {
    let arena = ElementArena()
    let owner = arena.mount("measure-owner", arena.rootId, ElementKind.Automatic)
    let space = arena.spaceFacet(owner)
    let sceneNode = arena.sceneFacet(owner).acquire(0)
    let context = UiContext(Renderer.headless(), Theme.light())
    let initialRevision = space.spatialRevision()

    sceneNode.publishLayout(ElementLayoutCommit(Rect(0.0, 0.0, 120.0, 80.0), None, PaintOutset(),
        context.uiEnvironmentKey(), ElementLayoutEffects(None<OverlaySnapshot>, None<SemanticFragment>)))
    @Expect(sceneNode.hasLayout())
    sceneNode.publishMeasure(Size(120.0, 80.0), context.uiEnvironmentKey(), Size(42.0, 24.0))
    let committed = space.resolveScene(sceneNode.id).getOrThrow().snapshot()
    @Expect(!committed.layoutCommitted)
    @Expect(sameAutomaticRect(committed.layoutBounds, Rect(0.0, 0.0, 120.0, 80.0)))
    @Expect(committed.measurement.isSome())
    @Expect(committed.measurement.getOrThrow().available.w, Float32(120.0))
    @Expect(committed.measurement.getOrThrow().result.h, Float32(24.0))
    @Expect(space.spatialRevision() > initialRevision)

    let committedRevision = committed.revision
    @Expect(sceneNode.hasMeasure())
    sceneNode.invalidateMeasure()
    let invalidated = space.resolveScene(sceneNode.id).getOrThrow().snapshot()
    @Expect(invalidated.measurement.isNone())
    @Expect(invalidated.revision > committedRevision)
    @Expect(!sceneNode.hasMeasure())
    let invalidatedRevision = invalidated.revision
    sceneNode.invalidateMeasure()
    @Expect(!sceneNode.hasMeasure())
    @Expect(space.resolveScene(sceneNode.id).getOrThrow().snapshot().revision, invalidatedRevision)

    sceneNode.close()
    arena.release(owner)
}

@Test
func invalidatingAbsentMeasurementTransitionsCurrentLayoutToStaleExactlyOnce(): Unit {
    let arena = ElementArena()
    let owner = arena.mount("layout-only-owner", arena.rootId, ElementKind.Automatic)
    let space = arena.spaceFacet(owner)
    let sceneNode = arena.sceneFacet(owner).acquire(0)
    let context = UiContext(Renderer.headless(), Theme.light())
    let bounds = Rect(5.0, 7.0, 90.0, 30.0)

    sceneNode.publishLayout(ElementLayoutCommit(bounds, None, PaintOutset(), context.uiEnvironmentKey(),
        ElementLayoutEffects(None<OverlaySnapshot>, None<SemanticFragment>)))
    let committed = space.resolveScene(sceneNode.id).getOrThrow().snapshot()
    @Expect(committed.layoutCommitted)
    @Expect(committed.measurement.isNone())

    sceneNode.invalidateMeasure()
    let stale = space.resolveScene(sceneNode.id).getOrThrow().snapshot()
    @Expect(!stale.layoutCommitted)
    @Expect(stale.measurement.isNone())
    @Expect(sameAutomaticRect(stale.layoutBounds, bounds))
    @Expect(stale.revision > committed.revision)
    @Expect(replayingStaleElementLayoutFails(sceneNode, context))

    sceneNode.invalidateMeasure()
    @Expect(space.resolveScene(sceneNode.id).getOrThrow().snapshot().revision, stale.revision)
    sceneNode.close()
    arena.release(owner)
}

private func replayingStaleElementLayoutFails(node: ElementSceneNode, context: UiContext): Bool {
    try {
        node.replayLayout(context)
        false
    } catch (_: IllegalStateException) {
        true
    }
}

@Test
func committedSemanticsAttachToTheirGenerationalElementFacet(): Unit {
    let store = StateStore()
    enableAutomaticComposition(store)
    let widget = buildRoot({=> Button("Owned", {=>}).key("owned-semantic")}, store)
    let context = UiContext(Renderer.headless(), Theme.light())
    context.clearSemantics()
    let _ = widget.measure(context, Size(120.0, 40.0))
    widget.layout(context, Rect(0.0, 0.0, 120.0, 40.0))
    context.commitSemantics(arena: Some(store.elementArena))

    let snapshot = context.semanticsTreeSnapshot()
    let owner = snapshot.owner("owned-semantic").getOrThrow()
    @Expect(owner.slot >= 0)
    let element = store.elementArena.resolve(owner).getOrThrow()
    @Expect(element.space.isSome())
    @Expect(element.scene.isSome())
}

private func updatingReleasedSceneNodeFails(node: ElementSceneNode): Bool {
    try {
        let context = UiContext(Renderer.headless(), Theme.light())
        node.publishLayout(
            ElementLayoutCommit(Rect.zero(), None, PaintOutset(), context.uiEnvironmentKey(),
                ElementLayoutEffects(None<OverlaySnapshot>, None<SemanticFragment>)))
        false
    } catch (_: IllegalStateException) {
        true
    }
}

private func failingElementBuildWasRejected(store: StateStore): Bool {
    try {
        let _ = buildRoot(
            {
                =>
                    RetainedSubtree("transient") {Spacer()}
                    throw IllegalArgumentException("probe")
            },
            store
        )
        false
    } catch (_: IllegalArgumentException) {
        true
    }
}
