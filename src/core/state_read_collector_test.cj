package cui.core

private class StateReadCollectorProbe {
    var phaseInvalidations: Int64 = 0
    var phaseRejected = false
}

@Test
func nestedPhaseStateCollectorRestoresOuterCollector(): Unit {
    let outer = PhaseStateDependencies({=> ()})
    let inner = PhaseStateDependencies({=> ()})
    let first = State<Int64>(1)
    let nested = State<Int64>(2)
    let last = State<Int64>(3)

    let value = collectPhaseStateReads<Int64>(outer, {
        =>
            let before = first.value
            let middle = collectPhaseStateReads<Int64>(inner, {=> nested.value})
            before + middle + last.value
    })

    @Expect(value, Int64(6))
    @Expect(outer.size, Int64(2))
    @Expect(inner.size, Int64(1))
    outer.close()
    inner.close()
}

@Test
func failingNestedPhaseCollectorRestoresMountCollector(): Unit {
    let store = StateStore()
    let before = State<Int64>(1)
    let failedPhase = State<Int64>(2)
    let after = State<Int64>(3)
    let probe = StateReadCollectorProbe()
    let phase = PhaseStateDependencies({=> probe.phaseInvalidations += 1})
    let body: () -> Unit = {
        =>
            let _ = before.value
            try {
                let _ = collectPhaseStateReads<Int64>(phase, {
                    =>
                        let _ = failedPhase.value
                        throw IllegalStateException("abort nested phase collection")
                })
            } catch (_: IllegalStateException) {
                probe.phaseRejected = true
            }
            let _ = after.value
            Spacer()
    }

    let _ = buildRoot(body, store)
    @Expect(probe.phaseRejected)
    @Expect(store.rootMountScope.buildDependencyCount(), Int64(2))
    @Expect(phase.size, Int64(0))
    failedPhase.value = 4
    @Expect(probe.phaseInvalidations, Int64(0))
    before.value = 5
    @Expect(store.rootMountScope.buildDirty)
    store.clear()
    phase.close()
}
