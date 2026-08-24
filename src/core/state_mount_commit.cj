package cui.core

import std.collection.ArrayList

func commitMountBuild(store: StateStore, build: StateMountBuild): Unit {
    for (path in build.scope.stateKeys) {
        if (!build.containsState(path)) {
            let _ = store.entries.remove(path) // cjcheck-ignore: ignore-result # obsolete ownership may already have been cleared by an ancestor
        }
    }
    for (path in build.scope.retainedKeys) {
        if (!build.containsRetained(path)) {
            removeRetainedMount(store, path)
        }
    }
    for (path in build.scope.automaticKeys) {
        if (!build.containsAutomatic(path)) {
            removeAutomaticMount(store, path)
        }
    }
    var effectIndex = build.scope.effectKeys.size - 1
    while (effectIndex >= 0) {
        let path = build.scope.effectKeys[effectIndex]
        if (!build.containsEffect(path)) {
            stageLifecycleEffectRemoval(store, path)
        }
        effectIndex -= 1
    }
    replaceMountKeys(build.scope.stateKeys, build.stateKeys)
    replaceMountKeys(build.scope.retainedKeys, build.retainedKeys)
    replaceMountKeys(build.scope.automaticKeys, build.automaticKeys)
    replaceMountKeys(build.scope.effectKeys, build.effectKeys)
    build.commitStateReads()
}

func removeRetainedMount(store: StateStore, path: String): Unit {
    match (store.retainedEntries.get(path)) {
        case Some(record) =>
            for (statePath in record.mountScope.stateKeys) {
                let _ = store.entries.remove(statePath) // cjcheck-ignore: ignore-result # state path belongs to the subtree being unmounted
            }
            for (childPath in record.mountScope.retainedKeys) {
                removeRetainedMount(store, childPath)
            }
            for (childPath in record.mountScope.automaticKeys) {
                removeAutomaticMount(store, childPath)
            }
            stageLifecycleEffectsInScope(store, record.mountScope)
            record.close()
            record.mountScope.stateKeys.clear()
            record.mountScope.retainedKeys.clear()
            record.mountScope.automaticKeys.clear()
            record.mountScope.effectKeys.clear()
            record.mountScope.closeBuildDependencies()
        case None => ()
    }
    let _ = store.retainedEntries.remove(path) // cjcheck-ignore: ignore-result # missing records are harmless during recursive cleanup
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
    store.stateAddedDuringBuild.clear()
    store.retainedAddedDuringBuild.clear()
    store.automaticAddedDuringBuild.clear()
    store.retainedReplacements.clear()
    store.automaticReplacements.clear()
}
