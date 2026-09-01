package cui.core

import std.collection.{ArrayList, HashMap}
import sdl.Rect

/** One deterministic delta in a committed accessibility tree. */
public enum SemanticsChange {
    | Added(String)
    | Removed(String)
    | Updated(String)
    | Moved(String, Int64, Int64)
    | FocusChanged(String, String)
}

/** Immutable, indexed semantics from the last stable layout transaction. */
public class SemanticsSnapshot {
    public let revision: UInt64
    public let nodes: Array<SemanticsNode>
    public let focusedId: String
    private let indexById: HashMap<String, Int64>
    private let ownersById: HashMap<String, ElementId>
    private let parentIndices: Array<Int64>
    private let previousSiblingIndices: Array<Int64>
    private let nextSiblingIndices: Array<Int64>
    private let firstChildIndices: Array<Int64>
    private let lastChildIndices: Array<Int64>
    private let firstRootIndex: Int64
    private let lastRootIndex: Int64
    private let spatialNodes = ArrayList<OrderedSpatialNode>()
    private var spatialRoot: Int64 = -1

    internal init(
        revision: UInt64,
        nodes: Array<SemanticsNode>,
        ownersById: HashMap<String, ElementId>,
        focusedId!: String = "",
        topology!: ?SemanticTopology = None
    ) {
        this.revision = revision
        this.nodes = nodes
        this.focusedId = focusedId
        this.indexById = HashMap<String, Int64>()
        this.ownersById = ownersById
        let resolvedTopology = match (topology) {
            case Some(value) => value
            case None => flatSemanticTopology(nodes.size)
        }
        this.parentIndices = resolvedTopology.parents
        this.previousSiblingIndices = resolvedTopology.previousSiblings
        this.nextSiblingIndices = resolvedTopology.nextSiblings
        this.firstChildIndices = resolvedTopology.firstChildren
        this.lastChildIndices = resolvedTopology.lastChildren
        this.firstRootIndex = resolvedTopology.firstRoot
        this.lastRootIndex = resolvedTopology.lastRoot
        for (index in 0..nodes.size) {
            let _ = indexById.add(nodes[index].id, index) // cjcheck-ignore: ignore-result # normalized snapshots contain one latest node per id
        }
        spatialRoot = if (nodes.isEmpty()) {
            -1
        } else {
            buildSpatialNode(0, nodes.size)
        }
    }

    /** Resolves a semantic id without scanning the full snapshot. */
    public func node(id: String): ?SemanticsNode {
        match (indexById.get(id)) {
            case Some(index) => Some(nodes[index])
            case None => None
        }
    }

    /** Returns the visually top-most semantic node whose positive-area bounds contain the point. */
    public func nodeAt(x: Float32, y: Float32): ?SemanticsNode {
        if (spatialRoot < 0) {
            return None
        }
        nodeAtSpatial(x, y, spatialRoot)
    }

    /** Returns the nearest semantic ancestor, or `None` for a fragment-root child. */
    public func parent(id: String): ?SemanticsNode {
        relatedNode(id, parentIndices)
    }

    /** Returns the preceding semantic sibling in declaration order. */
    public func previousSibling(id: String): ?SemanticsNode {
        relatedNode(id, previousSiblingIndices)
    }

    /** Returns the following semantic sibling in declaration order. */
    public func nextSibling(id: String): ?SemanticsNode {
        relatedNode(id, nextSiblingIndices)
    }

    /** Returns the first semantic child in declaration order. */
    public func firstChild(id: String): ?SemanticsNode {
        relatedNode(id, firstChildIndices)
    }

    /** Returns the last semantic child in declaration order. */
    public func lastChild(id: String): ?SemanticsNode {
        relatedNode(id, lastChildIndices)
    }

    /** Returns the first semantic node hosted directly by the fragment root. */
    public func firstRootChild(): ?SemanticsNode {
        nodeAtIndex(firstRootIndex)
    }

    /** Returns the last semantic node hosted directly by the fragment root. */
    public func lastRootChild(): ?SemanticsNode {
        nodeAtIndex(lastRootIndex)
    }

    /** Returns the parent index for a node index, or `-1` for roots and invalid indexes. */
    public func parentIndexAt(index: Int64): Int64 {
        if (index < 0 || index >= parentIndices.size) {
            -1
        } else {
            parentIndices[index]
        }
    }

    func owner(id: String): ?ElementId {
        ownersById.get(id)
    }

    private func relatedNode(id: String, relations: Array<Int64>): ?SemanticsNode {
        match (indexById.get(id)) {
            case Some(index) => nodeAtIndex(relations[index])
            case None => None
        }
    }

    private func nodeAtIndex(index: Int64): ?SemanticsNode {
        if (index < 0 || index >= nodes.size) {
            None
        } else {
            Some(nodes[index])
        }
    }

    private func buildSpatialNode(begin: Int64, end: Int64): Int64 {
        if (end - begin == 1) {
            let bounds = nodes[begin].visibleBounds
            let hasBounds = bounds.w > 0.0 && bounds.h > 0.0
            let hasUnbounded = false
            spatialNodes.add(OrderedSpatialNode(begin, end, -1, -1, bounds, hasBounds, hasUnbounded))
            return spatialNodes.size - 1
        }
        let middle = begin + (end - begin) / 2
        let left = buildSpatialNode(begin, middle)
        let right = buildSpatialNode(middle, end)
        spatialNodes.add(orderedSpatialBranch(begin, end, left, right, spatialNodes[left], spatialNodes[right]))
        spatialNodes.size - 1
    }

    private func nodeAtSpatial(x: Float32, y: Float32, nodeIndex: Int64): ?SemanticsNode {
        let spatial = spatialNodes[nodeIndex]
        if (!spatial.hasBounds || !spatial.bounds.contains(x, y)) {
            return None
        }
        if (spatial.isLeaf()) {
            return Some(nodes[spatial.begin])
        }
        match (nodeAtSpatial(x, y, spatial.right)) {
            case Some(node) => Some(node)
            case None => nodeAtSpatial(x, y, spatial.left)
        }
    }
}

class SemanticTopology {
    let parents: Array<Int64>
    let previousSiblings: Array<Int64>
    let nextSiblings: Array<Int64>
    let firstChildren: Array<Int64>
    let lastChildren: Array<Int64>
    let firstRoot: Int64
    let lastRoot: Int64

    init(
        parents: Array<Int64>,
        previousSiblings: Array<Int64>,
        nextSiblings: Array<Int64>,
        firstChildren: Array<Int64>,
        lastChildren: Array<Int64>,
        firstRoot: Int64,
        lastRoot: Int64
    ) {
        this.parents = parents
        this.previousSiblings = previousSiblings
        this.nextSiblings = nextSiblings
        this.firstChildren = firstChildren
        this.lastChildren = lastChildren
        this.firstRoot = firstRoot
        this.lastRoot = lastRoot
    }
}

func flatSemanticTopology(count: Int64): SemanticTopology {
    let parents = Array<Int64>(count, {_ => -1})
    let previous = Array<Int64>(count, {index => index - 1})
    let next = Array<Int64>(count, {
        index => if (index + 1 < count) {
            index + 1
        } else {
            -1
        }
    })
    SemanticTopology(parents, previous, next, Array<Int64>(count, {_ => -1}), Array<Int64>(count, {_ => -1}),
        if (count > 0) {
            0
        } else {
            -1
        }, count - 1)
}

/** Atomic tree patch delivered to an accessibility adapter after a stable layout commits. */
public class AccessibilityUpdate {
    public let previousRevision: UInt64
    public let snapshot: SemanticsSnapshot
    public let changes: Array<SemanticsChange>
    private let perform: (String, SemanticsAction) -> Bool

    internal init(
        previousRevision: UInt64,
        snapshot: SemanticsSnapshot,
        changes: Array<SemanticsChange>,
        perform: (String, SemanticsAction) -> Bool
    ) {
        this.previousRevision = previousRevision
        this.snapshot = snapshot
        this.changes = changes
        this.perform = perform
    }

    /** Routes an adapter action through the latest committed target index. */
    public func performAction(id: String, action: SemanticsAction): Bool {
        perform(id, action)
    }
}

/** Push adapter implemented by a native accessibility bridge or deterministic tooling. */
public interface AccessibilityAdapter {
    /**
     * Applies one complete, revisioned semantic-tree patch. Implementations must return before the
     * next UI transaction and may use `value.performAction` to route supported native actions.
     */
    func update(value: AccessibilityUpdate): Unit
}

class NormalizedSemantics {
    let nodes: Array<SemanticsNode>
    let actionsById: HashMap<String, SemanticActionTarget>
    let ownersById: HashMap<String, ElementId>

    init(
        nodes: Array<SemanticsNode>,
        actionsById: HashMap<String, SemanticActionTarget>,
        ownersById: HashMap<String, ElementId>
    ) {
        this.nodes = nodes
        this.actionsById = actionsById
        this.ownersById = ownersById
    }
}

class CommittedSemantics {
    let snapshot: SemanticsSnapshot
    let actionsById: HashMap<String, SemanticActionTarget>
    let contributions: Array<SemanticContribution>
    let arenaStructureRevision: UInt64

    init(
        snapshot: SemanticsSnapshot,
        actionsById: HashMap<String, SemanticActionTarget>,
        contributions: Array<SemanticContribution>,
        arenaStructureRevision: UInt64
    ) {
        this.snapshot = snapshot
        this.actionsById = actionsById
        this.contributions = contributions
        this.arenaStructureRevision = arenaStructureRevision
    }

    func closeReplacedActions(next: HashMap<String, SemanticActionTarget>): Unit {
        for (node in snapshot.nodes) {
            match ((actionsById.get(node.id), next.get(node.id))) {
                case (Some(previous), Some(candidate)) =>
                    if (!previous.sameRegistration(candidate)) {
                        previous.close()
                    }
                case (Some(previous), None) => previous.close()
                case _ => ()
            }
        }
    }
}

func normalizeSemantics(contributions: ArrayList<SemanticContribution>): NormalizedSemantics {
    let nodes = ArrayList<SemanticsNode>()
    let indexById = HashMap<String, Int64>()
    let actionsById = HashMap<String, SemanticActionTarget>()
    let ownersById = HashMap<String, ElementId>()
    for (contribution in contributions) {
        contribution.collect(nodes, indexById, actionsById, ownersById, false) // cjcheck-ignore: bool-literal-arg # root normalization begins enabled
    }
    NormalizedSemantics(nodes.toArray(), actionsById, ownersById)
}

func semanticsChanges(
    previous: SemanticsSnapshot,
    next: Array<SemanticsNode>,
    nextOwners: HashMap<String, ElementId>,
    nextTopology: SemanticTopology,
    nextFocusedId: String
): Array<SemanticsChange> {
    let previousIndex = semanticIndex(previous.nodes)
    let nextIndex = semanticIndex(next)
    let changes = ArrayList<SemanticsChange>()
    for (node in previous.nodes) {
        if (!nextIndex.contains(node.id)) {
            changes.add(SemanticsChange.Removed(node.id))
        }
    }
    for (index in 0..next.size) {
        let node = next[index]
        match (previousIndex.get(node.id)) {
            case None => changes.add(SemanticsChange.Added(node.id))
            case Some(oldIndex) =>
                if (!sameSemanticsNode(previous.nodes[oldIndex], node) ||
                    !sameSemanticOwner(previous.owner(node.id), nextOwners.get(node.id))) {
                    changes.add(SemanticsChange.Updated(node.id))
                }
                let previousParent = semanticParentId(previous.nodes, previous.parentIndexAt(oldIndex))
                let nextParent = semanticParentId(next, nextTopology.parents[index])
                if (oldIndex != index || previousParent != nextParent) {
                    changes.add(SemanticsChange.Moved(node.id, oldIndex, index))
                }
        }
    }
    if (previous.focusedId != nextFocusedId) {
        changes.add(SemanticsChange.FocusChanged(previous.focusedId, nextFocusedId))
    }
    changes.toArray()
}

private func semanticParentId(nodes: Array<SemanticsNode>, index: Int64): String {
    if (index < 0 || index >= nodes.size) {
        ""
    } else {
        nodes[index].id
    }
}

private func sameSemanticOwner(left: ?ElementId, right: ?ElementId): Bool {
    match ((left, right)) {
        case (Some(a), Some(b)) => sameElementId(a, b)
        case (None, None) => true
        case _ => false
    }
}

func sameSemanticContributionSequence(
    previous: Array<SemanticContribution>,
    current: ArrayList<SemanticContribution>
): Bool {
    if (previous.size != current.size) {
        return false
    }
    for (index in 0..previous.size) {
        let previousObject = match (previous[index] as Object) {
            case Some(value) => value
            case None => return false
        }
        let currentObject = match (current[index] as Object) {
            case Some(value) => value
            case None => return false
        }
        if (!sameObjectReference(previousObject, currentObject)) {
            return false
        }
    }
    true
}

private func semanticIndex(nodes: Array<SemanticsNode>): HashMap<String, Int64> {
    let result = HashMap<String, Int64>()
    for (index in 0..nodes.size) {
        let _ = result.add(nodes[index].id, index) // cjcheck-ignore: ignore-result # nodes were normalized by id
    }
    result
}

private func sameSemanticsNode(left: SemanticsNode, right: SemanticsNode): Bool {
    left.id == right.id && sameSemantics(left.properties, right.properties) && sameSemanticRect(left.bounds,
        right.bounds) && sameSemanticRect(left.visibleBounds, right.visibleBounds) && sameSemanticsActions(left.actions,
        right.actions)
}

private func sameSemantics(left: Semantics, right: Semantics): Bool {
    left.label == right.label && sameSemanticsRole(left.role, right.role) && left.value == right.value && left.hint == right
        .hint && left.enabled == right.enabled && sameOptionalBool(left.selected, right.selected) && sameOptionalBool(
        left.checked, right.checked)
}

private func sameSemanticsRole(left: SemanticsRole, right: SemanticsRole): Bool {
    match ((left, right)) {
        case (SemanticsRole.Generic, SemanticsRole.Generic) | (SemanticsRole.Text, SemanticsRole.Text)
            | (SemanticsRole.Button, SemanticsRole.Button) | (SemanticsRole.TextField, SemanticsRole.TextField)
            | (SemanticsRole.Checkbox, SemanticsRole.Checkbox) | (SemanticsRole.Switch, SemanticsRole.Switch)
            | (SemanticsRole.Slider, SemanticsRole.Slider) | (SemanticsRole.List, SemanticsRole.List)
            | (SemanticsRole.ListItem, SemanticsRole.ListItem) | (SemanticsRole.Image, SemanticsRole.Image)
            | (SemanticsRole.Dialog, SemanticsRole.Dialog) | (SemanticsRole.Menu, SemanticsRole.Menu)
            | (SemanticsRole.MenuItem, SemanticsRole.MenuItem) => true
        case _ => false
    }
}

private func sameSemanticsActions(left: Array<SemanticsAction>, right: Array<SemanticsAction>): Bool {
    if (left.size != right.size) {
        return false
    }
    for (index in 0..left.size) {
        if (!sameSemanticsAction(left[index], right[index])) {
            return false
        }
    }
    true
}

private func sameSemanticsAction(left: SemanticsAction, right: SemanticsAction): Bool {
    match ((left, right)) {
        case (SemanticsAction.Activate, SemanticsAction.Activate) | (SemanticsAction.Focus, SemanticsAction.Focus)
            | (SemanticsAction.Increment, SemanticsAction.Increment)
            | (SemanticsAction.Decrement, SemanticsAction.Decrement) => true
        case (SemanticsAction.SetValue(a), SemanticsAction.SetValue(b)) => a == b
        case _ => false
    }
}

private func sameOptionalBool(left: ?Bool, right: ?Bool): Bool {
    match ((left, right)) {
        case (Some(a), Some(b)) => a == b
        case (None, None) => true
        case _ => false
    }
}

private func sameSemanticRect(left: Rect, right: Rect): Bool {
    left.x == right.x && left.y == right.y && left.w == right.w && left.h == right.h
}
