package cui.core

private class TransactionFailureDeliveryProbe {
    var didThrow = false
    var message = ""
    var notifications: Int64 = 0
    var previous: Int64 = -1
    var current: Int64 = -1

    func record(before: Int64, after: Int64): Unit {
        notifications += 1
        previous = before
        current = after
    }

    func recordFailure(error: Exception): Unit {
        didThrow = true
        message = error.message
    }
}

@Test
func transactionObserverFailureDoesNotStarveLaterStateSource(): Unit {
    let scheduler = FrameScheduler()
    let failing = State<Int64>(0)
    let succeeding = State<Int64>(0)
    let probe = TransactionFailureDeliveryProbe()
    let failingObservation = failing.observe({_, _ => throw IllegalStateException("first source failed")})
    let succeedingObservation = succeeding.observe({previous, current => probe.record(previous, current)})

    withFrameScheduler(
        scheduler,
        {
            => try {
                scheduler.transaction(
                    {
                        =>
                            failing.value = 1
                            succeeding.value = 2
                    }
                )
            } catch (error: IllegalStateException) {
                probe.recordFailure(error)
            }
        }
    )

    @Expect(probe.didThrow)
    @Expect(probe.message, "first source failed")
    @Expect(probe.notifications, Int64(1))
    @Expect(probe.previous, Int64(0))
    @Expect(probe.current, Int64(2))
    failingObservation.close()
    succeedingObservation.close()
}

@Test
func failingObserverWriteStillSettlesNewlyQueuedState(): Unit {
    let scheduler = FrameScheduler()
    let source = State<Int64>(0)
    let reflected = State<Int64>(0)
    let probe = TransactionFailureDeliveryProbe()
    let sourceObservation = source.observe(
        {
            _, current =>
                reflected.value = current * 10
                throw IllegalStateException("observer failed after write")
        }
    )
    let reflectedObservation = reflected.observe({previous, current => probe.record(previous, current)})

    withFrameScheduler(
        scheduler,
        {
            => try {
                scheduler.transaction({=> source.value = 3})
            } catch (error: IllegalStateException) {
                probe.recordFailure(error)
            }
        }
    )

    @Expect(probe.didThrow)
    @Expect(probe.message, "observer failed after write")
    @Expect(reflected.value, Int64(30))
    @Expect(probe.notifications, Int64(1))
    sourceObservation.close()
    reflectedObservation.close()
}

@Test
func deferredDerivedFailureDoesNotStarveLaterDerivedObserver(): Unit {
    let scheduler = FrameScheduler()
    let firstSource = State<Int64>(0)
    let secondSource = State<Int64>(0)
    let first = derive(firstSource, {value => value * 10})
    let second = derive(secondSource, {value => value * 10})
    let probe = TransactionFailureDeliveryProbe()
    let firstObservation = first.observe({_, _ => throw IllegalStateException("first derived failed")})
    let secondObservation = second.observe({previous, current => probe.record(previous, current)})

    withFrameScheduler(
        scheduler,
        {
            => try {
                scheduler.transaction(
                    {
                        =>
                            firstSource.value = 1
                            secondSource.value = 2
                    }
                )
            } catch (error: IllegalStateException) {
                probe.recordFailure(error)
            }
        }
    )

    @Expect(probe.didThrow)
    @Expect(probe.message, "first derived failed")
    @Expect(probe.notifications, Int64(1))
    @Expect(probe.previous, Int64(0))
    @Expect(probe.current, Int64(20))
    firstObservation.close()
    secondObservation.close()
}

@Test
func transactionReportsFirstFailureAfterDrainingLaterFailures(): Unit {
    let scheduler = FrameScheduler()
    let first = State<Int64>(0)
    let second = State<Int64>(0)
    let tail = State<Int64>(0)
    let probe = TransactionFailureDeliveryProbe()
    let firstObservation = first.observe({_, _ => throw IllegalStateException("first failure")})
    let secondObservation = second.observe({_, _ => throw IllegalStateException("second failure")})
    let tailObservation = tail.observe({previous, current => probe.record(previous, current)})

    withFrameScheduler(
        scheduler,
        {
            => try {
                scheduler.transaction(
                    {
                        =>
                            first.value = 1
                            second.value = 1
                            tail.value = 1
                    }
                )
            } catch (error: IllegalStateException) {
                probe.recordFailure(error)
            }
        }
    )

    @Expect(probe.didThrow)
    @Expect(probe.message, "first failure")
    @Expect(probe.notifications, Int64(1))
    firstObservation.close()
    secondObservation.close()
    tailObservation.close()
}
