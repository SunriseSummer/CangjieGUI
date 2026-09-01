package cui.core

private class TransactionPolicyProbe {
    var notifications: Int64 = 0
    var previous: Int64 = -1
    var current: Int64 = -1
    var didThrow = false
    var comparisons: Int64 = 0

    func record(before: Int64, after: Int64): Unit {
        notifications += 1
        previous = before
        current = after
    }
}

@Test
func singleWritePolicyTransactionReusesSetterNonEquivalenceProof(): Unit {
    let scheduler = FrameScheduler()
    let probe = TransactionPolicyProbe()
    let policy = stateMutationPolicy<Int64>({previous, current =>
        probe.comparisons += 1
        previous == current
    })
    let value = State<Int64>(0, policy: policy)

    withFrameScheduler(scheduler, {=> scheduler.transaction({=> value.value = 1})})

    @Expect(value.value, Int64(1))
    @Expect(probe.comparisons, Int64(1))
}

@Test
func abortedFlushClearsQueuedPolicyComparisonMetadata(): Unit {
    let scheduler = FrameScheduler()
    let blocker = State<Int64>(0)
    let probe = TransactionPolicyProbe()
    let policy = stateMutationPolicy<Int64>({previous, current =>
        probe.comparisons += 1
        previous == current
    })
    let value = State<Int64>(0, policy: policy)
    let observation = blocker.observe({_, _ => throw IllegalStateException("expected observer failure")})

    withFrameScheduler(
        scheduler,
        {
            =>
                try {
                    scheduler.transaction(
                        {
                            =>
                                blocker.value = 1
                                value.value = 1
                        }
                    )
                } catch (_: IllegalStateException) {
                    probe.didThrow = true
                }
                scheduler.transaction({=> value.value = 2})
        }
    )

    @Expect(probe.didThrow)
    @Expect(value.value, Int64(2))
    @Expect(probe.comparisons, Int64(2))
    observation.close()
}

@Test
func structuralPolicyElidesNetZeroTransactionNotificationAndFrame(): Unit {
    let scheduler = FrameScheduler()
    let value = State<Int64>(0, policy: structuralEqualityPolicy<Int64>())
    let probe = TransactionPolicyProbe()
    let observation = value.observe({previous, current => probe.record(previous, current)})

    withFrameScheduler(
        scheduler,
        {
            =>
                let _ = value.value
                let before = scheduler.generation
                scheduler.transaction(
                    {
                        =>
                            value.value = 1
                            value.value = 0
                    }
                )
                @Expect(scheduler.generation, before)
        }
    )

    @Expect(value.value, Int64(0))
    @Expect(value.revision, UInt64(2))
    @Expect(probe.notifications, Int64(0))
    observation.close()
}

@Test
func interleavedPolicyWritesUseIndexedEndpointProofs(): Unit {
    let scheduler = FrameScheduler()
    let first = State<Int64>(0, policy: structuralEqualityPolicy<Int64>())
    let second = State<Int64>(0, policy: structuralEqualityPolicy<Int64>())
    let firstProbe = TransactionPolicyProbe()
    let secondProbe = TransactionPolicyProbe()
    let firstObservation = first.observe({previous, current => firstProbe.record(previous, current)})
    let secondObservation = second.observe({previous, current => secondProbe.record(previous, current)})

    withFrameScheduler(
        scheduler,
        {
            =>
                let before = scheduler.generation
                scheduler.transaction(
                    {
                        =>
                            first.value = 1
                            second.value = 1
                            first.value = 0
                            second.value = 0
                    }
                )
                @Expect(scheduler.generation, before)
        }
    )

    @Expect(firstProbe.notifications, Int64(0))
    @Expect(secondProbe.notifications, Int64(0))
    firstObservation.close()
    secondObservation.close()
}

@Test
func structuralPolicyCommitsOneNetTransactionChange(): Unit {
    let scheduler = FrameScheduler()
    let value = State<Int64>(0, policy: structuralEqualityPolicy<Int64>())
    let probe = TransactionPolicyProbe()
    let observation = value.observe({previous, current => probe.record(previous, current)})

    withFrameScheduler(
        scheduler,
        {
            =>
                let _ = value.value
                let before = scheduler.generation
                scheduler.transaction(
                    {
                        =>
                            value.value = 1
                            value.value = 2
                    }
                )
                @Expect(scheduler.generation, before + UInt64(1))
        }
    )

    @Expect(value.value, Int64(2))
    @Expect(value.revision, UInt64(2))
    @Expect(probe.notifications, Int64(1))
    @Expect(probe.previous, Int64(0))
    @Expect(probe.current, Int64(2))
    observation.close()
}

@Test
func defaultPolicyPreservesEventStyleNetZeroTransaction(): Unit {
    let scheduler = FrameScheduler()
    let value = State<Int64>(0)
    let probe = TransactionPolicyProbe()
    let observation = value.observe({previous, current => probe.record(previous, current)})

    withFrameScheduler(
        scheduler,
        {
            =>
                let _ = value.value
                let before = scheduler.generation
                scheduler.transaction(
                    {
                        =>
                            value.value = 1
                            value.value = 0
                    }
                )
                @Expect(scheduler.generation, before + UInt64(1))
        }
    )

    @Expect(probe.notifications, Int64(1))
    @Expect(probe.previous, Int64(0))
    @Expect(probe.current, Int64(0))
    observation.close()
}

@Test
func transactionPolicyFailureConservativelyInvalidatesCommittedWrites(): Unit {
    let scheduler = FrameScheduler()
    let policy = stateMutationPolicy<Int64>({previous, current =>
        if (previous == current) {
            throw IllegalStateException("expected transaction policy failure")
        }
        false
    })
    let value = State<Int64>(0, policy: policy)
    let probe = TransactionPolicyProbe()

    withFrameScheduler(
        scheduler,
        {
            =>
                let _ = value.value
                let before = scheduler.generation
                try {
                    scheduler.transaction(
                        {
                            =>
                                value.value = 1
                                value.value = 0
                        }
                    )
                } catch (_: IllegalStateException) {
                    probe.didThrow = true
                }
                @Expect(scheduler.generation, before + UInt64(1))
                scheduler.transaction({=> value.value = 2})
                @Expect(scheduler.generation, before + UInt64(2))
        }
    )

    @Expect(probe.didThrow)
    @Expect(value.value, Int64(2))
    @Expect(value.revision, UInt64(3))
}
