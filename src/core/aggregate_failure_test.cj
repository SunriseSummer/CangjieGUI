package cui.core

import sdl.{UiEvent, UiEventRecord}

@Test
func aggregateRetainsOriginalObjectsAndDefendsItsFailureArray(): Unit {
    let first = IllegalArgumentException("original")
    let second = IllegalStateException("cleanup")
    let input: Array<Exception> = [first, second]
    let aggregate = UiAggregateException(input)
    input[0] = Exception("replaced")
    let output = aggregate.failures
    output[0] = Exception("replaced again")
    @Expect(refEq(aggregate.primary, first))
    @Expect(refEq(aggregate.failures[1], second))
    var rejected = false
    try { let _ = UiAggregateException([first]) }
    catch (_: IllegalArgumentException) { rejected = true }
    @Expect(rejected)
}

@Test
func transactionKeepsBodyAndAllNotificationFailures(): Unit {
    let scheduler = FrameScheduler()
    let bodyFailure = IllegalArgumentException("body")
    let firstFailure = IllegalStateException("first notification")
    let lastFailure = Exception("last notification")
    withFrameScheduler(scheduler, {=>
        let first = State<Int64>(0)
        let last = State<Int64>(0)
        let firstObserver = first.observe({_, _ => throw firstFailure})
        let lastObserver = last.observe({_, _ => throw lastFailure})
        var captured: ?UiAggregateException = None
        try {
            scheduler.transaction({=> first.value = 1; last.value = 1; throw bodyFailure})
        } catch (error: UiAggregateException) { captured = Some(error) }
        let failures = captured.getOrThrow().failures
        @Expect(failures.size, Int64(3))
        @Expect(refEq(failures[0], bodyFailure))
        @Expect(refEq(failures[1], firstFailure))
        @Expect(refEq(failures[2], lastFailure))
        firstObserver.close()
        lastObserver.close()
        scheduler.transaction({=> first.value = 2})
        @Expect(first.value, Int64(2))
    })
}

@Test
func eventCompletionFailureDoesNotHideTheHandlerFailure(): Unit {
    let ctx = testContext()
    let handler = IllegalArgumentException("handler")
    let completion = IllegalStateException("completion")
    var captured: ?UiAggregateException = None
    try {
        dispatchEventRecord(UiEventRecord(UiEvent.Quit), ctx, {_ => ()}, {_ => throw handler}, {_ => throw completion})
    } catch (error: UiAggregateException) { captured = Some(error) }
    @Expect(refEq(captured.getOrThrow().primary, handler))
    @Expect(refEq(captured.getOrThrow().failures[1], completion))
}

@Test
func failedEffectSetupAndRollbackKeepEachOriginalException(): Unit {
    let store = StateStore()
    let setup = IllegalArgumentException("setup")
    let cleanup = IllegalStateException("cleanup")
    let attempts = State<Int64>(0)
    var captured: ?UiAggregateException = None
    try {
        let _ = buildRoot({=>
            mountEffect("prepared", {=> EffectCleanup({=>
                attempts.value += 1
                if (attempts.value == 1) { throw cleanup }
            })})
            mountEffect("rejected", {=> throw setup})
            Spacer()
        }, store)
    } catch (error: UiAggregateException) { captured = Some(error) }
    @Expect(refEq(captured.getOrThrow().primary, setup))
    @Expect(refEq(captured.getOrThrow().failures[1], cleanup))
    store.clear()
    @Expect(attempts.value, Int64(2))
}

private class FallibleStatusResource <: Resource {
    var rejectStatus = false
    var closed = false
    /** Reports status, with an injectable failure to verify that sibling cleanup continues. */
    public func isClosed(): Bool {
        if (rejectStatus) { throw IllegalStateException("status unavailable") }
        closed
    }
    /** Completes cleanup after status queries have recovered. */
    public func close(): Unit { closed = true }
}

@Test
func failedResourceStatusDoesNotSkipSiblingCleanup(): Unit {
    let store = StateStore()
    let first = FallibleStatusResource()
    let last = FallibleStatusResource()
    let _ = buildRoot({=>
        mountEffect("first", {=> first})
        mountEffect("last", {=> last})
        Spacer()
    }, store)
    last.rejectStatus = true
    var rejected = false
    try { store.clear() } catch (_: IllegalStateException) { rejected = true }
    @Expect(rejected)
    @Expect(first.closed)
    last.rejectStatus = false
    store.clear()
    @Expect(last.closed)
}
