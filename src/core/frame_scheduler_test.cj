package cui.core

import std.sync.{AtomicBool, SyncCounter}

private class SchedulerTransferProbe {
    var rejected = false
}

private class SchedulerNestedTransactionProbe {
    var notifications: Int64 = 0
    var current: Int64 = -1

    func record(value: Int64): Unit {
        notifications += 1
        current = value
    }
}

@Test
func frameSchedulerCoalescesNestedTransactions(): Unit {
    let scheduler = FrameScheduler()
    let state = State<Int64>(0)
    withFrameScheduler(
        scheduler,
        {
            =>
                let _ = state.value // bind the state to this application
                let before = scheduler.generation
                scheduler.transaction(
                    {
                        =>
                            state.value = 1
                            scheduler.transaction({=> state.value = 2})
                            state.value = 3
                    }
                )
                @Expect(scheduler.generation, before + UInt64(1))
        }
    )
    @Expect(state.value, Int64(3))
}

@Test
func frameSchedulerDefersAndCoalescesStateNotifications(): Unit {
    let scheduler = FrameScheduler()
    let state = State<Int64>(0)
    let notifications = State<Int64>(0)
    let previousValue = State<Int64>(-1)
    let currentValue = State<Int64>(-1)
    let observation = state.observe(
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
            =>
                scheduler.transaction(
                    {
                        =>
                            state.value = 1
                            state.value = 2
                            @Expect(notifications.value, Int64(0))
                    }
                )
        }
    )

    @Expect(notifications.value, Int64(1))
    @Expect(previousValue.value, Int64(0))
    @Expect(currentValue.value, Int64(2))
    observation.close()
}

@Test
func frameSchedulerFlushesObserverWritesBeforeDerivedEffects(): Unit {
    let scheduler = FrameScheduler()
    let source = State<Int64>(0)
    let reflected = State<Int64>(0)
    let total = derive(source, reflected, {left, right => left + right})
    let observed = State<Int64>(-1)
    let sourceObservation = source.observe({_, current => reflected.value = current * 10})
    let totalObservation = total.observe({_, current => observed.value = current})

    withFrameScheduler(scheduler, {=> scheduler.transaction({=> source.value = 3})})

    @Expect(reflected.value, Int64(30))
    @Expect(observed.value, Int64(33))
    sourceObservation.close()
    totalObservation.close()
}

@Test
func frameSchedulerCommitsDirtyTransactionWhenBodyThrows(): Unit {
    let scheduler = FrameScheduler()
    let state = State<Int64>(0)
    withFrameScheduler(
        scheduler,
        {
            =>
                let _ = state.value
                let before = scheduler.generation
                let caught = dirtyTransactionThrows(scheduler, state)
                @Expect(scheduler.generation, before + UInt64(1))
                @Expect(caught)
        }
    )
}

private func dirtyTransactionThrows(scheduler: FrameScheduler, state: State<Int64>): Bool {
    try {
        scheduler.transaction(
            {
                =>
                    state.value = 1
                    throw IllegalArgumentException("probe")
            }
        )
        false
    } catch (_: IllegalArgumentException) {
        true
    }
}

@Test
func boundStateRejectsBackgroundThreadWrites(): Unit {
    let scheduler = FrameScheduler()
    let state = State<Int64>(0)
    withFrameScheduler(scheduler, {=> let _ = state.value})

    let worker = spawn {
        => try {
            state.value = 1
            false
        } catch (_: IllegalStateException) {
            true
        }
    }

    @Expect(worker.get())
    @Expect(state.value, Int64(0))
}

@Test
func boundStateRejectsBackgroundUpdateBeforeRunningTransform(): Unit {
    let scheduler = FrameScheduler()
    let state = State<Int64>(0)
    let transformed = AtomicBool(false)
    withFrameScheduler(scheduler, {=> let _ = state.value})

    let worker = spawn {
        => try {
            state.update(
                {
                    value =>
                        transformed.store(true)
                        value + 1
                }
            )
            false
        } catch (_: IllegalStateException) {
            true
        }
    }

    @Expect(worker.get())
    @Expect(!transformed.load())
    @Expect(state.value, Int64(0))
}

@Test
func boundStateRejectsBackgroundObservationChanges(): Unit {
    let scheduler = FrameScheduler()
    let state = State<Int64>(0)
    let callbackCount = State<Int64>(0)
    withFrameScheduler(
        scheduler,
        {
            =>
                let _ = state.value
                let _ = callbackCount.value
        }
    )
    let observation = state.observe({_, _ => callbackCount.value += 1})

    let registerWorker = spawn {
        => try {
            let extra = state.observe({_, _ => ()})
            extra.close()
            false
        } catch (_: IllegalStateException) {
            true
        }
    }
    let closeWorker = spawn {
        => try {
            observation.close()
            false
        } catch (_: IllegalStateException) {
            true
        }
    }

    @Expect(registerWorker.get())
    @Expect(closeWorker.get())
    @Expect(!observation.isClosed())
    state.value = 1
    @Expect(callbackCount.value, Int64(1))
    observation.close()
    @Expect(observation.isClosed())
}

@Test
func frameSchedulerClaimsExactlyOneConcurrentOwner(): Unit {
    let scheduler = FrameScheduler()
    let ready = SyncCounter(2)
    let start = SyncCounter(1)
    let first = spawn {
        =>
            ready.dec()
            start.waitUntilZero()
            try {
                withFrameScheduler(scheduler, {=> ()})
                true
            } catch (_: IllegalStateException) {
                false
            }
    }
    let second = spawn {
        =>
            ready.dec()
            start.waitUntilZero()
            try {
                withFrameScheduler(scheduler, {=> ()})
                true
            } catch (_: IllegalStateException) {
                false
            }
    }

    ready.waitUntilZero()
    start.dec()
    @Expect(first.get() != second.get())
}

@Test
func stateTransfersInvalidationToSequentialAppOnTheSameThread(): Unit {
    let first = FrameScheduler()
    let second = FrameScheduler()
    let state = State<Int64>(0)
    withFrameScheduler(first, {=> let _ = state.value})
    let firstBefore = first.generation
    withFrameScheduler(
        second,
        {
            =>
                state.value = 1
        }
    )

    @Expect(first.generation, firstBefore)
    @Expect(second.generation, UInt64(1))
}

@Test
func stateRejectsTransferWhilePreviousSchedulerTransactionIsActive(): Unit {
    let first = FrameScheduler()
    let second = FrameScheduler()
    let state = State<Int64>(0)
    let probe = SchedulerTransferProbe()

    withFrameScheduler(
        first,
        {
            =>
                let _ = state.value
                first.transaction(
                    {
                        => try {
                            withFrameScheduler(second, {=> state.value = 1})
                        } catch (_: IllegalStateException) {
                            probe.rejected = true
                        }
                    }
                )
        }
    )

    @Expect(probe.rejected)
    @Expect(state.value, Int64(0))
    @Expect(first.generation, UInt64(0))
    @Expect(second.generation, UInt64(0))
}

@Test
func observerNestedTransactionJoinsOuterSettlement(): Unit {
    let scheduler = FrameScheduler()
    let source = State<Int64>(0)
    let reflected = State<Int64>(0)
    let probe = SchedulerNestedTransactionProbe()
    let sourceObservation = source.observe(
        {_, current => scheduler.transaction({=> reflected.value = current * 10})}
    )
    let reflectedObservation = reflected.observe({_, current => probe.record(current)})

    withFrameScheduler(
        scheduler,
        {
            =>
                let before = scheduler.generation
                scheduler.transaction({=> source.value = 3})
                @Expect(scheduler.generation, before + UInt64(1))
        }
    )

    @Expect(reflected.value, Int64(30))
    @Expect(probe.notifications, Int64(1))
    @Expect(probe.current, Int64(30))
    sourceObservation.close()
    reflectedObservation.close()
}
