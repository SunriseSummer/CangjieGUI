/*
 * A/B guard for the explicit retained boundary. Both cases run through WidgetTestHost's complete
 * stable frame transaction over the same dense scene. The miss case advances revision every frame;
 * the hit case keeps it fixed, so the difference is the build/measure/layout work retained mode
 * removes. Headless drawing is intentionally still replayed, matching cachePaint: false.
 */
package bench_micro

import cui.{EffectCleanup, Rect, RetainedSubtree, Spacer, State, WidgetTestHost, lifecycleEffect, subscribeFrame}
import bench_scenes.contentScrollScene
import bench_harness.{printSection, report, timeit}

private class RevisionSequence {
    private var current: UInt64 = 0

    func next(): UInt64 {
        current += UInt64(1)
        current
    }
}

private class SubscriptionCounter {
    var calls: Int64 = 0

    func hit(): Unit {
        calls += 1
    }
}

private class EffectCounter {
    var setups: Int64 = 0
    var cleanups: Int64 = 0

    func setup(): Unit {
        setups += 1
    }

    func cleanup(): Unit {
        cleanups += 1
    }
}

public func runRetainedFrameBench(): Unit {
    printSection("保留子树（完整 headless 帧 A/B）")
    let rect = Rect(0.0, 0.0, 720.0, 640.0)
    let frames: Int64 = 80

    let retainedHost = WidgetTestHost()
    let retainedScroll = State<Float32>(0.0)
    let stableBody: () -> Unit = {
        => let _ = RetainedSubtree("bench.retained", UInt64(0)) {
            let _ = contentScrollScene(retainedScroll, 24)
        }
    }
    let _ = retainedHost.frame(rect, body: stableBody) // warm retained identity and caches
    report("frame", "保留子树", timeit("revision 命中", frames, {
        => Int64(retainedHost.frame(rect, body: stableBody).metrics.stabilizationPasses)
    }))

    let missHost = WidgetTestHost()
    let missScroll = State<Float32>(0.0)
    let revisions = RevisionSequence()
    report(
        "frame",
        "保留子树",
        timeit(
            "revision 每帧变化",
            frames,
            {
                =>
                    let revision = revisions.next()
                    let result = missHost.frame(rect, body: {
                        => let _ = RetainedSubtree("bench.retained", revision) {
                            let _ = contentScrollScene(missScroll, 24)
                        }
                    })
                    Int64(result.metrics.stabilizationPasses)
            }
        )
    )

    let batchHost = WidgetTestHost()
    let values = Array<State<Int64>>(32, {_ => State<Int64>(0)})
    report(
        "micro",
        "状态调度",
        timeit(
            "32 次写入事务合并",
            20000,
            {
                =>
                    batchHost.batch({
                        => for (value in values) {
                            value.value += 1
                        }
                    })
                    values[0].value
            }
        )
    )

    let largeBatchHost = WidgetTestHost()
    let largeBatchValues = Array<State<Int64>>(256, {_ => State<Int64>(0)})
    report(
        "micro",
        "状态调度",
        timeit(
            "256 次写入事务合并",
            2500,
            {
                =>
                    largeBatchHost.batch({
                        => for (value in largeBatchValues) {
                            value.value += 1
                        }
                    })
                    largeBatchValues[0].value
            }
        )
    )

    runFrameSubscriptionBench(rect)
    runLifecycleEffectBench(rect)
}

private func runFrameSubscriptionBench(rect: Rect): Unit {
    let frames: Int64 = 120
    let emptyHost = WidgetTestHost()
    let emptyBody: () -> Unit = {=> RetainedSubtree("bench.subscriptions.empty") {Spacer()}}
    let _ = emptyHost.frame(rect, body: emptyBody)
    report("frame", "Frame 订阅表", timeit("0 个订阅", frames, {
        => Int64(emptyHost.frame(rect, body: emptyBody).metrics.frameSubscribers)
    }))

    let subscriberCount: Int64 = 512
    let subscribedHost = WidgetTestHost()
    let counter = SubscriptionCounter()
    let subscribedBody: () -> Unit = {
        => RetainedSubtree("bench.subscriptions.dense") {
            var index: Int64 = 0
            while (index < subscriberCount) {
                subscribeFrame({_, _ => counter.hit()})
                index += 1
            }
            Spacer()
        }
    }
    let _ = subscribedHost.frame(rect, body: subscribedBody)
    report("frame", "Frame 订阅表", timeit("512 个显式订阅", frames, {
        => Int64(subscribedHost.frame(rect, body: subscribedBody).metrics.frameSubscribers) + counter.calls
    }))
}

private func runLifecycleEffectBench(rect: Rect): Unit {
    let effectCount: Int64 = 128
    let frames: Int64 = 80

    let stableHost = WidgetTestHost()
    let stableCounter = EffectCounter()
    let stableBody: () -> Unit = {=> buildEffects(effectCount, UInt64(0), stableCounter)}
    let _ = stableHost.frame(rect, body: stableBody)
    report("frame", "生命周期 effect", timeit("128 个稳定 effect", frames, {
        => Int64(stableHost.frame(rect, body: stableBody).metrics.stabilizationPasses) + stableCounter.setups
    }))

    let replaceHost = WidgetTestHost()
    let replaceCounter = EffectCounter()
    let revisions = RevisionSequence()
    let _ = replaceHost.frame(rect, body: {=> buildEffects(effectCount, UInt64(0), replaceCounter)})
    report(
        "frame",
        "生命周期 effect",
        timeit(
            "128 个每帧替换",
            frames,
            {
                =>
                    let revision = revisions.next()
                    let result = replaceHost.frame(rect, body: {=> buildEffects(effectCount, revision, replaceCounter)})
                    Int64(result.metrics.stabilizationPasses) + replaceCounter.setups + replaceCounter.cleanups
            }
        )
    )
    stableHost.reset()
    replaceHost.reset()
}

private func buildEffects(count: Int64, revision: UInt64, counter: EffectCounter): Unit {
    var index: Int64 = 0
    while (index < count) {
        lifecycleEffect(
            "bench.effect.${index}",
            revision,
            {
                =>
                    counter.setup()
                    EffectCleanup({=> counter.cleanup()})
            }
        )
        index += 1
    }
    Spacer()
}
