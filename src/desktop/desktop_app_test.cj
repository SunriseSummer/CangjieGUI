package cui.desktop

import std.collection.ArrayList
import cui.core.FrameSchedule

private class ManagedResourceProbe <: Resource {
    private let name: String
    private let order: ArrayList<String>
    private let fail: Bool
    private var closed = false

    init(name: String, order: ArrayList<String>, fail!: Bool = false) {
        this.name = name
        this.order = order
        this.fail = fail
    }

    /** Whether this cleanup probe has already been visited. */
    public func isClosed(): Bool {
        closed
    }

    /** Records reverse-order cleanup and optionally raises the configured probe failure. */
    public func close(): Unit {
        if (closed) {
            return
        }
        closed = true
        order.add(name)
        if (fail) {
            throw IllegalStateException("managed resource close probe")
        }
    }
}

@Test
func tickDeltaGuardsAgainstClockReset(): Unit {
    @Expect(tickDelta(UInt64(10), UInt64(25)), UInt64(15))
    @Expect(tickDelta(UInt64(25), UInt64(10)), UInt64(0))
}

@Test
func frameProfilerPercentileUsesNearestRank(): Unit {
    @Expect(percentileOfSorted([UInt64(10), UInt64(20), UInt64(30), UInt64(40)], 95), UInt64(40))
    @Expect(percentileOfSorted([], 95), UInt64(0))
    let samples = [UInt64(10), UInt64(20), UInt64(60), UInt64(80), UInt64(100)]
    @Expect(percentileOfSorted(samples, 50), UInt64(60))
    @Expect(percentileOfSorted(samples, 90), UInt64(100))
    @Expect(percentileOfSorted(samples, 99), UInt64(100))
}

@Test
func eventWaitTimeoutBoundsNativeBlockingAndHonorsEarlierDeadline(): Unit {
    @Expect(eventWaitTimeout(FrameSchedule(immediate: false, deadlineMs: None), UInt64(100)), Int32(250))
    @Expect(eventWaitTimeout(FrameSchedule(immediate: false, deadlineMs: Some(UInt64(1000))), UInt64(100)),
        Int32(250))
    @Expect(eventWaitTimeout(FrameSchedule(immediate: false, deadlineMs: Some(UInt64(120))), UInt64(100)),
        Int32(20))
    @Expect(eventWaitTimeout(FrameSchedule(immediate: false, deadlineMs: Some(UInt64(90))), UInt64(100)), Int32(0))
}

@Test
func unprofiledFramesSkipPerformanceClockReads(): Unit {
    @Expect(frameProfileTimestamp(None), UInt64(0))
}

@Test
func closeResourcesVisitsEveryEntryInReverseOrderBeforeRethrowing(): Unit {
    let order = ArrayList<String>()
    let first = ManagedResourceProbe("first", order)
    let failing = ManagedResourceProbe("failing", order, fail: true)
    let last = ManagedResourceProbe("last", order)
    let resources = ArrayList<Resource>()
    resources.add(first)
    resources.add(failing)
    resources.add(last)

    var cleanupFailed = false
    try {
        closeResourcesInReverse(resources)
    } catch (_: IllegalStateException) {
        cleanupFailed = true
    }

    @Expect(cleanupFailed)
    @Expect(order.toArray(), ["last", "failing", "first"])
    @Expect(first.isClosed())
    @Expect(failing.isClosed())
    @Expect(last.isClosed())
    @Expect(resources.isEmpty())
}
