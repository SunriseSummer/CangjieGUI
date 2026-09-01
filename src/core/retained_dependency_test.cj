package cui.core

private class DependencyBuildCounter {
    var value: Int64 = 0
}

@Test
func retainedSubtreeAutomaticallyRebuildsForBuildStateRead(): Unit {
    let store = StateStore()
    let source = State<Int64>(0)
    let builds = DependencyBuildCounter()
    let captured = State<Int64>(-1)
    let retained = State<?RetainedSubtree>(None)
    let body: () -> Unit = {
        => let boundary = RetainedSubtree("automatic-state") {
            builds.value += 1
            captured.value = source.value
            Spacer()
        }
        retained.value = Some(boundary)
    }

    let _ = buildRoot(body, store)
    let _ = buildRoot(body, store)
    @Expect(builds.value, Int64(1))

    source.value = 7
    let _ = buildRoot(body, store)
    @Expect(builds.value, Int64(2))
    @Expect(captured.value, Int64(7))
    let stats = retained.value.getOrThrow().cacheStats()
    @Expect(stats.buildDependencyCount, Int64(1))
    @Expect(stats.buildInvalidations, UInt64(1))
}

@Test
func retainedBuildDependenciesFollowDynamicBranches(): Unit {
    let store = StateStore()
    let usePrimary = State<Bool>(true)
    let primary = State<Int64>(0)
    let secondary = State<Int64>(0)
    let builds = DependencyBuildCounter()
    let body: () -> Unit = {
        => RetainedSubtree("dynamic-dependencies") {
            builds.value += 1
            if (usePrimary.value) {
                let _ = primary.value
            } else {
                let _ = secondary.value
            }
            Spacer()
        }
    }

    let _ = buildRoot(body, store)
    primary.value = 1
    let _ = buildRoot(body, store)
    usePrimary.value = false
    let _ = buildRoot(body, store)

    primary.value = 2
    let _ = buildRoot(body, store)
    @Expect(builds.value, Int64(3))

    secondary.value = 1
    let _ = buildRoot(body, store)
    @Expect(builds.value, Int64(4))
}

@Test
func nestedRetainedStateInvalidationPropagatesThroughCleanParent(): Unit {
    let store = StateStore()
    let source = State<Int64>(0)
    let nestedBuilds = DependencyBuildCounter()
    let captured = State<Int64>(-1)
    let body: () -> Unit = {
        => RetainedSubtree("automatic-parent") {
            RetainedSubtree("automatic-child") {
                nestedBuilds.value += 1
                captured.value = source.value
                Spacer()
            }
        }
    }

    let _ = buildRoot(body, store)
    let _ = buildRoot(body, store)
    source.value = 9
    let _ = buildRoot(body, store)

    @Expect(nestedBuilds.value, Int64(2))
    @Expect(captured.value, Int64(9))
}

@Test
func failedRootBuildKeepsPreviouslyCommittedDependencies(): Unit {
    let store = StateStore()
    let primary = State<Int64>(0)
    let abandoned = State<Int64>(0)
    let builds = DependencyBuildCounter()
    let primaryBody: () -> Unit = {
        => RetainedSubtree("dependency-transaction") {
            builds.value += 1
            let _ = primary.value
            Spacer()
        }
    }

    let _ = buildRoot(primaryBody, store)
    primary.value = 1
    var rejected = false
    try {
        let _ = buildRoot(
            {
                =>
                    RetainedSubtree("dependency-transaction") {
                        builds.value += 1
                        let _ = abandoned.value
                        Spacer()
                    }
                    throw IllegalStateException("abort dependency replacement")
            },
            store
        )
    } catch (_: IllegalStateException) {
        rejected = true
    }
    let _ = buildRoot(primaryBody, store)
    abandoned.value = 1
    let _ = buildRoot(primaryBody, store)

    @Expect(rejected)
    @Expect(builds.value, Int64(3))
}

@Test
func stateWriteDuringRetainedBuildKeepsScopeDirtyForRetry(): Unit {
    let store = StateStore()
    let source = State<Int64>(0)
    let builds = DependencyBuildCounter()
    let body: () -> Unit = {
        => RetainedSubtree("write-during-build") {
            builds.value += 1
            let value = source.value
            if (value == 0) {
                source.value = 1
            }
            Spacer()
        }
    }

    let _ = buildRoot(body, store)
    let _ = buildRoot(body, store)
    let _ = buildRoot(body, store)
    @Expect(builds.value, Int64(2))
}

@Test
func indexedBuildDependenciesDeduplicateReuseAndPruneByStateIdentity(): Unit {
    let scope = StateMountScope()
    let primary = State<Int64>(0)
    let secondary = State<String>("initial")
    let invalidations = DependencyBuildCounter()
    let first = StateMountBuild(scope, collectStateReads: true, invalidate: {=> invalidations.value += 1})

    first.readState(primary)
    first.readState(primary)
    first.readState(secondary)
    first.commitStateReads()
    @Expect(scope.buildDependencyCount(), Int64(2))

    let second = StateMountBuild(scope, collectStateReads: true, invalidate: {=> invalidations.value += 1})
    second.readState(secondary)
    second.commitStateReads()
    @Expect(scope.buildDependencyCount(), Int64(1))

    primary.value = 1
    @Expect(invalidations.value, Int64(0))
    secondary.value = "changed"
    @Expect(invalidations.value, Int64(1))
    scope.closeBuildDependencies()
}

@Test
func buildDependencyFrontierPromotesOnlyAfterEightUniqueSources(): Unit {
    let scope = StateMountScope()
    let states = Array<State<Int64>>(10, {index => State<Int64>(index)})
    let first = StateMountBuild(scope, collectStateReads: true, invalidate: {=> ()})

    for (index in 0..8) {
        first.readState(states[index])
        first.readState(states[index])
    }
    @Expect(!first.usesIndexedDependencySources())
    first.readState(states[8])
    @Expect(first.usesIndexedDependencySources())
    first.readState(states[9])
    first.commitStateReads()
    @Expect(scope.buildDependencyCount(), Int64(10))
    @Expect(scope.committedBuildDependencies().getOrThrow().bySource.isSome())

    let second = StateMountBuild(scope, collectStateReads: true, invalidate: {=> ()})
    for (index in 0..8) {
        second.readState(states[index])
    }
    @Expect(!second.usesIndexedDependencySources())
    second.commitStateReads()
    @Expect(scope.buildDependencyCount(), Int64(8))
    @Expect(scope.committedBuildDependencies().getOrThrow().bySource.isNone())
    for (index in 0..8) {
        @Expect(states[index].listenerSlotCount(), Int64(1))
    }
    @Expect(states[8].listenerSlotCount(), Int64(0))
    @Expect(states[9].listenerSlotCount(), Int64(0))
    scope.closeBuildDependencies()
}

@Test
func committedDependencyFacetPromotesAtNineAndDemotesAtEight(): Unit {
    let scope = StateMountScope()
    let states = Array<State<Int64>>(9, {index => State<Int64>(index)})
    let first = StateMountBuild(scope, collectStateReads: true, invalidate: {=> ()})
    for (index in 0..8) {
        first.readState(states[index])
    }
    first.commitStateReads()
    @Expect(scope.committedBuildDependencies().getOrThrow().bySource.isNone())

    let second = StateMountBuild(scope, collectStateReads: true, invalidate: {=> ()})
    for (state in states) {
        second.readState(state)
    }
    second.commitStateReads()
    @Expect(scope.committedBuildDependencies().getOrThrow().bySource.isSome())

    let third = StateMountBuild(scope, collectStateReads: true, invalidate: {=> ()})
    for (index in 0..8) {
        third.readState(states[index])
    }
    third.commitStateReads()
    @Expect(scope.committedBuildDependencies().getOrThrow().bySource.isNone())
    @Expect(states[8].listenerSlotCount(), Int64(0))
    scope.closeBuildDependencies()
}

@Test
func promotedBuildDependencyFrontierRollsBackNewSubscriptions(): Unit {
    let scope = StateMountScope()
    let states = Array<State<Int64>>(9, {index => State<Int64>(index)})
    let build = StateMountBuild(scope, collectStateReads: true, invalidate: {=> ()})
    for (state in states) {
        build.readState(state)
    }

    @Expect(build.usesIndexedDependencySources())
    build.cancelStateReads()
    @Expect(scope.buildDependencyCount(), Int64(0))
    for (state in states) {
        @Expect(state.listenerSlotCount(), Int64(0))
    }
}

@Test
func declarationKeyFrontiersPreserveThresholdDuplicatesAndCategoryIndependence(): Unit {
    let scope = StateMountScope()
    let build = StateMountBuild(scope, collectStateReads: false, invalidate: {=> ()})
    for (index in 0..9) {
        let path = "state-${index}"
        build.visitState(path, "key '${path}'")
    }
    for (index in 0..9) {
        @Expect(build.containsState("state-${index}"))
    }

    var didThrow = false
    try {
        build.visitState("state-8", "key 'state-8'")
    } catch (_: IllegalStateException) {
        didThrow = true
    }
    @Expect(didThrow)

    let shared = "shared-path"
    let hasExternalRevision = false
    build.visitState(shared, "key '${shared}'")
    build.visitRetained(shared, shared, hasExternalRevision)
    build.visitAutomatic(shared, shared)
    build.visitEffect(shared, shared, hasExternalRevision)
    @Expect(build.containsState(shared))
    @Expect(build.containsRetained(shared))
    @Expect(build.containsAutomatic(shared))
    @Expect(build.containsEffect(shared))
}

@Test
func stateStoreReusesAnEmptyBuildTransactionArena(): Unit {
    let store = StateStore()
    beginMountBuild(store)
    let first = currentMountBuild(store)
    first.visitState("state", "key 'state'")
    first.visitRetained("retained", "retained", true)
    first.visitAutomatic("automatic", "automatic")
    first.visitEffect("effect", "effect", true)
    finishMountBuild(store)

    beginMountBuild(store)
    let second = currentMountBuild(store)

    @Expect(refEq((first as Object).getOrThrow(), (second as Object).getOrThrow())) // cjcheck-ignore: unchecked-cast # allocation reuse is the invariant under test
    @Expect(second.stateKeys.isEmpty())
    @Expect(second.retainedKeys.isEmpty())
    @Expect(second.automaticKeys.isEmpty())
    @Expect(second.effectKeys.isEmpty())
    @Expect(!second.hasExternalRetainedRevision)
    @Expect(!second.hasExternalEffectRevision)
    @Expect(!second.forceAutomaticDescendants)
    @Expect(second.automaticSubtreeWeight, Int64(0))
    @Expect(second.automaticMaxBranching, Int64(0))

    // Reusing a declaration from the previous logical build must not look like a duplicate.
    second.visitState("state", "key 'state'")
    @Expect(second.stateKeys.size, Int64(1))
    cancelMountBuild(store)
}

@Test
func buildTransactionArenaRejectsReuseBeforeDependencyRollback(): Unit {
    let scope = StateMountScope()
    let source = State<Int64>(0)
    let build = StateMountBuild(scope, collectStateReads: true, invalidate: {=> ()})
    build.readState(source)

    var didThrow = false
    try {
        build.restart(scope, collectStateReads: true, invalidate: {=> ()})
    } catch (_: IllegalStateException) {
        didThrow = true
    }
    @Expect(didThrow)
    @Expect(source.listenerSlotCount(), Int64(1))

    build.cancelStateReads()
    build.restart(scope, collectStateReads: true, invalidate: {=> ()})
    @Expect(source.listenerSlotCount(), Int64(0))
}

@Test
func buildTransactionArenaRetainsOnlyItsBoundedPrefix(): Unit {
    let store = StateStore()
    let scope = StateMountScope()
    for (_ in 0..300) {
        let _ = acquireMountBuild(store, scope, collectStateReads: false, invalidate: {=> ()})
    }

    @Expect(store.mountBuildArena.size, Int64(256))
    @Expect(store.mountBuildArenaCursor, Int64(256))
    releaseMountBuildArena(store)
    @Expect(store.mountBuildArenaCursor, Int64(0))
}

@Test
func committedMountFacetsStaySparseAndDemoteAfterLastValue(): Unit {
    let store = StateStore()
    let source = State<Int64>(0)
    let emptyBody: () -> Unit = {=> Spacer()}
    let dependencyBody: () -> Unit = {
        =>
            let _ = source.value
            Spacer()
    }
    let ownershipBody: () -> Unit = {
        =>
            let _ = rememberState<Int64>("owned") {1}
            Spacer()
    }

    let _ = buildRoot(emptyBody, store)
    @Expect(store.rootMountScope.mountOwnership.isNone())
    @Expect(store.rootMountScope.buildDependencyFacet.isNone())

    let _ = buildRoot(dependencyBody, store)
    @Expect(store.rootMountScope.mountOwnership.isNone())
    @Expect(store.rootMountScope.buildDependencyFacet.isSome())
    @Expect(store.rootMountScope.buildDependencyCount(), Int64(1))

    let _ = buildRoot(emptyBody, store)
    @Expect(store.rootMountScope.buildDependencyFacet.isNone())
    @Expect(source.listenerSlotCount(), Int64(0))

    let _ = buildRoot(ownershipBody, store)
    @Expect(store.rootMountScope.mountOwnership.isSome())
    @Expect(store.rootMountScope.buildDependencyFacet.isNone())
    @Expect(store.rootMountScope.stateKeyCount(), Int64(1))

    let _ = buildRoot(emptyBody, store)
    @Expect(store.rootMountScope.mountOwnership.isNone())
    @Expect(store.entries.isEmpty())
}

@Test
func stateReadingAutomaticLeavesDoNotAllocateOwnershipFacets(): Unit {
    let store = StateStore()
    enableAutomaticComposition(store)
    let sources = Array<State<Int64>>(32, {index => State<Int64>(index)})
    let body: () -> Unit = {
        => VStack {
            for (index in 0..sources.size) {
                Panel(flexible: false) {
                    let _ = sources[index].value
                    Spacer()
                }
            }
        }
    }

    let _ = buildRoot(body, store)
    var dependencyLeaves: Int64 = 0
    for ((_, record) in store.automaticEntries) {
        if (record.mountScope.buildDependencyFacet.isSome()) {
            dependencyLeaves += 1
            @Expect(record.mountScope.mountOwnership.isNone())
            @Expect(record.mountScope.buildDependencyFacet.getOrThrow().bySource.isNone())
        }
    }
    @Expect(dependencyLeaves, Int64(32))

    store.clear()
    for (source in sources) {
        @Expect(source.listenerSlotCount(), Int64(0))
    }
}
