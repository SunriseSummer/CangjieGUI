package cui.core

import std.collection.{ArrayList, HashSet}

/* Build-local ordered set backing keyboard focus traversal. */
class FocusRegistry {
    private let order = ArrayList<String>()
    private let ids = HashSet<String>()

    prop size: Int64 {
        get() {
            order.size
        }
    }

    func clear(): Unit {
        order.clear()
        ids.clear()
    }

    func register(id: String): Unit {
        // Duplicate explicit ids form one Tab stop, preserving the original first-entry contract.
        if (ids.add(id)) {
            order.add(id)
        }
    }

    func reregister(previous: String, replacement: String): Unit {
        remove(replacement)
        var index = order.size - 1
        while (index >= 0) {
            if (order[index] == previous) {
                ids.remove(previous)
                order[index] = replacement
                ids.add(replacement)
                return
            }
            index -= 1
        }
        register(replacement)
    }

    func unregister(id: String): Unit {
        remove(id)
    }

    func ring(): Array<String> {
        order.toArray()
    }

    func from(start: Int64): Array<String> {
        if (start >= order.size) {
            return []
        }
        let first = max(0, start)
        Array<String>(order.size - first, {index => order[first + index]})
    }

    private func remove(id: String): Unit {
        if (!ids.contains(id)) {
            return
        }
        var index = order.size - 1
        while (index >= 0) {
            if (order[index] == id) {
                order.remove(at: index)
                ids.remove(id)
                return
            }
            index -= 1
        }
    }
}
