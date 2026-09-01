package cui.core

import std.collection.{ArrayList, HashSet}

/*
 * Build-local ordered focus graph. `declarations` retains ownership even for duplicate public keys,
 * while `order` is the deduplicated Tab traversal snapshot exposed to the shell.
 */
class FocusRegistry {
    private let order = ArrayList<FocusTarget>()
    private let declarations = ArrayList<FocusTarget>()
    private var inactiveDeclarations: ?HashSet<Int64> = None
    private let ids = HashSet<String>()
    private var adopted: ?FocusSnapshot = None

    prop size: Int64 {
        get() {
            match (adopted) {
                case Some(snapshot) => snapshot.targets.size
                case None => order.size
            }
        }
    }

    func clear(): Unit {
        adopted = None
        order.clear()
        declarations.clear()
        inactiveDeclarations = None
        ids.clear()
    }

    func replay(snapshot: FocusSnapshot): Unit {
        if (adopted.isNone() && declarations.isEmpty()) {
            adopted = Some(snapshot)
            return
        }
        materializeAdopted()
        for (target in snapshot.declarations) {
            registerMaterialized(target)
        }
    }

    func register(target: FocusTarget): Unit {
        materializeAdopted()
        registerMaterialized(target)
    }

    private func registerMaterialized(target: FocusTarget): Unit {
        declarations.add(target)
        // Duplicate explicit ids form one Tab stop, preserving the original first-entry contract.
        if (ids.add(target.key)) {
            order.add(target)
        }
    }

    func reregister(previous: String, replacement: String): Unit {
        materializeAdopted()
        var owner = ElementId.detached()
        var index = declarations.size - 1
        while (index >= 0) {
            if (isDeclarationActive(index) && declarations[index].key == previous) {
                owner = declarations[index].owner
                declarations[index] = declarations[index].withKey(replacement)
                rebuildOrder()
                return
            }
            index -= 1
        }
        register(FocusTarget(owner, replacement))
    }

    func unregister(id: String): Unit {
        materializeAdopted()
        var index = declarations.size - 1
        while (index >= 0) {
            if (isDeclarationActive(index) && declarations[index].key == id) {
                markDeclarationInactive(index)
                rebuildOrder()
                return
            }
            index -= 1
        }
    }

    func ring(): Array<String> {
        let values = match (adopted) {
            case Some(snapshot) => snapshot.keys
            case None => focusTargetKeys(order.toArray())
        }
        Array<String>(values.size, {index => values[index]})
    }

    func snapshot(): FocusSnapshot {
        match (adopted) {
            case Some(value) => value
            case None => focusSnapshotFromNormalized(activeDeclarations(), order.toArray())
        }
    }

    func fragmentFrom(start: Int64): FocusSnapshot {
        if (start <= 0) {
            return snapshot()
        }
        focusSnapshotFromDeclarations(declarationsBetween(start, declarationCount()))
    }

    func fragmentBetween(start: Int64, end: Int64): FocusSnapshot {
        focusSnapshotFromDeclarations(declarationsBetween(start, end))
    }

    func declarationCount(): Int64 {
        match (adopted) {
            case Some(snapshot) => snapshot.declarations.size
            case None => declarations.size
        }
    }

    private func declarationsBetween(start: Int64, end: Int64): Array<FocusTarget> {
        let values = match (adopted) {
            case Some(snapshot) => snapshot.declarations
            case None => declarations.toArray()
        }
        if (start >= values.size || start >= end) {
            return []
        }
        let first = max(0, start)
        let limit = min(values.size, max(first, end))
        let result = ArrayList<FocusTarget>()
        for (index in first..limit) {
            if (adopted.isSome() || isDeclarationActive(index)) {
                result.add(values[index])
            }
        }
        result.toArray()
    }

    func from(start: Int64): Array<String> {
        let values = match (adopted) {
            case Some(snapshot) => snapshot.keys
            case None => focusTargetKeys(order.toArray())
        }
        if (start >= values.size) {
            return []
        }
        let first = max(0, start)
        Array<String>(values.size - first, {index => values[first + index]})
    }

    private func rebuildOrder(): Unit {
        order.clear()
        ids.clear()
        for (index in 0..declarations.size) {
            if (isDeclarationActive(index)) {
                let target = declarations[index]
                if (ids.add(target.key)) {
                    order.add(target)
                }
            }
        }
    }

    private func activeDeclarations(): Array<FocusTarget> {
        let result = ArrayList<FocusTarget>()
        for (index in 0..declarations.size) {
            if (isDeclarationActive(index)) {
                result.add(declarations[index])
            }
        }
        result.toArray()
    }

    private func materializeAdopted(): Unit {
        match (adopted) {
            case Some(snapshot) =>
                adopted = None
                for (target in snapshot.declarations) {
                    registerMaterialized(target)
                }
            case None => ()
        }
    }

    private func isDeclarationActive(index: Int64): Bool {
        match (inactiveDeclarations) {
            case Some(inactive) => !inactive.contains(index)
            case None => true
        }
    }

    private func markDeclarationInactive(index: Int64): Unit {
        let inactive = match (inactiveDeclarations) {
            case Some(value) => value
            case None =>
                let value = HashSet<Int64>()
                inactiveDeclarations = Some(value)
                value
        }
        inactive.add(index)
    }
}
