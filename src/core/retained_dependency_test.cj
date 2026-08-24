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
