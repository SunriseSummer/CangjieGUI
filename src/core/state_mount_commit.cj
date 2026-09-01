package cui.core

import std.collection.ArrayList

func commitMountBuild(store: StateStore, build: StateMountBuild): Unit {
    match (build.scope.committedOwnership()) {
        case Some(previous) =>
            for (path in previous.stateKeys) {
                if (!build.containsState(path)) {
                    let _ = store.entries.remove(path) // cjcheck-ignore: ignore-result # obsolete ownership may already have been cleared by an ancestor
                }
            }
            for (path in previous.retainedKeys) {
                if (!build.containsRetained(path)) {
                    removeRetainedMount(store, path)
                }
            }
            for (path in previous.automaticKeys) {
                if (!build.containsAutomatic(path)) {
                    removeAutomaticMount(store, path)
                }
            }
            var effectIndex = previous.effectKeys.size - 1
            while (effectIndex >= 0) {
                let path = previous.effectKeys[effectIndex]
                if (!build.containsEffect(path)) {
                    stageLifecycleEffectRemoval(store, path)
                }
                effectIndex -= 1
            }
        case None => ()
    }
    if (build.hasOwnershipDeclarations()) {
        let ownership = build.scope.ensureCommittedOwnership()
        replaceMountKeys(ownership.stateKeys, build.stateKeys)
        replaceMountKeys(ownership.retainedKeys, build.retainedKeys)
        replaceMountKeys(ownership.automaticKeys, build.automaticKeys)
        replaceMountKeys(ownership.effectKeys, build.effectKeys)
        ownership.hasExternalRetainedRevision = build.hasExternalRetainedRevision
        ownership.hasExternalEffectRevision = build.hasExternalEffectRevision
        build.commitImplicitSlotShape(ownership)
    } else {
        build.scope.clearCommittedOwnership()
    }
    build.commitStateReads()
}

func removeRetainedMount(store: StateStore, path: String): Unit {
    match (store.retainedEntries.get(path)) {
        case Some(record) =>
            match (record.mountScope.committedOwnership()) {
                case Some(ownership) =>
                    for (statePath in ownership.stateKeys) {
                        let _ = store.entries.remove(statePath) // cjcheck-ignore: ignore-result # state path belongs to the subtree being unmounted
                    }
                    for (childPath in ownership.retainedKeys) {
                        removeRetainedMount(store, childPath)
                    }
                    for (childPath in ownership.automaticKeys) {
                        removeAutomaticMount(store, childPath)
                    }
                case None => ()
            }
            stageLifecycleEffectsInScope(store, record.mountScope)
            record.close()
            record.mountScope.clearCommittedOwnership()
            record.mountScope.closeBuildDependencies()
        case None => ()
    }
    let _ = store.retainedEntries.remove(path) // cjcheck-ignore: ignore-result # missing records are harmless during recursive cleanup
    match (store.elementArena.idForPath(path)) {
        case Some(id) => store.elementArena.releaseIfLive(id)
        case None => ()
    }
}

private func replaceMountKeys(target: ArrayList<String>, source: ArrayList<String>): Unit {
    target.clear()
    for (path in source) {
        target.add(path)
    }
}

func clearBuildTransaction(store: StateStore): Unit {
    store.mountBuilds.clear()
    store.activeMountBuilds.clear()
    releaseMountBuildArena(store)
    store.stateAddedDuringBuild.clear()
    store.retainedAddedDuringBuild.clear()
    store.automaticAddedDuringBuild.clear()
    store.elementAddedDuringBuild.clear()
    store.retainedReplacements.clear()
    store.automaticReplacements.clear()
}
