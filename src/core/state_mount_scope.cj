package cui.core

import std.collection.HashMap

/* Persistent ownership node for a rebuild boundary; child scopes isolate retained dependencies. */
class StateMountScope {
    let elementId: ElementId
    let parent: ?StateMountScope
    let diagnosticPath: String
    let depth: Int64
    var ownerRecord: ?RetainedRecord = None
    private var automaticDamageSink: ?(() -> Unit) = None
    private var automaticPhaseSink: ?AutomaticRenderPhaseSink = None
    var mountOwnership: ?CommittedMountOwnership = None
    var buildDependencyFacet: ?CommittedBuildDependencies = None
    var buildDirty = false
    var buildSelfDirty = false
    var buildDescendantDirty = false
    var buildDirtyReason = ""
    var dirtyVersion: UInt64 = UInt64(0)
    var buildInvalidations: UInt64 = UInt64(0)

    init() {
        this.elementId = ElementId.detached()
        this.parent = None
        this.diagnosticPath = "<root>"
        this.depth = 0
    }

    init(elementId: ElementId) {
        this.elementId = elementId
        this.parent = None
        this.diagnosticPath = "<root>"
        this.depth = 0
    }

    init(parent: StateMountScope) {
        this(parent, "<detached>")
    }

    init(parent: StateMountScope, diagnosticPath: String) {
        this(parent, diagnosticPath, ElementId.detached())
    }

    init(parent: StateMountScope, diagnosticPath: String, elementId: ElementId) {
        this.elementId = elementId
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
        this.discardBuildDependencies()
        buildDirty = false
        buildSelfDirty = false
        buildDescendantDirty = false
        buildDirtyReason = ""
        automaticDamageSink = None
        automaticPhaseSink = None
    }

    func requiresExternalDeclarationReplay(): Bool {
        match (mountOwnership) {
            case Some(ownership) => ownership.hasExternalRetainedRevision || ownership.hasExternalEffectRevision
            case None => false
        }
    }

    func clearCommittedOwnership(): Unit {
        mountOwnership = None
    }

    func committedOwnership(): ?CommittedMountOwnership {
        mountOwnership
    }

    func ensureCommittedOwnership(): CommittedMountOwnership {
        match (mountOwnership) {
            case Some(ownership) => ownership
            case None =>
                let ownership = CommittedMountOwnership()
                mountOwnership = Some(ownership)
                ownership
        }
    }

    func stateKeyCount(): Int64 {
        match (mountOwnership) {
            case Some(ownership) => ownership.stateKeys.size
            case None => 0
        }
    }

    func retainedKeyCount(): Int64 {
        match (mountOwnership) {
            case Some(ownership) => ownership.retainedKeys.size
            case None => 0
        }
    }

    func automaticKeyCount(): Int64 {
        match (mountOwnership) {
            case Some(ownership) => ownership.automaticKeys.size
            case None => 0
        }
    }

    func effectKeyCount(): Int64 {
        match (mountOwnership) {
            case Some(ownership) => ownership.effectKeys.size
            case None => 0
        }
    }

    func hasCommittedImplicitSlotShapes(): Bool {
        match (mountOwnership) {
            case Some(ownership) => ownership.implicitSlotShapes.isSome()
            case None => false
        }
    }

    func committedImplicitSlotShapes(): ?HashMap<String, ImplicitSlotShape> {
        match (mountOwnership) {
            case Some(ownership) => ownership.implicitSlotShapes
            case None => None
        }
    }

    func committedBuildDependencies(): ?CommittedBuildDependencies {
        buildDependencyFacet
    }

    func ensureBuildDependencies(): CommittedBuildDependencies {
        match (buildDependencyFacet) {
            case Some(dependencies) => dependencies
            case None =>
                let dependencies = CommittedBuildDependencies()
                buildDependencyFacet = Some(dependencies)
                dependencies
        }
    }

    func buildDependencyCount(): Int64 {
        match (buildDependencyFacet) {
            case Some(dependencies) => dependencies.dependencies.size
            case None => 0
        }
    }

    func discardBuildDependencies(): Unit {
        match (buildDependencyFacet) {
            case Some(dependencies) => for (dependency in dependencies.dependencies) {
                dependency.close()
            }
            case None => ()
        }
        buildDependencyFacet = None
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
    store.elementAddedDuringBuild.clear()
    store.retainedReplacements.clear()
    store.automaticReplacements.clear()
    store.mountBuildArenaCursor = 0
    let root = acquireMountBuild(
        store,
        store.rootMountScope,
        collectStateReads: true,
        invalidate: {
            =>
                store.rootMountScope.markBuildDirty()
                markFullRetainedDamage(store)
        },
        forceAutomaticDescendants: store.rootMountScope.buildSelfDirty
    )
    registerCurrentImplicitSlotScope(store, root)
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

func beginMountStateReadCollection(store: StateStore): Unit {
    beginStateReadCollection(StateReadCollector.Mount(currentMountBuild(store)))
}

func currentMountScope(store: StateStore): StateMountScope {
    currentMountBuild(store).scope
}

func visitRetainedChild(store: StateStore, path: String, key: String, hasExternalRevision: Bool): Unit {
    currentMountBuild(store).visitRetained(path, key, hasExternalRevision)
}

func visitLifecycleEffectKey(store: StateStore, path: String, key: String, hasExternalRevision: Bool): Unit {
    currentMountBuild(store).visitEffect(path, key, hasExternalRevision)
}

func beginRetainedMount(store: StateStore, scope: StateMountScope): Unit {
    // Executing a manual retained body means either mount, explicit revision change, or invalidation;
    // ordinary nested bodies must therefore refresh captured values conservatively.
    let build = acquireMountBuild(store, scope, collectStateReads: true, invalidate: {=> scope.markBuildDirty()},
        forceAutomaticDescendants: true)
    registerCurrentImplicitSlotScope(store, build)
    store.mountBuilds.add(build)
    store.activeMountBuilds.add(build)
    beginMountStateReadCollection(store)
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

    // Shape checks run before any ownership mutation, so a positional-slot error can roll the
    // complete root build back without partially committing child scopes.
    for (build in store.mountBuilds) {
        build.validateImplicitSlotShape()
    }

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
    for (replacement in store.automaticReplacements) {
        replacement.cancel()
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
    i = store.elementAddedDuringBuild.size - 1
    while (i >= 0) {
        store.elementArena.releaseIfLive(store.elementAddedDuringBuild[i])
        i -= 1
    }
    clearBuildTransaction(store)
}

func clearMountedState(store: StateStore): Unit {
    for ((_, record) in store.retainedEntries) {
        record.close()
        record.mountScope.clearCommittedOwnership()
        record.mountScope.closeBuildDependencies()
    }
    for ((_, record) in store.automaticEntries) {
        record.closeRenderNodes()
        record.mountScope.clearCommittedOwnership()
        record.mountScope.closeBuildDependencies()
    }
    store.entries.clear()
    store.retainedEntries.clear()
    store.automaticEntries.clear()
    store.elementArena.clear()
    store.rootMountScope.clearCommittedOwnership()
    clearBuildTransaction(store)
}

func currentMountBuild(store: StateStore): StateMountBuild {
    if (store.activeMountBuilds.isEmpty()) {
        throw IllegalStateException("Remembered state must be accessed during a build")
    }
    store.activeMountBuilds[store.activeMountBuilds.size - 1]
}

func registerCurrentImplicitSlotScope(store: StateStore, build: StateMountBuild): Unit {
    if (build.hasCommittedImplicitSlotShapes()) {
        build.registerImplicitSlotScope(store.implicitSlotNamespace())
    }
}
