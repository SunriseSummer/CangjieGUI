package cui.core

/*
 * A bounded frame arena removes the common transaction/log allocation without attaching six
 * staging collections to every persistent scope in a large, mostly stable tree. Cells above the
 * bound remain ordinary ephemeral transactions, so peak UI breadth cannot grow retained memory.
 */
private let MOUNT_BUILD_ARENA_LIMIT: Int64 = 256
private let INACTIVE_MOUNT_INVALIDATION: () -> Unit = {=> ()}

func acquireMountBuild(
    store: StateStore,
    scope: StateMountScope,
    collectStateReads!: Bool,
    invalidate!: () -> Unit,
    forceAutomaticDescendants!: Bool = false,
    automaticSubtreeWeight!: Int64 = 0
): StateMountBuild {
    let slot = store.mountBuildArenaCursor
    if (slot < store.mountBuildArena.size) {
        let build = store.mountBuildArena[slot]
        store.mountBuildArenaCursor += 1
        build.restart(
            scope,
            collectStateReads: collectStateReads,
            invalidate: invalidate,
            forceAutomaticDescendants: forceAutomaticDescendants,
            automaticSubtreeWeight: automaticSubtreeWeight
        )
        return build
    }

    let build = StateMountBuild(
        scope,
        collectStateReads: collectStateReads,
        invalidate: invalidate,
        forceAutomaticDescendants: forceAutomaticDescendants,
        automaticSubtreeWeight: automaticSubtreeWeight
    )
    if (store.mountBuildArena.size < MOUNT_BUILD_ARENA_LIMIT) {
        store.mountBuildArena.add(build)
        store.mountBuildArenaCursor += 1
    }
    build
}

func releaseMountBuildArena(store: StateStore): Unit {
    var slot: Int64 = 0
    while (slot < store.mountBuildArenaCursor) {
        store.mountBuildArena[slot].restart(
            store.rootMountScope,
            collectStateReads: true,
            invalidate: INACTIVE_MOUNT_INVALIDATION
        )
        slot += 1
    }
    store.mountBuildArenaCursor = 0
}
