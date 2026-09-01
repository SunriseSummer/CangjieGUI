package cui.core

import std.collection.ArrayList
import sdl.{Rect, RenderCommandBuffer, RenderCommandSlot, Renderer, Size}

/* Stable identity for one retained paint slot owned by a generational Element. */
struct SceneNodeId {
    let owner: ElementId
    let slot: Int64
    let generation: UInt64

    init(owner: ElementId, slot: Int64, generation: UInt64) {
        this.owner = owner
        this.slot = slot
        this.generation = generation
    }

    static func detached(): SceneNodeId {
        SceneNodeId(ElementId.detached(), -1, UInt64(0))
    }
}

/*
 * One patchable leaf in the retained scene. The stable command slot is the actual hierarchical
 * patch boundary: ancestors retain its identity and see an immutable buffer replacement without
 * copying the child's commands or resources.
 */
class ElementSceneNode {
    let id: SceneNodeId
    private let owner: ?ElementSceneFacet
    private let geometry: ElementSceneSpace
    private var commands = RenderCommandSlot()
    private var revision: UInt64 = UInt64(0)
    private var commandCount: Int64 = 0
    private var estimatedCommandBytes: UInt64 = UInt64(0)
    private var alive = true

    init(id: SceneNodeId, owner: ?ElementSceneFacet, geometry: ElementSceneSpace) {
        this.id = id
        this.owner = owner
        this.geometry = geometry
    }

    func measureMatches(available: Size, environment: UiEnvironmentKey): Bool {
        ensureAlive("inspect measured size")
        geometry.measureMatches(available, environment)
    }

    func measuredSize(): Size {
        ensureAlive("read measured size")
        geometry.measuredSize()
    }

    func publishMeasure(available: Size, environment: UiEnvironmentKey, result: Size): Unit {
        ensureAlive("publish measured size")
        let invalidatedLayout = geometry.hasLayout()
        geometry.publishMeasure(available, environment, result)
        if (invalidatedLayout) {
            revision = nextRevision(revision)
        }
    }

    func invalidateMeasure(): Unit {
        ensureAlive("invalidate measured size")
        let invalidatedLayout = geometry.hasLayout()
        geometry.invalidateMeasure()
        if (invalidatedLayout) {
            revision = nextRevision(revision)
        }
    }

    func hasMeasure(): Bool {
        ensureAlive("inspect measurement validity")
        geometry.hasMeasure()
    }

    func publishLayout(value: ElementLayoutCommit): Unit {
        ensureAlive("publish layout")
        if (geometry.publishLayout(value)) {
            geometry.observePaintBounds(None)
            commands.clear()
            commands = RenderCommandSlot()
            commands.setReplayBounds(value.declaredPaintBounds)
            clearCommandStats()
        }
        revision = nextRevision(revision)
    }

    func layoutMatches(
        bounds: Rect,
        visibilityClip: ?Rect,
        paintOutset: PaintOutset,
        environment: UiEnvironmentKey
    ): Bool {
        ensureAlive("inspect layout")
        geometry.layoutMatches(bounds, visibilityClip, paintOutset, environment)
    }

    func replayLayout(ctx: UiContext): Unit {
        ensureAlive("replay layout")
        geometry.replayLayout(ctx)
    }

    func layoutEnvironmentMatches(environment: UiEnvironmentKey): Bool {
        ensureAlive("inspect layout environment")
        geometry.layoutEnvironmentMatches(environment)
    }

    func invalidateLayout(): Unit {
        ensureAlive("invalidate layout")
        let hadLayout = geometry.hasLayout()
        geometry.invalidateLayout()
        if (hadLayout) {
            revision = nextRevision(revision)
        }
    }

    func hasLayout(): Bool {
        ensureAlive("inspect layout validity")
        geometry.hasLayout()
    }

    func paintGeometryMatches(bounds: Rect, paintOutset: PaintOutset): Bool {
        ensureAlive("inspect paint layout")
        geometry.paintGeometryMatches(bounds, paintOutset)
    }

    func layoutBounds(): Rect {
        ensureAlive("inspect layout bounds")
        geometry.committedLayoutBounds()
    }

    func observePaintBounds(bounds: ?Rect): Unit {
        ensureAlive("observe paint bounds")
        geometry.observePaintBounds(bounds)
    }

    func publish(buffer: RenderCommandBuffer): Unit {
        ensureAlive("publish commands")
        commands.replace(buffer)
        let stats = buffer.stats()
        commandCount = stats.commandCount
        estimatedCommandBytes = stats.estimatedBytes
        geometry.observePaintBounds(buffer.paintBounds())
        revision = nextRevision(revision)
    }

    func invalidateCommands(resetBounds!: Bool): Unit {
        ensureAlive("invalidate commands")
        let hadCommands = commands.hasCommands()
        commands.clear()
        clearCommandStats()
        if (resetBounds) {
            geometry.observePaintBounds(None)
        }
        if (hadCommands) {
            revision = nextRevision(revision)
        }
    }

    func replay(renderer: Renderer, damage: ?Rect): Bool {
        ensureAlive("replay commands")
        match (damage) {
            case Some(value) => commands.replayIntersecting(renderer, value)
            case None => commands.replay(renderer)
        }
    }

    func hasCommands(): Bool {
        ensureAlive("inspect commands")
        commands.hasCommands()
    }

    func paintBounds(): Rect {
        ensureAlive("inspect paint bounds")
        geometry.paintBounds()
    }

    func commandStats(): (Int64, UInt64) {
        ensureAlive("inspect command stats")
        (commandCount, estimatedCommandBytes)
    }

    func eventTopology(childCount: Int64): ChildEventTopology {
        ensureAlive("resolve event topology")
        geometry.eventTopology(childCount)
    }

    func stagedEventTopologyCommit(): ElementEventTopologyCommit {
        ensureAlive("capture staged event topology")
        geometry.stagedEventTopologyCommit()
    }

    func discardStagedEventTopology(): Unit {
        ensureAlive("discard staged event topology")
        geometry.discardStagedEventTopology()
    }

    func contentRevision(): UInt64 {
        ensureAlive("inspect content revision")
        revision
    }

    func close(): Unit {
        if (!alive) {
            return
        }
        commands.clear()
        clearCommandStats()
        match (owner) {
            case Some(facet) => facet.release(id)
            case None => geometry.releaseDetached()
        }
        alive = false
    }

    private func ensureAlive(operation: String): Unit {
        if (!alive) {
            throw IllegalStateException("Cannot ${operation} through a released scene node")
        }
    }

    private func clearCommandStats(): Unit {
        commandCount = 0
        estimatedCommandBytes = UInt64(0)
    }
}

/* Generational positional scene slots owned by exactly one Element. */
class ElementSceneFacet {
    private let owner: ElementId
    private let space: ElementSpaceFacet
    private let nodes = ArrayList<?ElementSceneNode>()
    private let generations = ArrayList<UInt64>()
    private var revision: UInt64 = UInt64(0)

    init(owner: ElementId, space: ElementSpaceFacet) {
        this.owner = owner
        this.space = space
    }

    func acquire(slot: Int64): ElementSceneNode {
        if (slot < 0) {
            throw IllegalArgumentException("Scene slot must not be negative")
        }
        ensureSlot(slot)
        if (nodes[slot].isSome()) {
            throw IllegalStateException("Element scene slot ${slot} is already mounted")
        }
        generations[slot] = nextRevision(generations[slot])
        let id = SceneNodeId(owner, slot, generations[slot])
        let geometry = space.acquireScene(id)
        let node = ElementSceneNode(id, Some(this), geometry)
        nodes[slot] = Some(node)
        revision = nextRevision(revision)
        node
    }

    func resolve(id: SceneNodeId): ?ElementSceneNode {
        if (!sameSceneNodeOwner(id, owner) || id.slot < 0 || id.slot >= nodes.size || generations[id.slot] != id
            .generation) {
            return None
        }
        nodes[id.slot]
    }

    func release(id: SceneNodeId): Unit {
        if (resolve(id).isNone()) {
            throw IllegalStateException(
                "Stale scene node id(slot=${id.slot}, generation=${id.generation}) for Element ${owner.slot}")
        }
        space.releaseScene(id)
        nodes[id.slot] = None
        revision = nextRevision(revision)
    }

    func liveCount(): Int64 {
        var count: Int64 = 0
        for (node in nodes) {
            if (node.isSome()) {
                count += 1
            }
        }
        count
    }

    func structureRevision(): UInt64 {
        revision
    }

    private func ensureSlot(slot: Int64): Unit {
        while (nodes.size <= slot) {
            nodes.add(None)
            generations.add(UInt64(0))
        }
    }
}

func detachedElementSceneNode(): ElementSceneNode {
    let id = SceneNodeId.detached()
    ElementSceneNode(id, None, detachedElementSceneSpace(id))
}

private func sameSceneNodeOwner(id: SceneNodeId, owner: ElementId): Bool {
    sameElementId(id.owner, owner)
}
