package cui.core

import std.collection.{ArrayList, HashSet}

/*
 * Immutable focus declaration fragment. `declarations` is the free-monoid value composed during
 * build; `targets` is its first-key-wins normalization used by Tab traversal. Automatic/retained
 * composition records keep this object stable, so a clean root can publish the same graph by
 * identity without replaying every declaration or rebuilding lookup tables.
 */
class FocusSnapshot {
    private let identity = allocateStateIdentity()
    let declarations: Array<FocusTarget>
    let targets: Array<FocusTarget>
    let keys: Array<String>

    init(declarations: Array<FocusTarget>, targets: Array<FocusTarget>) {
        this.declarations = declarations
        this.targets = targets
        this.keys = focusTargetKeys(targets)
    }

    func identityToken(): UInt64 {
        identity
    }
}

func focusSnapshotFromDeclarations(declarations: Array<FocusTarget>): FocusSnapshot {
    let targets = ArrayList<FocusTarget>()
    let keys = HashSet<String>()
    for (target in declarations) {
        if (keys.add(target.key)) {
            targets.add(target)
        }
    }
    FocusSnapshot(declarations, targets.toArray())
}

func focusSnapshotFromNormalized(
    declarations: Array<FocusTarget>,
    targets: Array<FocusTarget>
): FocusSnapshot {
    FocusSnapshot(declarations, targets)
}

func sameFocusSnapshot(left: FocusSnapshot, right: FocusSnapshot): Bool {
    left.identityToken() == right.identityToken()
}
