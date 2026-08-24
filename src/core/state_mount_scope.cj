package cui.core

import std.collection.{ArrayList, HashSet}

/* Persistent ownership node for a rebuild boundary; child scopes isolate retained dependencies. */
class StateMountScope {
    let parent: ?StateMountScope
    let diagnosticPath: String
    let depth: Int64
    var ownerRecord: ?RetainedRecord = None
    private var automaticDamageSink: ?(() -> Unit) = None
    private var automaticPhaseSink: ?AutomaticRenderPhaseSink = None
    let stateKeys = ArrayList<String>()
    let retainedKeys = ArrayList<String>()
    let automaticKeys = ArrayList<String>()
    let effectKeys = ArrayList<String>()
    let buildDependencies = ArrayList<StateReadDependency>()
    var buildDirty = false
    var buildSelfDirty = false
    var buildDescendantDirty = false
    var buildDirtyReason = ""
    var dirtyVersion: UInt64 = UInt64(0)
    var buildInvalidations: UInt64 = UInt64(0)

    init() {
        this.parent = None
        this.diagnosticPath = "<root>"
        this.depth = 0
    }

    init(parent: StateMountScope) {
        this(parent, "<detached>")
    }

    init(parent: StateMountScope, diagnosticPath: String) {
        this.parent = Some(parent)
        this.diagnosticPath = diagnosticPath
        this.depth = parent.depth + 1
    }

    func markBuildDirty(): Unit {
        var current: ?StateMountScope = Some(this)
        while (let Some(scope) <- current) {
            let isSource = sameMountScope(scope, this)
            if (!scope.buildDirty) {
                scope.buildInvalidations = nextRevision(scope.buildInvalidations)
                scope.buildDirtyReason = if (isSource) {
                    "State dependency changed"
                } else {
                    "descendant build dependency changed"
                }
            }
            if (isSource) {
                scope.buildSelfDirty = true
                scope.buildDirtyReason = "State dependency changed"
            } else {
                scope.buildDescendantDirty = true
            }
            scope.dirtyVersion = nextRevision(scope.dirtyVersion)
            scope.buildDirty = true
            match (scope.ownerRecord) {
                case Some(record) => record.noteBuildInvalidationDamage()
                case None => ()
            }
            current = scope.parent
        }
        noteNearestAutomaticDamage()
    }

    func closeBuildDependencies(): Unit {
        for (dependency in buildDependencies) {
            dependency.close()
        }
        buildDependencies.clear()
        buildDirty = false
        buildSelfDirty = false
        buildDescendantDirty = false
        buildDirtyReason = ""
        automaticDamageSink = None
        automaticPhaseSink = None
    }

    func attachOwner(record: RetainedRecord): Unit {
        ownerRecord = Some(record)
    }

    func attachAutomaticDamageSink(sink: () -> Unit): Unit {
        automaticDamageSink = Some(sink)
    }

    func clearAutomaticDamageSink(): Unit {
        automaticDamageSink = None
    }

    func attachAutomaticPhaseSink(sink: AutomaticRenderPhaseSink): Unit {
        automaticPhaseSink = Some(sink)
    }

    func clearAutomaticPhaseSink(): Unit {
        automaticPhaseSink = None
    }

    private func noteNearestAutomaticDamage(): Unit {
        var current: ?StateMountScope = Some(this)
        while (let Some(scope) <- current) {
            // An explicit retained owner already recorded its own precise paint bounds while the
            // dirty mark walked ancestors. Crossing it to an automatic root would widen a valid
            // local update back to the whole viewport.
            if (scope.ownerRecord.isSome()) {
                return
            }
            match (scope.automaticDamageSink) {
                case Some(sink) =>
                    sink()
                    return
                case None => current = scope.parent
            }
        }
    }

    func invalidateAncestorMeasure(): Unit {
        var current = parent
        while (let Some(scope) <- current) {
            match (scope.ownerRecord) {
                case Some(record) => record.invalidateDescendantMeasure()
                case None => ()
            }
            current = scope.parent
        }
        invalidateNearestAutomaticPhase(parent, {sink => sink.invalidateMeasure()})
    }

    func invalidateAncestorLayout(): Unit {
        var current = parent
        while (let Some(scope) <- current) {
            match (scope.ownerRecord) {
                case Some(record) => record.invalidateDescendantLayout()
                case None => ()
            }
            current = scope.parent
        }
        invalidateNearestAutomaticPhase(parent, {sink => sink.invalidateLayout()})
    }

    func invalidateAncestorPaint(): Unit {
        var current = parent
        while (let Some(scope) <- current) {
            match (scope.ownerRecord) {
                case Some(record) => record.invalidateDescendantPaint()
                case None => ()
            }
            current = scope.parent
        }
        invalidateNearestAutomaticPhase(parent, {sink => sink.invalidatePaint()})
    }

    private func invalidateNearestAutomaticPhase(
        start: ?StateMountScope,
        invalidate: (AutomaticRenderPhaseSink) -> Unit
    ): Unit {
        var current = start
        while (let Some(scope) <- current) {
            match (scope.automaticPhaseSink) {
                case Some(sink) =>
                    invalidate(sink)
                    return
                case None => current = scope.parent
            }
        }
    }
}

/*
 * A build-local transaction for one mount scope. Persistent ownership is replaced only after
 * the complete root build succeeds, so a later exception cannot partially unmount the old tree.
 */
class StateMountBuild {
    let scope: StateMountScope
    let stateKeys = ArrayList<String>()
    let retainedKeys = ArrayList<String>()
    let automaticKeys = ArrayList<String>()
    let effectKeys = ArrayList<String>()
    private let visitedState = HashSet<String>()
    private let visitedRetained = HashSet<String>()
    private let visitedAutomatic = HashSet<String>()
    private let visitedEffect = HashSet<String>()
    private let collectStateReads: Bool
    private let invalidate: () -> Unit
    private let dependencies = ArrayList<StateReadDependency>()
    private let dependencySources = ArrayList<Object>()
    private let newDependencies = ArrayList<StateReadDependency>()
    private let dirtyVersionAtStart: UInt64
    let forceAutomaticDescendants: Bool
    var automaticSubtreeWeight: Int64
    var automaticMaxBranching: Int64 = 0

    init(
        scope: StateMountScope,
        collectStateReads!: Bool,
        invalidate!: () -> Unit,
        forceAutomaticDescendants!: Bool = false,
        automaticSubtreeWeight!: Int64 = 0
    ) {
        this.scope = scope
        this.collectStateReads = collectStateReads
        this.invalidate = invalidate
        this.dirtyVersionAtStart = scope.dirtyVersion
        this.forceAutomaticDescendants = forceAutomaticDescendants
        this.automaticSubtreeWeight = automaticSubtreeWeight
    }

    func visitState(path: String, key: String): Unit {
        if (visitedState.contains(path)) {
            throw IllegalStateException("Duplicate remembered state key '${key}' in the same scope")
        }
        visitedState.add(path)
        stateKeys.add(path)
    }

    func visitRetained(path: String, key: String): Unit {
        if (visitedRetained.contains(path)) {
            throw IllegalStateException("Duplicate retained subtree key '${key}' in the same scope")
        }
        visitedRetained.add(path)
        retainedKeys.add(path)
    }

    func visitAutomatic(path: String, key: String): Unit {
        if (visitedAutomatic.contains(path)) {
            throw IllegalStateException("Duplicate automatic composition identity '${key}' in the same scope")
        }
        visitedAutomatic.add(path)
        automaticKeys.add(path)
        automaticMaxBranching = max(automaticMaxBranching, automaticKeys.size)
    }

    func visitEffect(path: String, key: String): Unit {
        if (visitedEffect.contains(path)) {
            throw IllegalStateException("Duplicate lifecycle effect key '${key}' in the same scope")
        }
        visitedEffect.add(path)
        effectKeys.add(path)
    }

    func containsState(path: String): Bool {
        visitedState.contains(path)
    }

    func containsRetained(path: String): Bool {
        visitedRetained.contains(path)
    }

    func containsAutomatic(path: String): Bool {
        visitedAutomatic.contains(path)
    }

    func containsEffect(path: String): Bool {
        visitedEffect.contains(path)
    }

    func absorbAutomaticSubtree(weight: Int64, maxBranching: Int64): Unit {
        automaticSubtreeWeight += weight
        automaticMaxBranching = max(automaticMaxBranching, maxBranching)
    }

    func readState<T>(source: State<T>): Unit {
        if (!collectStateReads) {
            return
        }
        let sourceObject = stateObject(source)
        for (seen in dependencySources) {
            if (refEq(seen, sourceObject)) {
                return
            }
        }
        dependencySources.add(sourceObject)
        for (dependency in scope.buildDependencies) {
            if (dependency.matches(sourceObject)) {
                dependencies.add(dependency)
                return
            }
        }
        let dependency = TypedStateReadDependency<T>(source, invalidate)
        dependencies.add(dependency)
        newDependencies.add(dependency)
    }

    func commitStateReads(): Unit {
        if (!collectStateReads) {
            return
        }
        for (previous in scope.buildDependencies) {
            if (!containsDependency(previous)) {
                previous.close()
            }
        }
        scope.buildDependencies.clear()
        for (dependency in dependencies) {
            scope.buildDependencies.add(dependency)
        }
        newDependencies.clear()
        let invalidatedDuringBuild = scope.dirtyVersion != dirtyVersionAtStart
        scope.buildDirty = invalidatedDuringBuild
        if (!invalidatedDuringBuild) {
            scope.buildSelfDirty = false
            scope.buildDescendantDirty = false
            scope.buildDirtyReason = ""
        }
    }

    func cancelStateReads(): Unit {
        for (dependency in newDependencies) {
            dependency.close()
        }
        newDependencies.clear()
    }

    private func containsDependency(candidate: StateReadDependency): Bool {
        for (dependency in dependencies) {
            if (sameStateReadDependency(dependency, candidate)) {
                return true
            }
        }
        false
    }
}

private func sameMountScope(left: StateMountScope, right: StateMountScope): Bool {
    refEq((left as Object).getOrThrow(), (right as Object).getOrThrow()) // cjcheck-ignore: unchecked-cast # mount scopes are internal class identities
}

/* Hierarchical state ownership and root-build transaction support. */
func beginMountBuild(store: StateStore): Unit {
    store.mountBuilds.clear()
    store.activeMountBuilds.clear()
    store.stateAddedDuringBuild.clear()
    store.retainedAddedDuringBuild.clear()
    store.automaticAddedDuringBuild.clear()
    store.retainedReplacements.clear()
    store.automaticReplacements.clear()
    let root = StateMountBuild(
        store.rootMountScope,
        collectStateReads: true,
        invalidate: {
            =>
                store.rootMountScope.markBuildDirty()
                markFullRetainedDamage(store)
        },
        forceAutomaticDescendants: store.rootMountScope.buildSelfDirty
    )
    store.mountBuilds.add(root)
    store.activeMountBuilds.add(root)
}

func visitRememberedState(store: StateStore, path: String, key: String): Unit {
    if (store.activeMountBuilds.isEmpty()) {
        return
    }
    currentMountBuild(store).visitState(path, key)
}

func recordStateInsertion(store: StateStore, path: String): Unit {
    if (!store.activeMountBuilds.isEmpty()) {
        store.stateAddedDuringBuild.add(path)
    }
}

func recordMountStateRead<T>(store: StateStore, source: State<T>): Unit {
    if (!store.activeMountBuilds.isEmpty()) {
        currentMountBuild(store).readState(source)
    }
}

func currentMountScope(store: StateStore): StateMountScope {
    currentMountBuild(store).scope
}

func visitRetainedChild(store: StateStore, path: String, key: String): Unit {
    currentMountBuild(store).visitRetained(path, key)
}

func visitLifecycleEffectKey(store: StateStore, path: String, key: String): Unit {
    currentMountBuild(store).visitEffect(path, key)
}

func beginRetainedMount(store: StateStore, scope: StateMountScope): Unit {
    // Executing a manual retained body means either mount, explicit revision change, or invalidation;
    // ordinary nested bodies must therefore refresh captured values conservatively.
    let build = StateMountBuild(scope, collectStateReads: true, invalidate: {=> scope.markBuildDirty()},
        forceAutomaticDescendants: true)
    store.mountBuilds.add(build)
    store.activeMountBuilds.add(build)
    beginStateReadCollection()
}

func endRetainedMount(store: StateStore): Unit {
    endNestedMount(store, "retained")
}

func endNestedMount(store: StateStore, kind: String): Unit {
    if (store.activeMountBuilds.size <= 1) {
        throw IllegalStateException("Unbalanced ${kind} state scope")
    }
    endStateReadCollection()
    store.activeMountBuilds.remove(at: store.activeMountBuilds.size - 1)
}

func finishMountBuild(store: StateStore): Unit {
    if (store.activeMountBuilds.size != 1) {
        throw IllegalStateException("Unbalanced retained state scope at end of build")
    }
    store.activeMountBuilds.remove(at: 0)

    // Children commit before parents. Parent pruning can then recursively remove only
    // genuinely absent child scopes, never a scope that is still being rebuilt.
    var i = store.mountBuilds.size - 1
    while (i >= 0) {
        commitMountBuild(store, store.mountBuilds[i])
        i -= 1
    }
    for (replacement in store.retainedReplacements) {
        replacement.commit()
    }
    for (replacement in store.automaticReplacements) {
        replacement.commit()
    }
    clearBuildTransaction(store)
}

func cancelMountBuild(store: StateStore): Unit {
    for (build in store.mountBuilds) {
        build.cancelStateReads()
    }
    // Newly inserted retained records may be nested. Reverse order closes children first;
    // persistent ownership was not committed, so each path is removed exactly once here.
    var i = store.retainedAddedDuringBuild.size - 1
    while (i >= 0) {
        let path = store.retainedAddedDuringBuild[i]
        match (store.retainedEntries.get(path)) {
            case Some(record) => record.close()
            case None => ()
        }
        let _ = store.retainedEntries.remove(path) // cjcheck-ignore: ignore-result # rollback removes an insertion journal entry
        i -= 1
    }
    i = store.automaticAddedDuringBuild.size - 1
    while (i >= 0) {
        let path = store.automaticAddedDuringBuild[i]
        match (store.automaticEntries.get(path)) {
            case Some(record) =>
                record.closeRenderNodes()
                record.mountScope.closeBuildDependencies()
            case None => ()
        }
        let _ = store.automaticEntries.remove(path) // cjcheck-ignore: ignore-result # rollback removes an insertion journal entry
        i -= 1
    }
    for (path in store.stateAddedDuringBuild) {
        let _ = store.entries.remove(path) // cjcheck-ignore: ignore-result # rollback removes an insertion journal entry
    }
    clearBuildTransaction(store)
}

func clearMountedState(store: StateStore): Unit {
    for ((_, record) in store.retainedEntries) {
        record.close()
        record.mountScope.stateKeys.clear()
        record.mountScope.retainedKeys.clear()
        record.mountScope.automaticKeys.clear()
        record.mountScope.effectKeys.clear()
        record.mountScope.closeBuildDependencies()
    }
    for ((_, record) in store.automaticEntries) {
        record.closeRenderNodes()
        record.mountScope.stateKeys.clear()
        record.mountScope.retainedKeys.clear()
        record.mountScope.automaticKeys.clear()
        record.mountScope.effectKeys.clear()
        record.mountScope.closeBuildDependencies()
    }
    store.entries.clear()
    store.retainedEntries.clear()
    store.automaticEntries.clear()
    store.rootMountScope.stateKeys.clear()
    store.rootMountScope.retainedKeys.clear()
    store.rootMountScope.automaticKeys.clear()
    store.rootMountScope.effectKeys.clear()
    clearBuildTransaction(store)
}

func currentMountBuild(store: StateStore): StateMountBuild {
    if (store.activeMountBuilds.isEmpty()) {
        throw IllegalStateException("Remembered state must be accessed during a build")
    }
    store.activeMountBuilds[store.activeMountBuilds.size - 1]
}
