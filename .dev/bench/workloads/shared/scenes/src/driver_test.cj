package bench_scenes

import bench_harness.{frameDistribution, sampleFrames}
import cui.{Rect, Spacer, WidgetTestHost}

@Test
func frameDistributionUsesNearestRankAndCountsBudgetMisses(): Unit {
    let samples = [UInt64(1000000), UInt64(9000000), UInt64(17000000), UInt64(34000000), UInt64(50000000)]
    let distribution = frameDistribution(samples)
    @Expect(distribution.samples, Int64(5))
    @Expect(distribution.p50Ns, UInt64(17000000))
    @Expect(distribution.p90Ns, UInt64(50000000))
    @Expect(distribution.p95Ns, UInt64(50000000))
    @Expect(distribution.p99Ns, UInt64(50000000))
    @Expect(distribution.maxNs, UInt64(50000000))
    @Expect(distribution.over120FpsBudget, Int64(4))
    @Expect(distribution.over60FpsBudget, Int64(3))
    @Expect(distribution.over30FpsBudget, Int64(2))
    @Expect(samples[0], UInt64(1000000))
}

@Test
func sampledFramesPreserveIterationsChecksumAndDistribution(): Unit {
    let sampled = sampleFrames("sampled", 3, {=> Int64(7)})
    @Expect(sampled.result.iterations, Int64(3))
    @Expect(sampled.result.checksum, Int64(21))
    @Expect(sampled.distribution.samples, Int64(3))
    @Expect(sampled.distribution.p50Ns <= sampled.distribution.p95Ns)
    @Expect(sampled.distribution.p95Ns <= sampled.distribution.maxNs)
}

@Test
func benchDriverAdvancesThroughExplicitFrameSubscription(): Unit {
    let host = WidgetTestHost()
    let accumulator = BenchAccumulator(group: "test", name: "subscription", warmup: 0, frames: 1)
    let body: () -> Unit = {
        =>
            BenchDriver(accumulator)
            Spacer()
    }

    let first = host.frame(Rect(0.0, 0.0, 100.0, 60.0), body: body)
    @Expect(first.metrics.frameSubscribers, Int64(1))
    @Expect(first.schedule.immediate)
    @Expect(!host.context.shouldClose)

    let second = host.frame(Rect(0.0, 0.0, 100.0, 60.0), body: body)
    @Expect(second.metrics.frameSubscribers, Int64(1))
    @Expect(host.context.shouldClose)
}
