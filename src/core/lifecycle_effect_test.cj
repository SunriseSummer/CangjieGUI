package cui.core

import std.collection.ArrayList

private class EffectProbe <: Resource {
    let name: String
    let log: ArrayList<String>
    var failuresRemaining: Int64
    var closed = false

    init(name: String, log: ArrayList<String>, failures!: Int64 = 0) {
        this.name = name
        this.log = log
        this.failuresRemaining = failures
        log.add("mount:${name}")
    }

    /** Whether this test resource completed cleanup. */
    public func isClosed(): Bool {
        closed
    }

    /** Records cleanup attempts and fails the configured number of times. */
    public func close(): Unit {
        if (closed) {
            return
        }
        log.add("close:${name}")
        if (failuresRemaining > 0) {
            failuresRemaining -= 1
            throw IllegalStateException("cleanup:${name}")
        }
        closed = true
    }
}

@Test
func mountEffectCommitsOnceAndClosesOnUnmount(): Unit {
    let store = StateStore()
    let log = ArrayList<String>()
    let body: () -> Unit = {
        => mountEffect("listener", {=> EffectProbe("listener", log)})
        Spacer()
    }

    let _ = buildRoot(body, store)
    let _ = buildRoot(body, store)
    @Expect(log.toArray(), ["mount:listener"])

    let _ = buildRoot({=> Spacer()}, store)
    @Expect(log.toArray(), ["mount:listener", "close:listener"])
}

@Test
func failedBuildNeverStartsLifecycleEffect(): Unit {
    let store = StateStore()
    let log = ArrayList<String>()
    var failed = false
    try {
        let _ = buildRoot(
            {
                => mountEffect("listener", {=> EffectProbe("listener", log)})
                throw IllegalStateException("body failed")
            },
            store
        )
    } catch (_: IllegalStateException) {
        failed = true
    }

    @Expect(failed)
    @Expect(log.isEmpty())
    let _ = buildRoot({=> mountEffect("listener", {=> EffectProbe("listener", log)}); Spacer()}, store)
    @Expect(log.toArray(), ["mount:listener"])
}

@Test
func lifecycleEffectRevisionPreparesReplacementBeforeClosingPrevious(): Unit {
    let store = StateStore()
    let log = ArrayList<String>()
    let build = {
        revision: UInt64 => buildRoot(
            {=> lifecycleEffect("listener", revision, {=> EffectProbe("${revision}", log)}); Spacer()},
            store
        )
    }

    let _ = build(UInt64(0))
    let _ = build(UInt64(1))
    let _ = build(UInt64(1))

    @Expect(log.toArray(), ["mount:0", "mount:1", "close:0"])
}

@Test
func failedLifecycleSetupKeepsPreviouslyCommittedEffect(): Unit {
    let store = StateStore()
    let log = ArrayList<String>()
    let _ = buildRoot(
        {=> lifecycleEffect("listener", UInt64(0), {=> EffectProbe("stable", log)}); Spacer()},
        store
    )

    var failed = false
    try {
        let _ = buildRoot(
            {
                => lifecycleEffect("listener", UInt64(1), {
                    => log.add("setup:failed")
                    throw IllegalStateException("setup failed")
                })
                Spacer()
            },
            store
        )
    } catch (_: IllegalStateException) {
        failed = true
    }
    let _ = buildRoot(
        {=> lifecycleEffect("listener", UInt64(0), {=> EffectProbe("unexpected", log)}); Spacer()},
        store
    )

    @Expect(failed)
    @Expect(log.toArray(), ["mount:stable", "setup:failed"])
    store.clear()
    @Expect(log.toArray(), ["mount:stable", "setup:failed", "close:stable"])
}

@Test
func partialLifecycleSetupRollsBackPreparedResourcesInReverse(): Unit {
    let store = StateStore()
    let log = ArrayList<String>()
    var failed = false
    try {
        let _ = buildRoot(
            {
                => mountEffect("first", {=> EffectProbe("first", log)})
                mountEffect("second", {=> EffectProbe("second", log)})
                mountEffect("third", {
                    => log.add("setup:third")
                    throw IllegalStateException("third setup failed")
                })
                Spacer()
            },
            store
        )
    } catch (_: IllegalStateException) {
        failed = true
    }

    @Expect(failed)
    @Expect(log.toArray(), ["mount:first", "mount:second", "setup:third", "close:second", "close:first"])
}

@Test
func retainedHitKeepsNestedEffectAndUnmountClosesIt(): Unit {
    let store = StateStore()
    let log = ArrayList<String>()
    let body: () -> Unit = {
        => RetainedSubtree("owner") {
            mountEffect("listener", {=> EffectProbe("nested", log)})
            Spacer()
        }
    }

    let _ = buildRoot(body, store)
    let _ = buildRoot(body, store)
    @Expect(log.toArray(), ["mount:nested"])
    let _ = buildRoot({=> Spacer()}, store)
    @Expect(log.toArray(), ["mount:nested", "close:nested"])
}

@Test
func clearClosesNestedEffectsChildFirstAndDeclarationsInReverse(): Unit {
    let store = StateStore()
    let log = ArrayList<String>()
    let _ = buildRoot(
        {
            => mountEffect("root", {=> EffectProbe("root", log)})
            RetainedSubtree("outer") {
                mountEffect("outer-first", {=> EffectProbe("outer-first", log)})
                mountEffect("outer-last", {=> EffectProbe("outer-last", log)})
                RetainedSubtree("inner") {
                    mountEffect("inner", {=> EffectProbe("inner", log)})
                    Spacer()
                }
            }
        },
        store
    )

    store.clear()
    @Expect(log.toArray(), ["mount:root", "mount:outer-first", "mount:outer-last", "mount:inner",
        "close:inner", "close:outer-last", "close:outer-first", "close:root"])
}

@Test
func cleanupFailureDoesNotSkipSiblingsAndIsRetried(): Unit {
    let store = StateStore()
    let log = ArrayList<String>()
    let _ = buildRoot(
        {
            => mountEffect("first", {=> EffectProbe("first", log)})
            mountEffect("second", {=> EffectProbe("second", log, failures: 1)})
            Spacer()
        },
        store
    )

    var failed = false
    try {
        let _ = buildRoot({=> Spacer()}, store)
    } catch (_: IllegalStateException) {
        failed = true
    }
    @Expect(failed)
    @Expect(log.toArray(), ["mount:first", "mount:second", "close:second", "close:first"])
    @Expect(retainedGraphDiagnostics(store).failedEffectCleanupCount, Int64(1))

    let _ = buildRoot({=> Spacer()}, store)
    @Expect(log.toArray(), ["mount:first", "mount:second", "close:second", "close:first", "close:second"])
    @Expect(retainedGraphDiagnostics(store).failedEffectCleanupCount, Int64(0))
}

@Test
func lifecycleEffectRejectsInvalidIdentityAndClosedSetupResource(): Unit {
    let store = StateStore()
    let log = ArrayList<String>()
    var duplicateRejected = false
    try {
        let _ = buildRoot(
            {
                => mountEffect("same", {=> EffectProbe("first", log)})
                mountEffect("same", {=> EffectProbe("second", log)})
                Spacer()
            },
            store
        )
    } catch (_: IllegalStateException) {
        duplicateRejected = true
    }
    @Expect(duplicateRejected)
    @Expect(log.isEmpty())

    let closed = EffectCleanup({=> ()})
    closed.close()
    var closedRejected = false
    try {
        let _ = buildRoot({=> mountEffect("closed", {=> closed}); Spacer()}, store)
    } catch (_: IllegalStateException) {
        closedRejected = true
    }
    @Expect(closedRejected)
}

@Test
func lifecycleSetupCannotDeclareStateOrNestedEffects(): Unit {
    let store = StateStore()
    let log = ArrayList<String>()
    var stateRejected = false
    try {
        let _ = buildRoot(
            {
                => mountEffect("outer", {
                    => let _ = rememberState<Int64>("illegal") {0}
                    EffectProbe("unreachable", log)
                })
                Spacer()
            },
            store
        )
    } catch (_: IllegalStateException) {
        stateRejected = true
    }

    var nestedRejected = false
    try {
        let _ = buildRoot(
            {
                => mountEffect("outer", {
                    => mountEffect("nested", {=> EffectProbe("nested", log)})
                    EffectProbe("unreachable", log)
                })
                Spacer()
            },
            store
        )
    } catch (_: IllegalStateException) {
        nestedRejected = true
    }

    @Expect(stateRejected)
    @Expect(nestedRejected)
    @Expect(log.isEmpty())
}

@Test
func effectCleanupIsIdempotentAndRetriesFailure(): Unit {
    let attempts = State<Int64>(0)
    let cleanup = EffectCleanup(
        {
            => attempts.value += 1
                if (attempts.value == 1) {
                    throw IllegalStateException("retry")
                }
        }
    )

    var failed = false
    try {
        cleanup.close()
    } catch (_: IllegalStateException) {
        failed = true
    }
    @Expect(failed)
    @Expect(!cleanup.isClosed())
    cleanup.close()
    cleanup.close()
    @Expect(cleanup.isClosed())
    @Expect(attempts.value, Int64(2))
}
