package cui.core

import std.sync.{AtomicBool, SyncCounter}

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
