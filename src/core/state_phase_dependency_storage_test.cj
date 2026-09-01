package cui.core

@Test
func emptyPhaseCollectionAllocatesNoDependencyStorage(): Unit {
    let dependencies = PhaseStateDependencies({=> ()})
    @Expect(dependencies.dependencies.isNone())
    @Expect(dependencies.dependenciesBySource.isNone())
    @Expect(dependencies.pending.isNone())
    @Expect(dependencies.pendingSources.isNone())

    @Expect(collectPhaseStateReads<Int64>(dependencies, {=> 7}), Int64(7))
    @Expect(dependencies.size, Int64(0))
    @Expect(dependencies.dependencies.isNone())
    @Expect(dependencies.dependenciesBySource.isNone())
    @Expect(dependencies.pending.isNone())
    @Expect(dependencies.pendingSources.isNone())
}

@Test
func singlePhaseDependencyUsesLinearCommittedAndPendingFrontiers(): Unit {
    let source = State<Int64>(1)
    let dependencies = PhaseStateDependencies({=> ()})
    for (_ in 0..2) {
        @Expect(collectPhaseStateReads<Int64>(dependencies, {=> source.value}), Int64(1))
        @Expect(dependencies.size, Int64(1))
        @Expect(dependencies.dependencies.isSome())
        @Expect(dependencies.dependenciesBySource.isNone())
        @Expect(dependencies.pending.isSome())
        @Expect(dependencies.pendingSources.isNone())
        @Expect(source.listenerSlotCount(), Int64(1))
    }

    let _ = collectPhaseStateReads<Int64>(dependencies, {=> 0})
    @Expect(dependencies.size, Int64(0))
    @Expect(dependencies.dependencies.isNone())
    @Expect(dependencies.pending.isNone())
    @Expect(source.listenerSlotCount(), Int64(0))
}

@Test
func phaseDependencyFrontierPromotesAtNineAndDemotesAtEight(): Unit {
    let states = Array<State<Int64>>(9, {index => State<Int64>(index)})
    let dependencies = PhaseStateDependencies({=> ()})
    let first = collectPhaseStateReads<Int64>(dependencies, {
        =>
            var total: Int64 = 0
            for (index in 0..8) {
                total += states[index].value
            }
            total
    })
    @Expect(first, Int64(28))
    @Expect(dependencies.dependenciesBySource.isNone())
    @Expect(dependencies.pendingSources.isNone())

    let second = collectPhaseStateReads<Int64>(dependencies, {
        =>
            var total: Int64 = 0
            for (state in states) {
                total += state.value
            }
            total
    })
    @Expect(second, Int64(36))
    @Expect(dependencies.dependenciesBySource.isSome())
    @Expect(dependencies.pendingSources.isSome())

    let _ = collectPhaseStateReads<Int64>(dependencies, {
        =>
            var total: Int64 = 0
            for (index in 0..8) {
                total += states[index].value
            }
            total
    })
    @Expect(dependencies.dependenciesBySource.isNone())
    @Expect(dependencies.pendingSources.isNone())
    @Expect(states[8].listenerSlotCount(), Int64(0))
    dependencies.close()
}

@Test
func failedPhaseCollectionKeepsCommittedStorageAndDropsCreatedEdges(): Unit {
    let stable = State<Int64>(1)
    let transient = State<Int64>(2)
    let dependencies = PhaseStateDependencies({=> ()})
    let _ = collectPhaseStateReads<Int64>(dependencies, {=> stable.value})
    var didThrow = false
    try {
        let _ = collectPhaseStateReads<Int64>(dependencies, {
            =>
                let _ = stable.value
                let _ = transient.value
                throw IllegalStateException("expected phase collection failure")
        })
    } catch (_: IllegalStateException) {
        didThrow = true
    }

    @Expect(didThrow)
    @Expect(dependencies.size, Int64(1))
    @Expect(dependencies.dependenciesBySource.isNone())
    @Expect(stable.listenerSlotCount(), Int64(1))
    @Expect(transient.listenerSlotCount(), Int64(0))
    dependencies.close()
}

@Test
func unchangedWidePhaseTraceReusesCommittedPrefixWithoutTransientIndex(): Unit {
    let states = Array<State<Int64>>(10, {index => State<Int64>(index)})
    let dependencies = PhaseStateDependencies({=> ()})
    let readAll: () -> Int64 = {
        =>
            var total: Int64 = 0
            for (state in states) {
                total += state.value
            }
            total
    }

    @Expect(collectPhaseStateReads<Int64>(dependencies, readAll), Int64(45))
    @Expect(dependencies.pendingSources.isSome())
    @Expect(collectPhaseStateReads<Int64>(dependencies, readAll), Int64(45))
    @Expect(dependencies.pendingSources.isNone())
    @Expect(collectPhaseStateReads<Int64>(dependencies, readAll), Int64(45))
    for (state in states) {
        @Expect(state.listenerSlotCount(), Int64(1))
    }
    dependencies.close()
}

@Test
func widePhaseTraceFallsBackForReorderAndReplacement(): Unit {
    let states = Array<State<Int64>>(10, {index => State<Int64>(index)})
    let replacement = State<Int64>(100)
    let dependencies = PhaseStateDependencies({=> ()})
    let _ = collectPhaseStateReads<Int64>(dependencies, {
        =>
            for (state in states) {
                let _ = state.value
            }
            0
    })
    let _ = collectPhaseStateReads<Int64>(dependencies, {
        =>
            var index = states.size - 1
            while (index >= 0) {
                let _ = states[index].value
                index -= 1
            }
            0
    })
    let _ = collectPhaseStateReads<Int64>(dependencies, {
        =>
            for (index in 0..9) {
                let _ = states[index].value
            }
            let _ = replacement.value
            0
    })

    @Expect(dependencies.size, Int64(10))
    for (index in 0..9) {
        @Expect(states[index].listenerSlotCount(), Int64(1))
    }
    @Expect(states[9].listenerSlotCount(), Int64(0))
    @Expect(replacement.listenerSlotCount(), Int64(1))
    dependencies.close()
}
