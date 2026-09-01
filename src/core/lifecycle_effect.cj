package cui.core

import std.collection.ArrayList

/** Idempotent Resource adapter for lifecycle effects whose cleanup is naturally a closure. */
public class EffectCleanup <: Resource {
    private var action: ?(() -> Unit)

    public init(action: () -> Unit) {
        this.action = Some(action)
    }

    /** Whether the cleanup action completed successfully. */
    public func isClosed(): Bool {
        action.isNone()
    }

    /** Runs the cleanup once; a failure remains retryable. */
    public func close(): Unit {
        match (action) {
            case Some(cleanup) =>
                cleanup()
                action = None
            case None => ()
        }
    }
}

class LifecycleEffectRecord {
    let revision: UInt64
    let resource: Resource

    init(revision: UInt64, resource: Resource) {
        this.revision = revision
        this.resource = resource
    }
}

class PendingLifecycleEffect {
    let path: String
    let revision: UInt64
    let setup: () -> Resource
    var prepared: ?Resource = None

    init(path: String, revision: UInt64, setup: () -> Resource) {
        this.path = path
        this.revision = revision
        this.setup = setup
    }
}

/** Mounts `setup` once for this identity and closes its Resource when the scope unmounts. */
public func mountEffect(key: String, setup: () -> Resource): Unit {
    declareLifecycleEffect(key, UInt64(0), setup, hasExternalRevision: false)
}

/** Mounts a Resource at the next guarded positional slot of the active declarative scope. */
public func mountEffect(setup: () -> Resource): Unit {
    let store = currentStateStore()
    let (path, identity) = store.nextImplicitSlot(ImplicitSlotKind.MountEffect)
    declareLifecycleEffectAt(store, path, identity, UInt64(0), setup, hasExternalRevision: false)
}

/**
 * Owns a Resource at the current declarative identity. Setup runs only after the complete build
 * body succeeds, restarts after `revision` changes, and cleanup runs on replacement or unmount.
 */
public func lifecycleEffect(key: String, revision: UInt64, setup: () -> Resource): Unit {
    declareLifecycleEffect(key, revision, setup, hasExternalRevision: true)
}

/** Owns a revisioned Resource at the next guarded positional slot of the active scope. */
public func lifecycleEffect(revision: UInt64, setup: () -> Resource): Unit {
    let store = currentStateStore()
    let (path, identity) = store.nextImplicitSlot(ImplicitSlotKind.LifecycleEffect)
    declareLifecycleEffectAt(store, path, identity, revision, setup, hasExternalRevision: true)
}

private func declareLifecycleEffect(
    key: String,
    revision: UInt64,
    setup: () -> Resource,
    hasExternalRevision!: Bool
): Unit {
    let store = currentStateStore()
    store.validateKey(key)
    let path = store.scopedKey(key)
    declareLifecycleEffectAt(store, path, key, revision, setup, hasExternalRevision: hasExternalRevision)
}

private func declareLifecycleEffectAt(
    store: StateStore,
    path: String,
    identity: String,
    revision: UInt64,
    setup: () -> Resource,
    hasExternalRevision!: Bool
): Unit {
    visitLifecycleEffectKey(store, path, identity, hasExternalRevision)
    match (store.lifecycleEffects.get(path)) {
        case Some(record) where record.revision == revision => ()
        case _ => store.pendingLifecycleEffects.add(PendingLifecycleEffect(path, revision, setup))
    }
}

func beginLifecycleEffectBuild(store: StateStore): Unit {
    store.pendingLifecycleEffects.clear()
    store.lifecycleEffectRemovals.clear()
}

func prepareLifecycleEffectBuild(store: StateStore): Unit {
    for (pending in store.pendingLifecycleEffects) {
        let resource = pending.setup()
        if (resource.isClosed()) {
            throw IllegalStateException("Lifecycle effect '${pending.path}' setup returned a closed Resource")
        }
        pending.prepared = Some(resource)
    }
}

func stageLifecycleEffectRemoval(store: StateStore, path: String): Unit {
    if (!store.lifecycleEffectRemovals.contains(path)) {
        store.lifecycleEffectRemovals.add(path)
    }
}

func stageLifecycleEffectsInScope(store: StateStore, scope: StateMountScope): Unit {
    match (scope.committedOwnership()) {
        case Some(ownership) =>
            var i = ownership.effectKeys.size - 1
            while (i >= 0) {
                stageLifecycleEffectRemoval(store, ownership.effectKeys[i])
                i -= 1
            }
        case None => ()
    }
}

/* Installs prepared effects after structural ownership commits; cleanup failures are delayed. */
func commitLifecycleEffectBuild(store: StateStore): ?Exception {
    var firstFailure = retryFailedLifecycleCleanups(store)
    for (pending in store.pendingLifecycleEffects) {
        match (pending.prepared) {
            case Some(resource) =>
                let previous = store.lifecycleEffects.add(
                    pending.path,
                    LifecycleEffectRecord(pending.revision, resource)
                )
                match (previous) {
                    case Some(record) => firstFailure = keepFirstFailure(
                        firstFailure,
                        closeLifecycleResource(store, record.resource)
                    )
                    case None => ()
                }
            case None => firstFailure = keepFirstFailure(
                firstFailure,
                Some(IllegalStateException("Lifecycle effect '${pending.path}' was not prepared"))
            )
        }
    }
    for (path in store.lifecycleEffectRemovals) {
        if (!hasPendingLifecycleEffect(store, path)) {
            match (store.lifecycleEffects.remove(path)) {
                case Some(record) => firstFailure = keepFirstFailure(
                    firstFailure,
                    closeLifecycleResource(store, record.resource)
                )
                case None => ()
            }
        }
    }
    clearLifecycleEffectTransaction(store)
    firstFailure
}

func cancelLifecycleEffectBuild(store: StateStore): ?Exception {
    var firstFailure: ?Exception = None
    var i = store.pendingLifecycleEffects.size - 1
    while (i >= 0) {
        match (store.pendingLifecycleEffects[i].prepared) {
            case Some(resource) => firstFailure = keepFirstFailure(
                firstFailure,
                closeLifecycleResource(store, resource)
            )
            case None => ()
        }
        i -= 1
    }
    clearLifecycleEffectTransaction(store)
    firstFailure
}

func clearLifecycleEffects(store: StateStore): ?Exception {
    var firstFailure = retryFailedLifecycleCleanups(store)
    firstFailure = keepFirstFailure(firstFailure, closeLifecycleEffectsInScope(store, store.rootMountScope))
    // Defensive cleanup for an ownership inconsistency: never leak an effect merely because its
    // scope key was damaged. Normal paths empty the map in the hierarchy walk above.
    let leftovers = ArrayList<String>()
    for ((path, _) in store.lifecycleEffects) {
        leftovers.add(path)
    }
    for (path in leftovers) {
        match (store.lifecycleEffects.remove(path)) {
            case Some(record) => firstFailure = keepFirstFailure(
                firstFailure,
                closeLifecycleResource(store, record.resource)
            )
            case None => ()
        }
    }
    clearLifecycleEffectTransaction(store)
    firstFailure
}

private func closeLifecycleEffectsInScope(store: StateStore, scope: StateMountScope): ?Exception {
    var firstFailure: ?Exception = None
    match (scope.committedOwnership()) {
        case Some(ownership) =>
            var automaticIndex = ownership.automaticKeys.size - 1
            while (automaticIndex >= 0) {
                match (store.automaticEntries.get(ownership.automaticKeys[automaticIndex])) {
                    case Some(record) => firstFailure = keepFirstFailure(
                        firstFailure,
                        closeLifecycleEffectsInScope(store, record.mountScope)
                    )
                    case None => ()
                }
                automaticIndex -= 1
            }
            var retainedIndex = ownership.retainedKeys.size - 1
            while (retainedIndex >= 0) {
                match (store.retainedEntries.get(ownership.retainedKeys[retainedIndex])) {
                    case Some(record) => firstFailure = keepFirstFailure(
                        firstFailure,
                        closeLifecycleEffectsInScope(store, record.mountScope)
                    )
                    case None => ()
                }
                retainedIndex -= 1
            }
            var effectIndex = ownership.effectKeys.size - 1
            while (effectIndex >= 0) {
                match (store.lifecycleEffects.remove(ownership.effectKeys[effectIndex])) {
                    case Some(record) => firstFailure = keepFirstFailure(
                        firstFailure,
                        closeLifecycleResource(store, record.resource)
                    )
                    case None => ()
                }
                effectIndex -= 1
            }
        case None => ()
    }
    firstFailure
}

private func closeLifecycleResource(store: StateStore, resource: Resource): ?Exception {
    try {
        if (!resource.isClosed()) {
            resource.close()
        }
        None
    } catch (error: Exception) {
        if (!resource.isClosed() && !containsLifecycleResource(store.failedLifecycleCleanups, resource)) {
            store.failedLifecycleCleanups.add(resource)
        }
        Some(error)
    }
}

private func retryFailedLifecycleCleanups(store: StateStore): ?Exception {
    if (store.failedLifecycleCleanups.isEmpty()) {
        return None
    }
    let retrying = store.failedLifecycleCleanups.toArray()
    store.failedLifecycleCleanups.clear()
    var firstFailure: ?Exception = None
    for (resource in retrying) {
        firstFailure = keepFirstFailure(firstFailure, closeLifecycleResource(store, resource))
    }
    firstFailure
}

private func containsLifecycleResource(resources: ArrayList<Resource>, candidate: Resource): Bool {
    let target = (candidate as Object).getOrThrow() // cjcheck-ignore: unchecked-cast # Resource effects are class instances
    for (resource in resources) {
        if (refEq((resource as Object).getOrThrow(), target)) { // cjcheck-ignore: unchecked-cast # identity prevents duplicate retries
            return true
        }
    }
    false
}

private func hasPendingLifecycleEffect(store: StateStore, path: String): Bool {
    for (pending in store.pendingLifecycleEffects) {
        if (pending.path == path) {
            return true
        }
    }
    false
}

private func keepFirstFailure(current: ?Exception, candidate: ?Exception): ?Exception {
    match (current) {
        case Some(_) => current
        case None => candidate
    }
}

private func clearLifecycleEffectTransaction(store: StateStore): Unit {
    store.pendingLifecycleEffects.clear()
    store.lifecycleEffectRemovals.clear()
}
