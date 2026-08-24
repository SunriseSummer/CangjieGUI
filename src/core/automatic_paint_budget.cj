package cui.core

import std.collection.ArrayList

private let AUTOMATIC_PAINT_GLOBAL_BUDGET_BYTES: UInt64 = UInt64(32 * 1024 * 1024)

/* Per-application bounded LRU for automatically selected display lists. */
class AutomaticPaintBudget {
    private let limitBytes: UInt64
    private let entries = ArrayList<AutomaticRenderNode>()
    private var usedBytes: UInt64 = UInt64(0)
    private var clock: UInt64 = UInt64(0)

    init(limitBytes!: UInt64 = AUTOMATIC_PAINT_GLOBAL_BUDGET_BYTES) {
        this.limitBytes = limitBytes
    }

    func admit(node: AutomaticRenderNode, bytes: UInt64): Bool {
        if (bytes == UInt64(0) || bytes > limitBytes) {
            return false
        }
        release(node)
        while (usedBytes + bytes > limitBytes) {
            match (leastRecentlyUsed(node)) {
                case Some(candidate) => evict(candidate)
                case None => return false
            }
        }
        entries.add(node)
        usedBytes += bytes
        clock = nextRevision(clock)
        node.acceptPaintBudget(bytes, clock)
        true
    }

    func touch(node: AutomaticRenderNode): Unit {
        if (node.paintBudgetBytes() == UInt64(0)) {
            return
        }
        clock = nextRevision(clock)
        node.touchPaintBudget(clock)
    }

    func release(node: AutomaticRenderNode): Unit {
        if (node.paintBudgetBytes() == UInt64(0)) {
            return
        }
        var index = entries.size - 1
        while (index >= 0) {
            if (sameAutomaticPaintNode(entries[index], node)) {
                usedBytes -= min(usedBytes, node.paintBudgetBytes())
                entries.remove(at: index)
                node.releasePaintBudget()
                return
            }
            index -= 1
        }
        node.releasePaintBudget()
    }

    private func leastRecentlyUsed(excluded: AutomaticRenderNode): ?AutomaticRenderNode {
        var result: ?AutomaticRenderNode = None
        var oldest = UInt64.Max
        for (candidate in entries) {
            if (!sameAutomaticPaintNode(candidate, excluded) && candidate.paintBudgetLastUse() < oldest) {
                result = Some(candidate)
                oldest = candidate.paintBudgetLastUse()
            }
        }
        result
    }

    private func evict(node: AutomaticRenderNode): Unit {
        usedBytes -= min(usedBytes, node.paintBudgetBytes())
        var index = entries.size - 1
        while (index >= 0) {
            if (sameAutomaticPaintNode(entries[index], node)) {
                entries.remove(at: index)
                break
            }
            index -= 1
        }
        node.evictPaintForBudget()
    }
}

private func sameAutomaticPaintNode(left: AutomaticRenderNode, right: AutomaticRenderNode): Bool {
    refEq((left as Object).getOrThrow(), (right as Object).getOrThrow()) // cjcheck-ignore: unchecked-cast # both are internal class instances
}
