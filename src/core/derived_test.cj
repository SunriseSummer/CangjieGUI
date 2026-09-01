package cui.core

struct TestProfile {
    let name: String
    let subscribed: Bool

    init(name: String, subscribed: Bool) {
        this.name = name
        this.subscribed = subscribed
    }
}

struct TestAccount {
    let profile: TestProfile
    let active: Bool

    init(profile: TestProfile, active: Bool) {
        this.profile = profile
        this.active = active
    }
}

private class DerivedFailureProbe {
    var calls: Int64 = 0

    func compute(value: Int64): Int64 {
        calls += 1
        if (value == 2) {
            throw IllegalStateException("expected derived failure")
        }
        value * 2
    }
}

private class ManualObservable <: Observable<Int64> {
    private var stored: Int64
    private var manualRevision: UInt64 = UInt64(0)
    private var callback: ?((Int64, Int64) -> Unit) = None

    init(value: Int64) {
        this.stored = value
    }

    public func get(): Int64 {
        stored
    }

    public prop revision: UInt64 {
        get() {
            manualRevision
        }
    }

    public func observe(callback: (Int64, Int64) -> Unit): StateObservation<Int64> {
        this.callback = Some(callback)
        StateObservation<Int64>({=> this.callback = None})
    }

    func replace(value: Int64): Unit {
        let previous = stored
        stored = value
        manualRevision = nextRevision(manualRevision)
        match (callback) {
            case Some(notify) => notify(previous, value)
            case None => ()
        }
    }
}

@Test
func deriveOverArrayOfSourcesTracksEvery(): Unit {
    let a = State<Int64>(1)
    let b = State<Int64>(2)
    let c = State<Int64>(3)
    let sources: Array<Observable<Int64>> = [a, b, c]
    let total = derive<Int64, Int64>(
        sources,
        {
            values =>
                var sum = 0
                for (v in values) {
                    sum += v
                }
                sum
        }
    )
    @Expect(total.value, Int64(6))
    // Recomputes when ANY source changes — including the 3rd, past the fixed-arity overloads' reach
    // when combined with more.
    b.value = 20
    @Expect(total.value, Int64(24))
    c.value = 30
    @Expect(total.value, Int64(51))
}

@Test
func derivedStateCachesUntilSourceChanges(): Unit {
    let count = State<Int64>(2)
    let calls = State<Int64>(0)
    let doubled = count.map<Int64>(
        {
            value =>
                calls.value += 1
                value * 2
        }
    )

    @Expect(doubled.value, Int64(4))
    @Expect(doubled.value, Int64(4))
    @Expect(calls.value, Int64(1))

    count.value = 5
    @Expect(doubled.value, Int64(10))
    @Expect(calls.value, Int64(2))
}

@Test
func derivedStateCombinesSeveralSources(): Unit {
    let quantity = State<Int64>(2)
    let unitPrice = State<Int64>(30)
    let total = derive(quantity, unitPrice, {q, p => q * p})

    @Expect(total.value, Int64(60))

    unitPrice.value = 40
    @Expect(total.value, Int64(80))

    let beforeRevision = total.revision
    quantity.value = 3
    @Expect(total.value, Int64(120))
    @Expect(total.revision != beforeRevision)
}

@Test
func derivedStateDoesNotCommitSourceRevisionWhenComputeThrows(): Unit {
    let source = State<Int64>(1)
    let probe = DerivedFailureProbe()
    let doubled = derive<Int64, Int64>(source, {value => probe.compute(value)})

    @Expect(doubled.value, Int64(2))
    source.value = 2

    var firstFailure = false
    try {
        let _ = doubled.value
    } catch (_: IllegalStateException) {
        firstFailure = true
    }
    var secondFailure = false
    try {
        let _ = doubled.value
    } catch (_: IllegalStateException) {
        secondFailure = true
    }
    @Expect(firstFailure)
    @Expect(secondFailure)
    @Expect(probe.calls, Int64(3))

    source.value = 3
    @Expect(doubled.value, Int64(6))
    @Expect(probe.calls, Int64(4))
}

@Test
func derivedStateRechecksSourceChangedDuringCompute(): Unit {
    let source = State<Int64>(0)
    let first = ValueCell<Bool>(true)
    let calls = ValueCell<Int64>(0)
    let derived = derive<Int64, Int64>(
        source,
        {
            value =>
                calls.value += 1
                if (first.value) {
                    first.value = false
                    source.value = value + 1
                }
                value
        }
    )

    @Expect(derived.value, Int64(0))
    @Expect(derived.value, Int64(1))
    @Expect(derived.value, Int64(1))
    @Expect(calls.value, Int64(2))
}

@Test
func derivedStateScansCustomObservableWithoutStateWriteEpoch(): Unit {
    let source = ManualObservable(2)
    let doubled = derive<Int64, Int64>(source, {value => value * 2})

    @Expect(doubled.value, Int64(4))
    source.replace(5)
    @Expect(doubled.value, Int64(10))
}

@Test
func derivedStateWriteEpochPropagatesThroughDerivedAndBinding(): Unit {
    let profile = State<TestProfile>(TestProfile("林", true))
    let name = profile.project<String>(get: {value => value.name},
        set: {value, next => TestProfile(next, value.subscribed)})
    let length = name.map<Int64>({value => value.size})
    let summary = length.map<String>({value => "${value}"})

    @Expect(summary.value, "3")
    name.value = "陈明"
    @Expect(summary.value, "6")
}

@Test
func derivedCacheHitReenrollsUpstreamStateInActiveDependencyCollector(): Unit {
    let source = State<Int64>(1)
    let doubled = source.map<Int64>({value => value * 2})
    let invalidations = ValueCell<Int64>(0)
    let dependencies = PhaseStateDependencies({=> invalidations.value += 1})

    let first = collectPhaseStateReads<Int64>(dependencies, {=> doubled.value})
    let second = collectPhaseStateReads<Int64>(dependencies, {=> doubled.value})
    @Expect(first, Int64(2))
    @Expect(second, Int64(2))

    source.value = 2
    @Expect(invalidations.value, Int64(1))
    dependencies.close()
}

@Test
func dynamicDerivedSnapshotsItsSourceTopologyAtCreation(): Unit {
    let first = State<Int64>(1)
    let replacement = State<Int64>(10)
    let sources: Array<Observable<Int64>> = [first]
    let derived = derive<Int64, Int64>(sources, {values => values[0]})

    @Expect(derived.value, Int64(1))
    sources[0] = replacement
    replacement.value = 20
    @Expect(derived.value, Int64(1))

    first.value = 3
    @Expect(derived.value, Int64(3))
}

@Test
func derivedCollectorUsesCustomObservablePushInvalidation(): Unit {
    let source = ManualObservable(4)
    let doubled = source.map<Int64>({value => value * 2})
    let invalidations = ValueCell<Int64>(0)
    let dependencies = PhaseStateDependencies({=> invalidations.value += 1})

    @Expect(collectPhaseStateReads<Int64>(dependencies, {=> doubled.value}), Int64(8))
    @Expect(dependencies.size, Int64(1))
    source.replace(5)
    @Expect(invalidations.value, Int64(1))
    @Expect(doubled.value, Int64(10))
    dependencies.close()
}

@Test
func derivedStateObserverFollowsSourceAssignments(): Unit {
    let count = State<Int64>(1)
    let doubled = count.map<Int64>({value => value * 2})
    let received = State<Int64>(0)
    let observation = doubled.observe({previous, current => received.value = previous * 100 + current})

    count.value = 3
    @Expect(received.value, Int64(206))

    observation.close()
    count.value = 4
    @Expect(received.value, Int64(206))
    @Expect(observation.isClosed())
}

@Test
func derivedObserverSeesOneGlitchFreeValueForTransaction(): Unit {
    let scheduler = FrameScheduler()
    let first = State<Int64>(1)
    let second = State<Int64>(2)
    let total = derive(first, second, {left, right => left + right})
    let notifications = State<Int64>(0)
    let previousValue = State<Int64>(-1)
    let currentValue = State<Int64>(-1)
    let observation = total.observe(
        {
            previous, current =>
                notifications.value += 1
                previousValue.value = previous
                currentValue.value = current
        }
    )

    withFrameScheduler(
        scheduler,
        {
            => scheduler.transaction(
                {
                    =>
                        first.value = 10
                        second.value = 20
                }
            )
        }
    )

    @Expect(notifications.value, Int64(1))
    @Expect(previousValue.value, Int64(3))
    @Expect(currentValue.value, Int64(30))
    observation.close()
}

@Test
func bindingProjectsOneComponentBothWays(): Unit {
    let profile = State<TestProfile>(TestProfile("林", true))
    let name = profile.project<String>(get: {p => p.name}, set: {p, next => TestProfile(next, p.subscribed)})

    @Expect(name.value, "林")

    name.value = "陈"
    @Expect(profile.value.name, "陈")
    @Expect(profile.value.subscribed)

    let received = State<String>("")
    let observation = name.observe({_, current => received.value = current})
    profile.value = TestProfile("赵", false)
    @Expect(received.value, "赵")
    observation.close()
}

@Test
func setIfChangedSkipsEqualAssignments(): Unit {
    let value = State<Int64>(1)
    let notifications = State<Int64>(0)
    let observation = value.observe({_, _ => notifications.value += 1})

    @Expect(!value.setIfChanged(1))
    @Expect(notifications.value, Int64(0))

    @Expect(value.setIfChanged(2))
    @Expect(value.value, Int64(2))
    @Expect(notifications.value, Int64(1))
    observation.close()
}

@Test
func structuralMutationPolicySkipsEquivalentAssignments(): Unit {
    let value = State<Int64>(1, policy: structuralEqualityPolicy<Int64>())
    let notifications = State<Int64>(0)
    let observation = value.observe({_, _ => notifications.value += 1})

    value.value = 1
    @Expect(value.revision, UInt64(0))
    @Expect(notifications.value, Int64(0))

    value.value = 2
    @Expect(value.revision, UInt64(1))
    @Expect(notifications.value, Int64(1))
    observation.close()
}
