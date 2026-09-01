package cui.core

private class FailingObservationSource <: Observable<Int64> {
    public func get(): Int64 {
        2
    }

    public prop revision: UInt64 {
        get() {
            UInt64(0)
        }
    }

    public func observe(_: (Int64, Int64) -> Unit): StateObservation<Int64> {
        throw IllegalStateException("expected observation connection failure")
    }
}

private class OrderedCustomObservable <: Observable<Int64> {
    private let name: String
    private let stored: Int64
    private let log: ValueCell<String>

    init(name: String, value: Int64, log: ValueCell<String>) {
        this.name = name
        this.stored = value
        this.log = log
    }

    public func get(): Int64 {
        log.value = log.value + "g${name};"
        stored
    }

    public prop revision: UInt64 {
        get() {
            log.value = log.value + "r${name};"
            UInt64(0)
        }
    }

    public func observe(_: (Int64, Int64) -> Unit): StateObservation<Int64> {
        StateObservation<Int64>({=> ()})
    }
}

@Test
func derivedCollectorUsesOneLazyAggregateEdgeForWideSources(): Unit {
    let states = Array<State<Int64>>(16, {index => State<Int64>(index)})
    let sources = Array<Observable<Int64>>(states.size, {index => states[index]})
    let computes = ValueCell<Int64>(0)
    let total = derive<Int64, Int64>(sources, {
        values =>
            computes.value += 1
            var result: Int64 = 0
            for (value in values) {
                result += value
            }
            result
    })
    let invalidations = ValueCell<Int64>(0)
    let dependencies = PhaseStateDependencies({=> invalidations.value += 1})

    let _ = collectPhaseStateReads<Int64>(dependencies, {=> total.value})
    let _ = collectPhaseStateReads<Int64>(dependencies, {=> total.value})
    @Expect(dependencies.size, Int64(1))
    @Expect(computes.value, Int64(1))

    states[15].value = 100
    @Expect(invalidations.value, Int64(1))
    @Expect(computes.value, Int64(1))
    @Expect(total.value, Int64(205))
    @Expect(computes.value, Int64(2))

    dependencies.close()
    for (state in states) {
        @Expect(state.listenerSlotCount(), Int64(0))
    }
}

@Test
func nestedDerivedCollectorInvalidatesWithoutEagerCompute(): Unit {
    let source = State<Int64>(2)
    let innerComputes = ValueCell<Int64>(0)
    let outerComputes = ValueCell<Int64>(0)
    let inner = source.map<Int64>({value =>
        innerComputes.value += 1
        value * 2
    })
    let outer = inner.map<Int64>({value =>
        outerComputes.value += 1
        value + 1
    })
    let invalidations = ValueCell<Int64>(0)
    let dependencies = PhaseStateDependencies({=> invalidations.value += 1})

    @Expect(collectPhaseStateReads<Int64>(dependencies, {=> outer.value}), Int64(5))
    @Expect(dependencies.size, Int64(1))
    source.value = 3
    @Expect(invalidations.value, Int64(1))
    @Expect(innerComputes.value, Int64(1))
    @Expect(outerComputes.value, Int64(1))
    @Expect(outer.value, Int64(7))
    @Expect(innerComputes.value, Int64(2))
    @Expect(outerComputes.value, Int64(2))
    dependencies.close()
}

@Test
func inlineDerivedCollectorReusesStableStateEdges(): Unit {
    let states = Array<State<Int64>>(16, {index => State<Int64>(index)})
    let sources = Array<Observable<Int64>>(states.size, {index => states[index]})
    let dependencies = PhaseStateDependencies({=> ()})

    for (_ in 0..2) {
        let value = collectPhaseStateReads<Int64>(dependencies, {
            => derive<Int64, Int64>(sources, {values => values[15]}).value
        })
        @Expect(value, Int64(15))
        @Expect(dependencies.size, states.size)
        for (state in states) {
            @Expect(state.listenerSlotCount(), Int64(1))
        }
    }
    dependencies.close()
}

@Test
func failedDerivedCollectionRollsBackAggregateSubscriptions(): Unit {
    let source = State<Int64>(1)
    let doubled = source.map<Int64>({value => value * 2})
    let dependencies = PhaseStateDependencies({=> ()})
    var didThrow = false

    try {
        let _ = collectPhaseStateReads<Int64>(dependencies, {
            =>
                let _ = doubled.value
                throw IllegalStateException("expected collection failure")
        })
    } catch (_: IllegalStateException) {
        didThrow = true
    }

    @Expect(didThrow)
    @Expect(source.listenerSlotCount(), Int64(0))
    dependencies.close()
}

@Test
func nestedDerivedObserverUsesInvalidationEdgesAndRemainsLazyUntilDelivery(): Unit {
    let source = State<Int64>(2)
    let computes = ValueCell<Int64>(0)
    let outer = source.map<Int64>({value =>
        computes.value += 1
        value * 2
    }).map<Int64>({value =>
        computes.value += 1
        value + 1
    })
    let received = ValueCell<Int64>(0)
    let observation = outer.observe({previous, current => received.value = previous * 100 + current})

    @Expect(computes.value, Int64(2))
    source.value = 3
    @Expect(received.value, Int64(507))
    @Expect(computes.value, Int64(4))
    observation.close()
    @Expect(source.listenerSlotCount(), Int64(0))
}

@Test
func failedDerivedObserverConnectionRollsBackEarlierSources(): Unit {
    let first = State<Int64>(1)
    let failing = FailingObservationSource()
    let total = derive(first, failing, {left, right => left + right})
    var didThrow = false

    try {
        let _ = total.observe({_, _ => ()})
    } catch (_: IllegalStateException) {
        didThrow = true
    }

    @Expect(didThrow)
    @Expect(first.listenerSlotCount(), Int64(0))
}

@Test
func unrelatedStateEpochChangeDoesNotRecomputeDerivedValue(): Unit {
    let source = State<Int64>(2)
    let unrelated = State<Int64>(0)
    let computes = ValueCell<Int64>(0)
    let doubled = source.map<Int64>({value =>
        computes.value += 1
        value * 2
    })

    @Expect(doubled.value, Int64(4))
    unrelated.value = 1
    @Expect(doubled.value, Int64(4))
    @Expect(computes.value, Int64(1))
}

@Test
func dynamicDerivedFusedSnapshotRechecksSourceWrittenDuringCompute(): Unit {
    let source = State<Int64>(0)
    let sources: Array<Observable<Int64>> = [source]
    let first = ValueCell<Bool>(true)
    let computes = ValueCell<Int64>(0)
    let derived = derive<Int64, Int64>(sources, {
        values =>
            computes.value += 1
            if (first.value) {
                first.value = false
                source.value = values[0] + 1
            }
            values[0]
    })

    @Expect(derived.value, Int64(0))
    @Expect(derived.value, Int64(1))
    @Expect(derived.value, Int64(1))
    @Expect(computes.value, Int64(2))
}

@Test
func dynamicDerivedFusedSnapshotRetriesInitialComputeFailure(): Unit {
    let source = State<Int64>(3)
    let sources: Array<Observable<Int64>> = [source]
    let attempts = ValueCell<Int64>(0)
    let derived = derive<Int64, Int64>(sources, {
        values =>
            attempts.value += 1
            if (attempts.value == 1) {
                throw IllegalStateException("expected fused snapshot failure")
            }
            values[0] * 2
    })

    var didThrow = false
    try {
        let _ = derived.value
    } catch (_: IllegalStateException) {
        didThrow = true
    }
    @Expect(didThrow)
    @Expect(derived.value, Int64(6))
    @Expect(attempts.value, Int64(2))
}

@Test
func dynamicDerivedFusedSnapshotIgnoresUnrelatedStateWrite(): Unit {
    let source = State<Int64>(4)
    let unrelated = State<Int64>(0)
    let sources: Array<Observable<Int64>> = [source]
    let computes = ValueCell<Int64>(0)
    let derived = derive<Int64, Int64>(sources, {
        values =>
            computes.value += 1
            values[0] * 2
    })

    @Expect(derived.value, Int64(8))
    unrelated.value = 1
    @Expect(derived.value, Int64(8))
    @Expect(computes.value, Int64(1))
}

@Test
func dynamicDerivedPreservesCustomObservableSamplingOrder(): Unit {
    let log = ValueCell<String>("")
    let sources: Array<Observable<Int64>> = [OrderedCustomObservable("a", 1, log),
        OrderedCustomObservable("b", 2, log)]
    let total = derive<Int64, Int64>(sources, {values => values[0] + values[1]})

    @Expect(total.value, Int64(3))
    @Expect(log.value, "ra;rb;ga;gb;")
}

@Test
func deriveStatesSnapshotsTopologyAndTracksWrites(): Unit {
    let first = State<Int64>(1)
    let replacement = State<Int64>(10)
    let sources = [first]
    let computes = ValueCell<Int64>(0)
    let derived = deriveStates<Int64, Int64>(sources, {
        values =>
            computes.value += 1
            values[0] * 2
    })

    @Expect(derived.value, Int64(2))
    sources[0] = replacement
    replacement.value = 20
    @Expect(derived.value, Int64(2))
    first.value = 3
    @Expect(derived.value, Int64(6))
    @Expect(computes.value, Int64(2))
}

@Test
func deriveStatesRechecksComputeSelfWrite(): Unit {
    let source = State<Int64>(0)
    let sources = [source]
    let first = ValueCell<Bool>(true)
    let derived = deriveStates<Int64, Int64>(sources, {
        values =>
            if (first.value) {
                first.value = false
                source.value = values[0] + 1
            }
            values[0]
    })

    @Expect(derived.value, Int64(0))
    @Expect(derived.value, Int64(1))
}

@Test
func emptyDynamicDerivedCallRemainsUnambiguous(): Unit {
    let derived = derive<Int64, Int64>([], {values => values.size})

    @Expect(derived.value, Int64(0))
}
