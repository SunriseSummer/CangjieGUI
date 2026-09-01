package cui.core

/*
 * Stable focus identity. The public control key remains ergonomic and source compatible, while the
 * owning generational Element prevents a stale focus claim from aliasing a newly mounted subtree.
 */
struct FocusTarget {
    let owner: ElementId
    let key: String
    let declarationId: String

    init(owner: ElementId, key: String) {
        this.owner = owner
        this.key = key
        this.declarationId = key
    }

    init(owner: ElementId, key: String, declarationId: String) {
        this.owner = owner
        this.key = key
        this.declarationId = declarationId
    }

    static func detached(key: String): FocusTarget {
        FocusTarget(ElementId.detached(), key)
    }

    func withKey(key: String): FocusTarget {
        FocusTarget(owner, key, declarationId)
    }
}

func sameFocusTarget(left: FocusTarget, right: FocusTarget): Bool {
    left.key == right.key && left.declarationId == right.declarationId && sameElementId(left.owner, right.owner)
}

func focusTargetKeys(targets: Array<FocusTarget>): Array<String> {
    Array<String>(targets.size, {index => targets[index].key})
}

func detachedFocusTargets(keys: Array<String>): Array<FocusTarget> {
    Array<FocusTarget>(keys.size, {index => FocusTarget.detached(keys[index])})
}
