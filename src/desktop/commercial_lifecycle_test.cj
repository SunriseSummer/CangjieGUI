package cui.desktop

import std.collection.ArrayList
import cui.core.State

@Test
func closeDecisionDeduplicatesPendingRequestsAndCancellationAllowsRetry(): Unit {
    let coordinator = CloseCoordinator()
    let requests = ArrayList<CloseRequest>()
    let accepted = State<Int64>(0)
    coordinator.setHandler({request => requests.add(request)})
    coordinator.request({=> ()}, {=> accepted.value += 1})
    coordinator.request({=> ()}, {=> accepted.value += 1})
    @Expect(requests.size, 1)
    requests[0].cancel()
    coordinator.request({=> ()}, {=> accepted.value += 1})
    @Expect(requests.size, 2)
    requests[1].accept()
    requests[1].accept()
    @Expect(accepted.value, 1)
    @Expect(!requests[1].isPending())
}

@Test
func closeDecisionIsInvalidatedOnShutdownOrHandlerFailure(): Unit {
    let coordinator = CloseCoordinator()
    let requests = ArrayList<CloseRequest>()
    let accepted = State<Bool>(false)
    coordinator.setHandler({request => requests.add(request)})
    coordinator.request({=> ()}, {=> accepted.value = true})
    coordinator.stop()
    requests[0].accept()
    @Expect(!accepted.value)
    coordinator.setHandler({_ => throw IllegalStateException("confirmation failed")})
    var failed = false
    try { coordinator.request({=> ()}, {=> accepted.value = true}) }
    catch (_: IllegalStateException) { failed = true }
    @Expect(failed)
    coordinator.setHandler(None)
    coordinator.request({=> ()}, {=> accepted.value = true})
    @Expect(accepted.value)
}

@Test
func postQueueBoundsAdmissionAndPreservesFifoAcrossBatches(): Unit {
    let queue = DesktopPostQueue(2)
    let calls = ArrayList<Int64>()
    let (first, wakeFirst) = queue.add({=> calls.add(1)})
    let (second, wakeSecond) = queue.add({=> calls.add(2)})
    let (third, wakeThird) = queue.add({=> calls.add(3)})
    @Expect(first && wakeFirst)
    @Expect(second && !wakeSecond)
    @Expect(!third && !wakeThird)
    @Expect(queue.drain(1))
    @Expect(calls.toArray(), [1])
    @Expect(!queue.drain(1))
    @Expect(calls.toArray(), [1, 2])
    @Expect(queue.stats().highWatermark, 2)
    @Expect(queue.stats().rejected, UInt64(1))
    queue.stop()
    let (afterStop, _) = queue.add({=> calls.add(4)})
    @Expect(!afterStop)
}

@Test
func postQueueDoesNotLoseOrReplayActionsWhenOneThrows(): Unit {
    let queue = DesktopPostQueue(3)
    let calls = State<Int64>(0)
    let _ = queue.add({=> throw IllegalStateException("posted action failed")})
    let _ = queue.add({=> calls.value += 1})
    var failed = false
    try { let _ = queue.drain(2) } catch (_: IllegalStateException) { failed = true }
    @Expect(failed)
    @Expect(queue.stats().pending, 1)
    @Expect(!queue.drain(2))
    @Expect(calls.value, 1)
}
