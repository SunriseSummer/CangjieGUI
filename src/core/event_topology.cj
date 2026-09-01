package cui.core

import std.collection.ArrayList
import sdl.{Rect, UiEvent}

/**
 * Declares whether a Widget subtree can observe pointer events outside the rectangle assigned by
 * its parent. `Unbounded` preserves the compatibility contract for custom widgets. A subtree may
 * return `LayoutBounds` only when every pointer handler below it is confined to that rectangle;
 * multi-child containers can then omit it from point routing without changing event semantics.
 */
public enum PointerEventScope {
    | Unbounded
    | LayoutBounds
}

private struct PointerEventPoint {
    let x: Float32
    let y: Float32

    init(x: Float32, y: Float32) {
        this.x = x
        this.y = y
    }
}

/* Immutable metadata from the last completed child-event layout transaction. */
struct ElementEventTopologySnapshot {
    let revision: UInt64
    let childCount: Int64
    let containerBounds: Rect
    let hasIndex: Bool
    let allChildrenConfined: Bool

    init(
        revision: UInt64,
        childCount: Int64,
        containerBounds: Rect,
        hasIndex: Bool,
        allChildrenConfined: Bool
    ) {
        this.revision = revision
        this.childCount = childCount
        this.containerBounds = containerBounds
        this.hasIndex = hasIndex
        this.allChildrenConfined = allChildrenConfined
    }
}

/* Event-routing contribution carried by one atomic Element layout commit. */
enum ElementEventTopologyCommit {
    | Preserve
    | Replace(ChildEventTopology)
    | Clear
}

/* The five legal phases of one pending event-topology layout transaction. */
enum ChildEventTopologyLayoutPhase {
    | Idle
    | RecordingClean
    | RecordingDirty
    | ReadyClean
    | ReadyDirty
}

/*
 * Layout-owned point-routing index for one ordered child array. The committed arrays are the read
 * face used by event dispatch; layout writes only the pending arrays. Standalone containers publish
 * at commitLayout(), while Element-owned containers defer the O(1) buffer swap to LayoutCommit.
 */
class ChildEventTopology {
    private var childBounds: Array<Rect>
    private var childWasLaidOut: Array<Bool>
    private var childUsesLayoutBounds: Array<Bool>
    private var nodes = ArrayList<OrderedSpatialNode>()
    private var root: Int64 = -1
    private var hasBoundedChildren = false
    private var allChildrenConfined = false
    private var committedContainerBounds = Rect.zero()
    private var hasCommittedLayout = false
    private var pendingChildBounds: Array<Rect>
    private var pendingChildWasLaidOut: Array<Bool>
    private var pendingChildUsesLayoutBounds: Array<Bool>
    private var pendingNodes = ArrayList<OrderedSpatialNode>()
    private var pendingRoot: Int64 = -1
    private var pendingAllChildrenConfined = false
    private var pendingContainerBounds = Rect.zero()
    private var layoutPhase = ChildEventTopologyLayoutPhase.Idle
    private var pendingHasBoundedChildren = false
    private let deferredPublication: Bool
    private var revision: UInt64 = UInt64(0)
    private var alive = true

    init(childCount: Int64, deferredPublication!: Bool = false) {
        childBounds = Array<Rect>(childCount, {_ => Rect.zero()})
        childWasLaidOut = Array<Bool>(childCount, {_ => false})
        childUsesLayoutBounds = Array<Bool>(childCount, {_ => false})
        pendingChildBounds = Array<Rect>(childCount, {_ => Rect.zero()})
        pendingChildWasLaidOut = Array<Bool>(childCount, {_ => false})
        pendingChildUsesLayoutBounds = Array<Bool>(childCount, {_ => false})
        this.deferredPublication = deferredPublication
    }

    func beginLayout(): Unit {
        ensureAlive("begin event topology layout")
        layoutPhase = if (hasCommittedLayout) {
            ChildEventTopologyLayoutPhase.RecordingClean
        } else {
            ChildEventTopologyLayoutPhase.RecordingDirty
        }
        pendingHasBoundedChildren = false
        pendingNodes.clear()
        pendingRoot = -1
        pendingAllChildrenConfined = false
        for (index in 0..pendingChildWasLaidOut.size) {
            pendingChildWasLaidOut[index] = false
            pendingChildUsesLayoutBounds[index] = false
        }
    }

    func noteChildLayout(index: Int64, bounds: Rect, child: Widget): Unit {
        ensureAlive("record event topology child layout")
        let alreadyChanged = recordingHasChanged()
        if (index < 0 || index >= childBounds.size) {
            throw IllegalArgumentException("Child event topology index is out of range")
        }
        let bounded = pointerEventsUseLayoutBounds(child)
        if (!alreadyChanged && (!childWasLaidOut[index] || !sameTopologyRect(childBounds[index], bounds) ||
            childUsesLayoutBounds[index] != bounded)) {
            markRecordingChanged()
        }
        pendingChildBounds[index] = bounds
        pendingChildUsesLayoutBounds[index] = bounded
        pendingChildWasLaidOut[index] = true
        pendingHasBoundedChildren = pendingHasBoundedChildren || bounded
    }

    func commitLayout(children: Array<Widget>, containerBounds: Rect): Unit {
        ensureAlive("commit event topology layout")
        let changedBeforeCommit = recordingHasChanged()
        if (children.size != childBounds.size) {
            throw IllegalStateException("Child event topology no longer matches its child array")
        }
        if (!changedBeforeCommit) {
            for (index in 0..childWasLaidOut.size) {
                if (childWasLaidOut[index] != pendingChildWasLaidOut[index]) {
                    markRecordingChanged()
                    break
                }
            }
        }
        if (!recordingHasChanged() && !sameTopologyRect(committedContainerBounds, containerBounds)) {
            markRecordingChanged()
        }
        pendingContainerBounds = containerBounds
        if (!recordingHasChanged()) {
            finishStagedLayout()
            return
        }
        pendingRoot = if (!pendingHasBoundedChildren || children.isEmpty()) {
            -1
        } else {
            buildPendingNode(0, children.size)
        }
        if (pendingRoot >= 0) {
            pendingHasBoundedChildren = pendingNodes[pendingRoot].hasBounds
            let rootNode = pendingNodes[pendingRoot]
            pendingAllChildrenConfined = !rootNode.hasUnbounded && containsRect(containerBounds, rootNode.bounds)
        }
        finishStagedLayout()
    }

    func hasStagedLayout(): Bool {
        ensureAlive("inspect staged event topology layout")
        match (layoutPhase) {
            case ChildEventTopologyLayoutPhase.ReadyClean | ChildEventTopologyLayoutPhase.ReadyDirty => true
            case _ => false
        }
    }

    func publishStagedLayout(): Unit {
        ensureAlive("publish staged event topology layout")
        match (layoutPhase) {
            case ChildEventTopologyLayoutPhase.ReadyClean =>
                layoutPhase = ChildEventTopologyLayoutPhase.Idle
                return
            case ChildEventTopologyLayoutPhase.ReadyDirty => layoutPhase = ChildEventTopologyLayoutPhase.Idle
            case _ => throw IllegalStateException("Child event topology has no completed layout to publish")
        }
        let previousBounds = childBounds
        childBounds = pendingChildBounds
        pendingChildBounds = previousBounds
        let previousWasLaidOut = childWasLaidOut
        childWasLaidOut = pendingChildWasLaidOut
        pendingChildWasLaidOut = previousWasLaidOut
        let previousUsesLayoutBounds = childUsesLayoutBounds
        childUsesLayoutBounds = pendingChildUsesLayoutBounds
        pendingChildUsesLayoutBounds = previousUsesLayoutBounds
        let previousNodes = nodes
        nodes = pendingNodes
        pendingNodes = previousNodes
        root = pendingRoot
        hasBoundedChildren = pendingHasBoundedChildren
        allChildrenConfined = pendingAllChildrenConfined
        committedContainerBounds = pendingContainerBounds
        hasCommittedLayout = true
        revision = nextRevision(revision)
    }

    func discardStagedLayout(): Unit {
        ensureAlive("discard staged event topology layout")
        layoutPhase = ChildEventTopologyLayoutPhase.Idle
        pendingNodes.clear()
    }

    func pointerEventScope(): PointerEventScope {
        ensureAlive("inspect event topology scope")
        if (allChildrenConfined) {
            PointerEventScope.LayoutBounds
        } else {
            PointerEventScope.Unbounded
        }
    }

    func dispatch(children: Array<Widget>, ctx: UiContext, event: UiEvent): Bool {
        ensureAlive("dispatch through event topology")
        if (root < 0 || !hasBoundedChildren) {
            return dispatchChildrenUnindexed(children, ctx, event)
        }
        match (indexedPoint(ctx, event)) {
            case Some(point) => dispatchNode(children, ctx, event, point, root)
            case _ => dispatchChildrenUnindexed(children, ctx, event)
        }
    }

    func childCount(): Int64 {
        childBounds.size
    }

    func snapshot(): ElementEventTopologySnapshot {
        ensureAlive("snapshot event topology")
        ElementEventTopologySnapshot(revision, childBounds.size, committedContainerBounds, root >= 0 &&
            hasBoundedChildren, allChildrenConfined)
    }

    func close(): Unit {
        if (!alive) {
            return
        }
        nodes.clear()
        pendingNodes.clear()
        root = -1
        pendingRoot = -1
        layoutPhase = ChildEventTopologyLayoutPhase.Idle
        alive = false
    }

    private func ensureAlive(operation: String): Unit {
        if (!alive) {
            throw IllegalStateException("Cannot ${operation} through a released Element event topology")
        }
    }

    private func finishStagedLayout(): Unit {
        layoutPhase = match (layoutPhase) {
            case ChildEventTopologyLayoutPhase.RecordingClean => ChildEventTopologyLayoutPhase.ReadyClean
            case ChildEventTopologyLayoutPhase.RecordingDirty => ChildEventTopologyLayoutPhase.ReadyDirty
            case _ => throw IllegalStateException("Child event topology layout has not begun")
        }
        if (!deferredPublication) {
            publishStagedLayout()
        }
    }

    private func recordingHasChanged(): Bool {
        match (layoutPhase) {
            case ChildEventTopologyLayoutPhase.RecordingClean => false
            case ChildEventTopologyLayoutPhase.RecordingDirty => true
            case _ => throw IllegalStateException("Child event topology layout has not begun")
        }
    }

    private func markRecordingChanged(): Unit {
        match (layoutPhase) {
            case ChildEventTopologyLayoutPhase.RecordingClean => layoutPhase = ChildEventTopologyLayoutPhase
                .RecordingDirty
            case ChildEventTopologyLayoutPhase.RecordingDirty => ()
            case _ => throw IllegalStateException("Child event topology layout has not begun")
        }
    }

    private func buildPendingNode(begin: Int64, end: Int64): Int64 {
        if (end - begin == 1) {
            let bounded = pendingChildWasLaidOut[begin] && pendingChildUsesLayoutBounds[begin]
            pendingNodes.add(OrderedSpatialNode(begin, end, -1, -1, pendingChildBounds[begin], bounded, !bounded))
            return pendingNodes.size - 1
        }
        let middle = begin + (end - begin) / 2
        let left = buildPendingNode(begin, middle)
        let right = buildPendingNode(middle, end)
        let leftNode = pendingNodes[left]
        let rightNode = pendingNodes[right]
        pendingNodes.add(orderedSpatialBranch(begin, end, left, right, leftNode, rightNode))
        pendingNodes.size - 1
    }

    private func dispatchNode(
        children: Array<Widget>,
        ctx: UiContext,
        event: UiEvent,
        point: PointerEventPoint,
        nodeIndex: Int64
    ): Bool {
        let node = nodes[nodeIndex]
        if (!node.hasUnbounded && (!node.hasBounds || !node.bounds.contains(point.x, point.y))) {
            return false
        }
        if (node.isLeaf()) {
            if (node.hasUnbounded || (node.hasBounds && node.bounds.contains(point.x, point.y))) {
                return children[node.begin].handle(ctx, event)
            }
            return false
        }
        if (dispatchNode(children, ctx, event, point, node.right)) {
            return true
        }
        dispatchNode(children, ctx, event, point, node.left)
    }
}

private func pointerEventsUseLayoutBounds(widget: Widget): Bool {
    match (widget.pointerEventScope()) {
        case PointerEventScope.LayoutBounds => true
        case PointerEventScope.Unbounded => false
    }
}

private func containsRect(outer: Rect, inner: Rect): Bool {
    inner.x >= outer.x && inner.y >= outer.y && inner.right() <= outer.right() && inner.bottom() <= outer.bottom()
}

private func sameTopologyRect(left: Rect, right: Rect): Bool {
    left.x.toBits() == right.x.toBits() && left.y.toBits() == right.y.toBits() && left.w.toBits() == right.w.toBits() &&
        left.h.toBits() == right.h.toBits()
}

private func indexedPoint(ctx: UiContext, event: UiEvent): ?PointerEventPoint {
    match (event) {
        case UiEvent.MouseMove(x, y) =>
            if (ctx.leftMouseDown || !ctx.dragId.isEmpty() || !ctx.pressedId.isEmpty()) {
                None
            } else {
                Some(PointerEventPoint(x, y))
            }
        case UiEvent.MouseUp(_, x, y) =>
            if (ctx.leftMouseDown || !ctx.dragId.isEmpty() || !ctx.pressedId.isEmpty()) {
                None
            } else {
                Some(PointerEventPoint(x, y))
            }
        case UiEvent.MouseDown(_, x, y) => Some(PointerEventPoint(x, y))
        case UiEvent.MouseWheel(_, _, x, y) => Some(PointerEventPoint(x, y))
        case UiEvent.DropFile(_, x, y) => Some(PointerEventPoint(x, y))
        case UiEvent.DropText(_, x, y) => Some(PointerEventPoint(x, y))
        case UiEvent.DropPosition(x, y) => Some(PointerEventPoint(x, y))
        case _ => None
    }
}

private func dispatchChildrenUnindexed(children: Array<Widget>, ctx: UiContext, event: UiEvent): Bool {
    match (event) {
        case UiEvent.Frame(_) =>
            for (child in children) {
                broadcastEvent(child, ctx, event)
            }
            return false
        case _ => ()
    }
    var index = children.size - 1
    while (index >= 0) {
        if (children[index].handle(ctx, event)) {
            return true
        }
        index -= 1
    }
    false
}
