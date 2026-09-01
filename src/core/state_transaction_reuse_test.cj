package cui.core

private class TransactionReuseProbe {
    var log = ""
    var previousWasNone = false
    var current: ?Int64 = None

    func record(previous: Int64, current: Int64): Unit {
        log = log + "${previous}>${current};"
    }

    func recordOptional(previous: ?Int64, current: ?Int64): Unit {
        previousWasNone = previous.isNone()
        this.current = current
    }
}

@Test
func stateLazilyReusesOneTransactionNotificationSlot(): Unit {
    let scheduler = FrameScheduler()
    let state = State<Int64>(0)
    let observation = state.observe({_, _ => ()})
    @Expect(state.transactionNotificationSlot().isNone())

    withFrameScheduler(scheduler, {=> scheduler.transaction({=> state.value = 1})})
    let first = state.transactionNotificationSlot().getOrThrow()
    withFrameScheduler(scheduler, {=> scheduler.transaction({=> state.value = 2})})
    let second = state.transactionNotificationSlot().getOrThrow()

    @Expect(refEq((first as Object).getOrThrow(), (second as Object).getOrThrow())) // cjcheck-ignore: unchecked-cast # both values are the State-owned class slot
    observation.close()
}

@Test
func reentrantTransactionWriteRepreparesCopiedNotificationSlot(): Unit {
    let scheduler = FrameScheduler()
    let state = State<Int64>(0)
    let probe = TransactionReuseProbe()
    let observation = state.observe(
        {
            previous, current =>
                probe.record(previous, current)
                if (current == 1) {
                    state.value = 2
                }
        }
    )

    withFrameScheduler(scheduler, {=> scheduler.transaction({=> state.value = 1})})

    @Expect(state.value, Int64(2))
    @Expect(probe.log, "0>1;1>2;")
    observation.close()
}

@Test
func nullableStateReusableSlotPreservesPreviousValue(): Unit {
    let scheduler = FrameScheduler()
    let state = State<?Int64>(None)
    let probe = TransactionReuseProbe()
    let observation = state.observe({previous, current => probe.recordOptional(previous, current)})

    withFrameScheduler(scheduler, {=> scheduler.transaction({=> state.value = Some(Int64(7))})})

    @Expect(probe.previousWasNone)
    @Expect(probe.current.getOrThrow(), Int64(7))
    observation.close()
}
