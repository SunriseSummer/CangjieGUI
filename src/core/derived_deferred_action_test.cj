package cui.core

private class DeferredActionProbe {
    var dispatches: Int64 = 0
    var log = ""

    func dispatch(): Unit {
        dispatches += 1
    }

    func record(previous: Int64, current: Int64): Unit {
        log = log + "${previous}>${current};"
    }
}

@Test
func deferredObserverActionCanBeReusedAcrossTransactions(): Unit {
    let scheduler = FrameScheduler()
    let probe = DeferredActionProbe()
    let action = DeferredStateObserverAction(UInt64(41), {=> probe.dispatch()})

    withFrameScheduler(
        scheduler,
        {
            =>
                scheduler.transaction(
                    {
                        =>
                            @Expect(scheduler.deferStateObserver(action))
                            @Expect(scheduler.deferStateObserver(action))
                    }
                )
                scheduler.transaction({=> @Expect(scheduler.deferStateObserver(action))})
        }
    )

    @Expect(probe.dispatches, Int64(2))
}

@Test
func reentrantDerivedObserverRequeuesSameDeferredAction(): Unit {
    let scheduler = FrameScheduler()
    let source = State<Int64>(0)
    let derived = derive(source, {value => value})
    let probe = DeferredActionProbe()
    let observation = derived.observe(
        {
            previous, current =>
                probe.record(previous, current)
                if (current == 1) {
                    source.value = 2
                }
        }
    )

    withFrameScheduler(scheduler, {=> scheduler.transaction({=> source.value = 1})})

    @Expect(source.value, Int64(2))
    @Expect(probe.log, "0>1;1>2;")
    observation.close()
}
