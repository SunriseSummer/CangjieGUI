package cui.core

private class DistinctDerivedProbe {
    var computes: Int64 = 0
    var firstInvalidations: Int64 = 0
    var secondInvalidations: Int64 = 0
    var observerCalls: Int64 = 0
    var didThrow = false
}

@Test
func unobservedDistinctDerivedRemainsLazy(): Unit {
    let source = State<Int64>(0)
    let probe = DistinctDerivedProbe()
    let selected = source.map<Int64>(
        {
            value =>
                probe.computes += 1
                value
        },
        policy: structuralEqualityPolicy<Int64>()
    )

    source.value = 1

    @Expect(probe.computes, Int64(0))
    @Expect(selected.value, Int64(1))
    @Expect(probe.computes, Int64(1))
}

@Test
func failedDistinctDependencyInitializationRollsBackSubscription(): Unit {
    let source = State<Int64>(1)
    let probe = DistinctDerivedProbe()
    let selected = source.map<Int64>(
        {
            value =>
                probe.computes += 1
                if (probe.computes == 1) {
                    throw IllegalStateException("expected initial distinct compute failure")
                }
                value
        },
        policy: structuralEqualityPolicy<Int64>()
    )
    let dependencies = PhaseStateDependencies({=> probe.firstInvalidations += 1})

    try {
        let _ = collectPhaseStateReads<Int64>(dependencies, {=> selected.value})
    } catch (_: IllegalStateException) {
        probe.didThrow = true
    }

    @Expect(probe.didThrow)
    @Expect(source.listenerSlotCount(), Int64(0))
    @Expect(collectPhaseStateReads<Int64>(dependencies, {=> selected.value}), Int64(1))
    @Expect(dependencies.size, Int64(1))
    dependencies.close()
    @Expect(source.listenerSlotCount(), Int64(0))
}

@Test
func distinctDerivedSuppressesEquivalentInvalidationAndRevision(): Unit {
    let source = State<Int64>(0)
    let probe = DistinctDerivedProbe()
    let parity = source.map<Int64>(
        {
            value =>
                probe.computes += 1
                value % 2
        },
        policy: structuralEqualityPolicy<Int64>()
    )
    let first = parity.observeInvalidation({=> probe.firstInvalidations += 1})
    let second = parity.observeInvalidation({=> probe.secondInvalidations += 1})
    let initialRevision = parity.revision

    source.value = 2

    @Expect(probe.computes, Int64(2))
    @Expect(parity.value, Int64(0))
    @Expect(parity.revision, initialRevision)
    @Expect(probe.firstInvalidations, Int64(0))
    @Expect(probe.secondInvalidations, Int64(0))

    source.value = 3

    @Expect(probe.computes, Int64(3))
    @Expect(parity.value, Int64(1))
    @Expect(parity.revision, initialRevision + UInt64(1))
    @Expect(probe.firstInvalidations, Int64(1))
    @Expect(probe.secondInvalidations, Int64(1))
    first.close()
    second.close()
}

@Test
func distinctDerivedObserverReceivesOnlyChangedQuotientClasses(): Unit {
    let source = State<Int64>(0)
    let probe = DistinctDerivedProbe()
    let parity = source.map<Int64>({value => value % 2}, policy: structuralEqualityPolicy<Int64>())
    let observation = parity.observe({_, _ => probe.observerCalls += 1})

    source.value = 2
    source.value = 3

    @Expect(probe.observerCalls, Int64(1))
    observation.close()
}

@Test
func distinctDerivedFailedComparisonDoesNotCommitAndCanRecover(): Unit {
    let source = State<Int64>(0)
    let probe = DistinctDerivedProbe()
    let policy = stateMutationPolicy<Int64>(
        {
            previous, current =>
                if (current == 2) {
                    throw IllegalStateException("expected distinct comparison failure")
                }
                previous == current
        }
    )
    let selected = source.map<Int64>({value => value}, policy: policy)
    let observation = selected.observeInvalidation({=> probe.firstInvalidations += 1})
    let initialRevision = selected.revision

    try {
        source.value = 2
    } catch (_: IllegalStateException) {
        probe.didThrow = true
    }

    @Expect(probe.didThrow)
    @Expect(probe.firstInvalidations, Int64(0))

    source.value = 3

    @Expect(selected.value, Int64(3))
    @Expect(selected.revision, initialRevision + UInt64(1))
    @Expect(probe.firstInvalidations, Int64(1))
    observation.close()
}

@Test
func derivedDistinctCanFilterAnExistingGraph(): Unit {
    let source = State<Int64>(1)
    let parity = source.map<Int64>({value => value % 2}).distinct(structuralEqualityPolicy<Int64>())
    let probe = DistinctDerivedProbe()
    let observation = parity.observeInvalidation({=> probe.firstInvalidations += 1})

    source.value = 3
    source.value = 4

    @Expect(probe.firstInvalidations, Int64(1))
    @Expect(parity.value, Int64(0))
    observation.close()
}
