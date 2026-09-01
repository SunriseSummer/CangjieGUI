package cui.core

import std.collection.{ArrayList, HashMap}

/* Stable generational handle for one persistent declarative element. */
struct ElementId {
    let slot: Int64
    let generation: UInt64

    init(slot: Int64, generation: UInt64) {
        this.slot = slot
        this.generation = generation
    }

    static func detached(): ElementId {
        ElementId(-1, UInt64(0))
    }
}

enum ElementKind {
    | Root
    | Retained
    | Automatic
}

/*
 * One authoritative persistent identity with compatibility facets for the structures being
 * migrated. The facets point at existing records; they do not copy lifecycle or phase state.
 */
class ElementRecord {
    let id: ElementId
    let path: String
    let kind: ElementKind
    let parent: ?ElementId
    let children = ArrayList<ElementId>()
    var mountScope: ?StateMountScope = None
    var retained: ?RetainedRecord = None
    var automatic: ?AutomaticCompositionRecord = None
    var scene: ?ElementSceneFacet = None
    var space: ?ElementSpaceFacet = None

    init(id: ElementId, path: String, kind: ElementKind, parent: ?ElementId) {
        this.id = id
        this.path = path
        this.kind = kind
        this.parent = parent
    }
}

/*
 * Application-local slot arena. Paths are only the reconciliation lookup key; once mounted,
 * subsystems carry ElementId so slot reuse cannot alias a stale reference.
 */
class ElementArena {
    private let records = ArrayList<?ElementRecord>()
    private let generations = ArrayList<UInt64>()
    private let freeSlots = ArrayList<Int64>()
    private let idsByPath = HashMap<String, ElementId>()
    private var structureRevisionValue: UInt64 = UInt64(0)
    let rootId: ElementId

    init() {
        rootId = ElementId(0, UInt64(1))
        generations.add(rootId.generation)
        records.add(Some(ElementRecord(rootId, "<root>", ElementKind.Root, None)))
        let _ = idsByPath.add("<root>", rootId) // cjcheck-ignore: ignore-result # the arena is empty during construction
    }

    func mount(path: String, parent: ElementId, kind: ElementKind): ElementId {
        if (idsByPath.contains(path)) {
            throw IllegalStateException("Element path '${path}' is already mounted")
        }
        let parentRecord = requireRecord(parent)
        let id = allocateId()
        let record = ElementRecord(id, path, kind, Some(parent))
        records[id.slot] = Some(record)
        let _ = idsByPath.add(path, id) // cjcheck-ignore: ignore-result # duplicate paths were rejected above
        parentRecord.children.add(id)
        structureRevisionValue = nextRevision(structureRevisionValue)
        id
    }

    func attachMountScope(id: ElementId, scope: StateMountScope): Unit {
        requireRecord(id).mountScope = Some(scope)
    }

    func attachRetained(id: ElementId, record: RetainedRecord): Unit {
        let element = requireKind(id, ElementKind.Retained)
        element.retained = Some(record)
    }

    func attachAutomatic(id: ElementId, record: AutomaticCompositionRecord): Unit {
        let element = requireKind(id, ElementKind.Automatic)
        element.automatic = Some(record)
    }

    func sceneFacet(id: ElementId): ElementSceneFacet {
        let element = requireRecord(id)
        match (element.scene) {
            case Some(facet) => facet
            case None =>
                let facet = ElementSceneFacet(id, spaceFacet(id))
                element.scene = Some(facet)
                facet
        }
    }

    func spaceFacet(id: ElementId): ElementSpaceFacet {
        let element = requireRecord(id)
        match (element.space) {
            case Some(facet) => facet
            case None =>
                let facet = ElementSpaceFacet(id)
                element.space = Some(facet)
                facet
        }
    }

    func resolve(id: ElementId): ?ElementRecord {
        if (id.slot < 0 || id.slot >= records.size || generations[id.slot] != id.generation) {
            return None
        }
        records[id.slot]
    }

    func idForPath(path: String): ?ElementId {
        idsByPath.get(path)
    }

    func release(id: ElementId): Unit {
        let record = requireRecord(id)
        if (sameElementId(id, rootId)) {
            throw IllegalStateException("The root Element cannot be released")
        }
        if (!record.children.isEmpty()) {
            throw IllegalStateException("Element '${record.path}' still owns ${record.children.size} child elements")
        }
        match (record.scene) {
            case Some(facet) =>
                if (facet.liveCount() > 0) {
                    throw IllegalStateException(
                        "Element '${record.path}' still owns ${facet.liveCount()} scene nodes at scene revision " +
                            "${facet.structureRevision()}")
                }
            case None => ()
        }
        match (record.space) {
            case Some(facet) =>
                if (facet.liveSceneCount() > 0) {
                    throw IllegalStateException(
                        "Element '${record.path}' still owns ${facet.liveSceneCount()} spatial scene nodes at space " +
                            "revision ${facet.spatialRevision()}")
                }
            case None => ()
        }
        match (record.parent) {
            case Some(parent) => removeChild(requireRecord(parent), id)
            case None => ()
        }
        let _ = idsByPath.remove(record.path) // cjcheck-ignore: ignore-result # path and record are installed atomically
        records[id.slot] = None
        freeSlots.add(id.slot)
        structureRevisionValue = nextRevision(structureRevisionValue)
    }

    func releaseIfLive(id: ElementId): Unit {
        if (resolve(id).isSome()) {
            release(id)
        }
    }

    func clear(): Unit {
        let hadMountedElements = idsByPath.size > 1
        let root = requireRecord(rootId)
        root.children.clear()
        idsByPath.clear()
        let _ = idsByPath.add(root.path, rootId) // cjcheck-ignore: ignore-result # the path index was just cleared
        freeSlots.clear()
        var slot: Int64 = 1
        while (slot < records.size) {
            records[slot] = None
            generations[slot] = nextRevision(generations[slot])
            freeSlots.add(slot)
            slot += 1
        }
        if (hadMountedElements) {
            structureRevisionValue = nextRevision(structureRevisionValue)
        }
    }

    /* Monotonic version of successful parent/child topology mutations. */
    func structureRevision(): UInt64 {
        structureRevisionValue
    }

    /** Number of currently mounted compatibility elements, including the root. */
    protected func liveCount(): Int64 {
        Int64(idsByPath.size)
    }

    private func allocateId(): ElementId {
        if (!freeSlots.isEmpty()) {
            let last = freeSlots.size - 1
            let slot = freeSlots[last]
            freeSlots.remove(at: last)
            generations[slot] = nextRevision(generations[slot])
            return ElementId(slot, generations[slot])
        }
        let slot = records.size
        records.add(None)
        generations.add(UInt64(1))
        ElementId(slot, UInt64(1))
    }

    private func requireRecord(id: ElementId): ElementRecord {
        match (resolve(id)) {
            case Some(record) => record
            case None => throw IllegalStateException(
                "Stale or detached ElementId(slot=${id.slot}, generation=${id.generation})")
        }
    }

    private func requireKind(id: ElementId, expected: ElementKind): ElementRecord {
        let record = requireRecord(id)
        if (!sameElementKind(record.kind, expected)) {
            throw IllegalStateException("Element '${record.path}' has an incompatible facet kind")
        }
        record
    }

    private func removeChild(parent: ElementRecord, child: ElementId): Unit {
        var index = parent.children.size - 1
        while (index >= 0) {
            if (sameElementId(parent.children[index], child)) {
                parent.children.remove(at: index)
                return
            }
            index -= 1
        }
        throw IllegalStateException("Element parent/child ownership is inconsistent")
    }
}

func sameElementId(left: ElementId, right: ElementId): Bool {
    left.slot == right.slot && left.generation == right.generation
}

private func sameElementKind(left: ElementKind, right: ElementKind): Bool {
    match ((left, right)) {
        case (ElementKind.Root, ElementKind.Root) => true
        case (ElementKind.Retained, ElementKind.Retained) => true
        case (ElementKind.Automatic, ElementKind.Automatic) => true
        case _ => false
    }
}

func createElementMountScope(
    store: StateStore,
    path: String,
    diagnosticPath: String,
    kind: ElementKind
): StateMountScope {
    let parent = currentMountScope(store)
    let id = store.elementArena.mount(path, parent.elementId, kind)
    store.elementAddedDuringBuild.add(id)
    let scope = StateMountScope(parent, diagnosticPath, id)
    store.elementArena.attachMountScope(id, scope)
    scope
}
