package cui.core

import std.collection.ArrayList

private class SlotEffectBuildState {
    var builds: Int64 = 0
    var revision: UInt64 = UInt64(0)
}

@Test
func keylessMountEffectCommitsOnceAndUnmountsWithKeyedScope(): Unit {
    let store = StateStore()
    let log = ArrayList<String>()
    let visible = State<Bool>(true)
    let body: () -> Unit = {
        => VStack {
            if (visible.value) {
                Keyed("effect-owner") {
                    mountEffect {EffectProbe("keyless", log)}
                    Spacer()
                }
            }
        }
    }

    let _ = buildRoot(body, store)
    let _ = buildRoot(body, store)
    @Expect(log.toArray(), ["mount:keyless"])

    visible.value = false
    let _ = buildRoot(body, store)
    @Expect(log.toArray(), ["mount:keyless", "close:keyless"])
}

@Test
func keylessMountEffectDoesNotPreventCleanAutomaticAncestorHit(): Unit {
    let store = StateStore()
    enableAutomaticComposition(store)
    let log = ArrayList<String>()
    let counter = SlotEffectBuildState()
    let body: () -> Unit = {
        =>
            counter.builds += 1
            mountEffect {EffectProbe("stable", log)}
            Spacer()
    }

    let _ = buildRoot(body, store)
    let _ = buildRoot(body, store)

    @Expect(counter.builds, Int64(1))
    @Expect(log.toArray(), ["mount:stable"])
}

@Test
func keylessLifecycleEffectRevisionReplaysAndReplaces(): Unit {
    let store = StateStore()
    enableAutomaticComposition(store)
    let log = ArrayList<String>()
    let counter = SlotEffectBuildState()
    let body: () -> Unit = {
        =>
            counter.builds += 1
            lifecycleEffect(counter.revision) {EffectProbe("${counter.revision}", log)}
            Spacer()
    }

    let _ = buildRoot(body, store)
    counter.revision = UInt64(1)
    let _ = buildRoot(body, store)

    @Expect(counter.builds, Int64(2))
    @Expect(log.toArray(), ["mount:0", "mount:1", "close:0"])
}

@Test
func keylessSlotKindDriftRejectsBeforeEffectSetup(): Unit {
    let store = StateStore()
    let log = ArrayList<String>()
    let useEffect = State<Bool>(false)
    let body: () -> Unit = {
        =>
            if (useEffect.value) {
                mountEffect {EffectProbe("unexpected", log)}
            } else {
                let _ = remember<Int64> {7}
            }
            Spacer()
    }

    let _ = buildRoot(body, store)
    useEffect.value = true
    var didThrow = false
    try {
        let _ = buildRoot(body, store)
    } catch (_: IllegalStateException) {
        didThrow = true
    }

    @Expect(didThrow)
    @Expect(log.isEmpty())
    useEffect.value = false
    let _ = buildRoot(body, store)
}

@Test
func keylessEffectCountDriftRollsBackAndKeepsCommittedResource(): Unit {
    let store = StateStore()
    let log = ArrayList<String>()
    let declare = State<Bool>(true)
    let body: () -> Unit = {
        =>
            if (declare.value) {
                mountEffect {EffectProbe("stable", log)}
            }
            Spacer()
    }

    let _ = buildRoot(body, store)
    declare.value = false
    var didThrow = false
    try {
        let _ = buildRoot(body, store)
    } catch (_: IllegalStateException) {
        didThrow = true
    }
    @Expect(didThrow)
    @Expect(log.toArray(), ["mount:stable"])

    declare.value = true
    let _ = buildRoot(body, store)
    store.clear()
    @Expect(log.toArray(), ["mount:stable", "close:stable"])
}

@Test
func keylessEffectSetupFailureRollsBackPreparedResourcesInReverse(): Unit {
    let store = StateStore()
    let log = ArrayList<String>()
    var didThrow = false
    try {
        let _ = buildRoot({
            =>
                mountEffect {EffectProbe("first", log)}
                mountEffect {EffectProbe("second", log)}
                mountEffect {
                    log.add("setup:third")
                    throw IllegalStateException("expected keyless setup failure")
                }
                Spacer()
        }, store)
    } catch (_: IllegalStateException) {
        didThrow = true
    }

    @Expect(didThrow)
    @Expect(log.toArray(), ["mount:first", "mount:second", "setup:third", "close:second", "close:first"])
}
