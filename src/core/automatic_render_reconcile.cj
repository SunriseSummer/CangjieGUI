package cui.core

import std.collection.ArrayList
import sdl.Rect

/* One existing proxy update, staged until the root composition transaction commits. */
class PendingAutomaticRenderUpdate {
    let node: AutomaticRenderNode
    let child: Widget

    init(node: AutomaticRenderNode, child: Widget) {
        this.node = node
        this.child = child
    }

    func commit(): Unit {
        node.update(child)
    }
}

/* Reconciliation output and deferred mutations for one automatic composition record. */
class AutomaticRenderReconciliation {
    let children: Array<Widget>
    private let updates: Array<PendingAutomaticRenderUpdate>
    private let removed: Array<AutomaticRenderNode>
    private let created: Array<AutomaticRenderNode>

    init(
        children: Array<Widget>,
        updates: Array<PendingAutomaticRenderUpdate>,
        removed: Array<AutomaticRenderNode>,
        created: Array<AutomaticRenderNode>
    ) {
        this.children = children
        this.updates = updates
        this.removed = removed
        this.created = created
    }

    func commit(): Unit {
        for (update in updates) {
            update.commit()
        }
        for (node in removed) {
            node.close()
        }
    }

    /* A rejected root build must release only nodes allocated by this staged reconciliation. */
    func cancel(): Unit {
        for (node in created) {
            node.close()
        }
    }
}

func wrapAutomaticChildren(
    children: Array<Widget>,
    scene: ElementSceneFacet,
    paintBudget: AutomaticPaintBudget,
    invalidateDamage: (Rect) -> Unit
): Array<Widget> {
    Array<Widget>(children.size, {
        index => AutomaticRenderNode(children[index], scene.acquire(index), paintBudget, invalidateDamage)
    })
}

func reconcileAutomaticChildren(
    previous: Array<Widget>,
    next: Array<Widget>,
    scene: ElementSceneFacet,
    paintBudget: AutomaticPaintBudget,
    invalidateDamage: (Rect) -> Unit
): AutomaticRenderReconciliation {
    let children = ArrayList<Widget>()
    let updates = ArrayList<PendingAutomaticRenderUpdate>()
    let removed = ArrayList<AutomaticRenderNode>()
    let created = ArrayList<AutomaticRenderNode>()
    var index: Int64 = 0
    while (index < next.size) {
        if (index < previous.size) {
            match (previous[index] as AutomaticRenderNode) {
                case Some(node) =>
                    children.add(node)
                    updates.add(PendingAutomaticRenderUpdate(node, next[index]))
                case None =>
                    let node = AutomaticRenderNode(next[index], scene.acquire(index), paintBudget, invalidateDamage)
                    children.add(node)
                    created.add(node)
            }
        } else {
            let node = AutomaticRenderNode(next[index], scene.acquire(index), paintBudget, invalidateDamage)
            children.add(node)
            created.add(node)
        }
        index += 1
    }
    while (index < previous.size) {
        match (previous[index] as AutomaticRenderNode) {
            case Some(node) => removed.add(node)
            case None => ()
        }
        index += 1
    }
    AutomaticRenderReconciliation(children.toArray(), updates.toArray(), removed.toArray(), created.toArray())
}

func closeAutomaticRenderChildren(children: Array<Widget>): Unit {
    for (child in children) {
        match (child as AutomaticRenderNode) {
            case Some(node) => node.close()
            case None => ()
        }
    }
}

func automaticRenderNodes(children: Array<Widget>): Array<AutomaticRenderNode> {
    let result = ArrayList<AutomaticRenderNode>()
    for (child in children) {
        match (child as AutomaticRenderNode) {
            case Some(node) => result.add(node)
            case None => ()
        }
    }
    result.toArray()
}
