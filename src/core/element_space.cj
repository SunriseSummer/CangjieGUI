package cui.core

import std.collection.{ArrayList, HashMap, HashSet}
import sdl.Rect

/* Mutable transaction target hidden behind immutable snapshots. */
class ElementSceneSpace {
    let id: SceneNodeId
    private let owner: ?ElementSpaceFacet
    internal var layoutState = ElementLayoutState.Absent
    private var observedPaintBounds: ?Rect = None
    internal var measureCommit: ?ElementMeasureSnapshot = None
    internal var eventTopologyState = ElementEventTopologyState.Empty
    internal var revision: UInt64 = UInt64(0)
    private var alive = true

    init(id: SceneNodeId, owner: ?ElementSpaceFacet) {
        this.id = id
        this.owner = owner
    }

    func observePaintBounds(bounds: ?Rect): Unit {
        ensureAlive("update paint geometry")
        if (sameOptionalSpatialRect(observedPaintBounds, bounds)) {
            return
        }
        observedPaintBounds = bounds
        revision = nextRevision(revision)
        noteOwnerChange()
    }

    func paintBounds(): Rect {
        ensureAlive("inspect paint geometry")
        let declared = match (layoutState) {
            case ElementLayoutState.Current(value) => value.declaredPaintBounds
            case ElementLayoutState.Stale(value) => value.declaredPaintBounds
            case ElementLayoutState.Absent => Rect.zero()
        }
        match (observedPaintBounds) {
            case Some(value) => unionRect(declared, value)
            case None => declared
        }
    }

    /**
     * Captures the committed layout, visibility, paint, and event topology for diagnostics and tests.
     */
    public func snapshot(): ElementSceneSpaceSnapshot {
        ensureAlive("snapshot geometry")
        let eventSnapshot: ?ElementEventTopologySnapshot = match (committedEventTopologyFor(this)) {
            case Some(value) => Some(value.snapshot())
            case None => None
        }
        let (layoutCommitted, layoutBounds, visibleBounds) = match (layoutState) {
            case ElementLayoutState.Current(value) => (true, value.bounds, value.visibleBounds)
            case ElementLayoutState.Stale(value) => (false, value.bounds, value.visibleBounds)
            case ElementLayoutState.Absent => (false, Rect.zero(), Rect.zero())
        }
        ElementSceneSpaceSnapshot(id, revision, layoutCommitted, layoutBounds, visibleBounds, paintBounds(),
            measureCommit, eventSnapshot)
    }

    func releaseDetached(): Unit {
        ensureAlive("release geometry")
        closeElementEventTopologies(this)
        layoutState = ElementLayoutState.Absent
        measureCommit = None
        alive = false
    }

    func markReleased(): Unit {
        ensureAlive("release geometry")
        closeElementEventTopologies(this)
        layoutState = ElementLayoutState.Absent
        measureCommit = None
        alive = false
    }

    internal func noteOwnerChange(): Unit {
        match (owner) {
            case Some(facet) => facet.noteGeometryChange()
            case None => ()
        }
    }

    internal func ensureAlive(operation: String): Unit {
        if (!alive) {
            throw IllegalStateException("Cannot ${operation} through a released Element space node")
        }
    }
}

/* Spatial/accessibility facet attached to one generational Element owner. */
class ElementSpaceFacet {
    let owner: ElementId
    private let sceneSpaces = ArrayList<?ElementSceneSpace>()
    private var revision: UInt64 = UInt64(0)
    private var semanticRevision: UInt64 = UInt64(0)
    private var semanticSnapshot: ?SemanticsSnapshot = None
    private var primarySemanticIndex: Int64 = -1
    private var extraSemanticIndices: ?ArrayList<Int64> = None

    init(owner: ElementId) {
        this.owner = owner
    }

    func acquireScene(id: SceneNodeId): ElementSceneSpace {
        if (!sameElementId(owner, id.owner) || id.slot < 0) {
            throw IllegalArgumentException("Scene geometry must use a non-negative slot owned by this Element")
        }
        while (sceneSpaces.size <= id.slot) {
            sceneSpaces.add(None)
        }
        if (sceneSpaces[id.slot].isSome()) {
            throw IllegalStateException("Element space slot ${id.slot} is already mounted")
        }
        let space = ElementSceneSpace(id, Some(this))
        sceneSpaces[id.slot] = Some(space)
        revision = nextRevision(revision)
        space
    }

    func resolveScene(id: SceneNodeId): ?ElementSceneSpace {
        if (!sameElementId(owner, id.owner) || id.slot < 0 || id.slot >= sceneSpaces.size) {
            return None
        }
        match (sceneSpaces[id.slot]) {
            case Some(space) where sameSceneSpaceId(space.id, id) => Some(space)
            case _ => None
        }
    }

    func releaseScene(id: SceneNodeId): Unit {
        let space = match (resolveScene(id)) {
            case Some(value) => value
            case None => throw IllegalStateException(
                "Stale scene geometry(slot=${id.slot}, generation=${id.generation}) for Element ${owner.slot}")
        }
        space.markReleased()
        sceneSpaces[id.slot] = None
        revision = nextRevision(revision)
    }

    func liveSceneCount(): Int64 {
        var count: Int64 = 0
        for (space in sceneSpaces) {
            if (space.isSome()) {
                count += 1
            }
        }
        count
    }

    func spatialRevision(): UInt64 {
        revision
    }

    func noteGeometryChange(): Unit {
        revision = nextRevision(revision)
    }

    func beginSemantics(revision: UInt64, snapshot: SemanticsSnapshot): Unit {
        semanticRevision = revision
        semanticSnapshot = Some(snapshot)
        primarySemanticIndex = -1
        match (extraSemanticIndices) {
            case Some(indices) => indices.clear()
            case None => ()
        }
        this.revision = nextRevision(this.revision)
    }

    func appendSemanticIndex(index: Int64): Unit {
        if (primarySemanticIndex < 0) {
            primarySemanticIndex = index
            return
        }
        let indices = match (extraSemanticIndices) {
            case Some(value) => value
            case None =>
                let value = ArrayList<Int64>()
                extraSemanticIndices = Some(value)
                value
        }
        indices.add(index)
    }

    func clearSemantics(revision: UInt64): Unit {
        semanticRevision = revision
        semanticSnapshot = None
        primarySemanticIndex = -1
        extraSemanticIndices = None
        this.revision = nextRevision(this.revision)
    }
}

/* Reconciles semantic membership only for owners touched by the previous or next snapshot. */
func commitElementSemanticOwnership(
    arena: ElementArena,
    previous: SemanticsSnapshot,
    next: SemanticsSnapshot
): Unit {
    let nextOwners = HashSet<Int64>()
    for (node in next.nodes) {
        match (liveSemanticOwner(arena, next, node.id)) {
            case Some(owner) => let _ = nextOwners.add(owner.slot)
            case None => ()
        }
    }

    let cleared = HashSet<Int64>()
    for (node in previous.nodes) {
        clearPreviousSemanticOwner(arena, previous, next.revision, nextOwners, cleared, node.id)
    }

    let initialized = HashSet<Int64>()
    for (index in 0..next.nodes.size) {
        let owner = match (liveSemanticOwner(arena, next, next.nodes[index].id)) {
            case Some(value) => value
            case None => continue
        }
        let facet = arena.spaceFacet(owner)
        if (initialized.add(owner.slot)) {
            facet.beginSemantics(next.revision, next)
        }
        facet.appendSemanticIndex(index)
    }
}

private func clearPreviousSemanticOwner(
    arena: ElementArena,
    previous: SemanticsSnapshot,
    revision: UInt64,
    nextOwners: HashSet<Int64>,
    cleared: HashSet<Int64>,
    id: String
): Unit {
    let owner = match (previous.owner(id)) {
        case Some(value) => value
        case None => return
    }
    if (nextOwners.contains(owner.slot) || !cleared.add(owner.slot)) {
        return
    }
    let record = match (arena.resolve(owner)) {
        case Some(value) => value
        case None => return
    }
    match (record.space) {
        case Some(facet) => facet.clearSemantics(revision)
        case None => ()
    }
}

private func liveSemanticOwner(
    arena: ElementArena,
    snapshot: SemanticsSnapshot,
    id: String
): ?ElementId {
    let owner = match (snapshot.owner(id)) {
        case Some(value) => value
        case None => return None
    }
    match (arena.resolve(owner)) {
        case Some(_) => Some(owner)
        case None => None
    }
}

/*
 * Projects the Element ownership tree onto semantic owners. This is the tree quotient induced by
 * "has semantic output": unlabelled Elements are contracted and every node is attached to its
 * nearest labelled ancestor. Path compression keeps the total ancestor walk linear in the covered
 * Element ancestry instead of quadratic for deeply nested layouts.
 */
func semanticTopologyFor(
    arena: ElementArena,
    nodes: Array<SemanticsNode>,
    ownersById: HashMap<String, ElementId>
): SemanticTopology {
    let lastSemanticByOwner = HashMap<Int64, Int64>()
    for (index in 0..nodes.size) {
        match (ownersById.get(nodes[index].id)) {
            case Some(owner) where owner.slot >= 0 => let _ = lastSemanticByOwner.add(owner.slot, index)
            case _ => ()
        }
    }

    let nearestSemanticByElement = HashMap<Int64, Int64>()
    let parents = Array<Int64>(nodes.size, {_ => -1})
    for (index in 0..nodes.size) {
        match (ownersById.get(nodes[index].id)) {
            case Some(owner) where owner.slot >= 0 => parents[index] = nearestSemanticAncestor(arena, owner,
                lastSemanticByOwner, nearestSemanticByElement)
            case _ => ()
        }
    }
    linkedSemanticTopology(parents)
}

private func nearestSemanticAncestor(
    arena: ElementArena,
    owner: ElementId,
    semanticByOwner: HashMap<Int64, Int64>,
    cache: HashMap<Int64, Int64>
): Int64 {
    let visited = ArrayList<ElementId>()
    var current: ?ElementId = match (arena.resolve(owner)) {
        case Some(record) => record.parent
        case None => None<ElementId>
    }
    var result: Int64 = -1
    while (let Some(id) <- current) {
        match (semanticByOwner.get(id.slot)) {
            case Some(index) =>
                result = index
                break
            case None => ()
        }
        match (cache.get(id.slot)) {
            case Some(index) =>
                result = index
                break
            case None => visited.add(id)
        }
        current = match (arena.resolve(id)) {
            case Some(record) => record.parent
            case None => None<ElementId>
        }
    }
    for (id in visited) {
        let _ = cache.add(id.slot, result) // cjcheck-ignore: ignore-result # path compression intentionally overwrites an equivalent cached owner
    }
    result
}

private func linkedSemanticTopology(parents: Array<Int64>): SemanticTopology {
    let count = parents.size
    let previous = Array<Int64>(count, {_ => -1})
    let next = Array<Int64>(count, {_ => -1})
    let first = Array<Int64>(count, {_ => -1})
    let last = Array<Int64>(count, {_ => -1})
    var firstRoot: Int64 = -1
    var lastRoot: Int64 = -1
    for (index in 0..count) {
        let parent = parents[index]
        if (parent < 0) {
            if (firstRoot < 0) {
                firstRoot = index
            }
            if (lastRoot >= 0) {
                previous[index] = lastRoot
                next[lastRoot] = index
            }
            lastRoot = index
        } else {
            if (first[parent] < 0) {
                first[parent] = index
            }
            if (last[parent] >= 0) {
                previous[index] = last[parent]
                next[last[parent]] = index
            }
            last[parent] = index
        }
    }
    SemanticTopology(parents, previous, next, first, last, firstRoot, lastRoot)
}

func detachedElementSceneSpace(id: SceneNodeId): ElementSceneSpace {
    ElementSceneSpace(id, None)
}

private func sameSceneSpaceId(left: SceneNodeId, right: SceneNodeId): Bool {
    sameElementId(left.owner, right.owner) && left.slot == right.slot && left.generation == right.generation
}
