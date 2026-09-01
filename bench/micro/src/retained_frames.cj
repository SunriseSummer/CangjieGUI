/*
 * A/B guard for the explicit retained boundary. Both cases run through WidgetTestHost's complete
 * stable frame transaction over the same dense scene. The miss case advances revision every frame;
 * the hit case keeps it fixed, so the difference is the build/measure/layout work retained mode
 * removes. Headless drawing is intentionally still replayed, matching cachePaint: false.
 */
package bench_micro

import std.collection.ArrayList
import cui.{EffectCleanup, Rect, RetainedSubtree, Spacer, State, StateObservation, WidgetTestHost, lifecycleEffect,
    stateMutationPolicy, structuralEqualityPolicy, subscribeFrame}
import bench_scenes.contentScrollScene
import bench_harness.{printSection, report, reportCount, timeit}

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

private class TransactionFailureCounter {
    var callbacks: Int64 = 0
    var failures: Int64 = 0

    func callback(): Unit {
        callbacks += 1
    }

    func failed(): Unit {
        failures += 1
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
    reportRetainedHit()
    reportRetainedMiss()
    let rect = Rect(0.0, 0.0, 720.0, 640.0)
    runFrameSubscriptionBench(rect)
    runLifecycleEffectBench(rect)
}

/** Runs only the stable retained hit in a fresh process for low-noise regression sampling. */
public func runRetainedHitBench(): Unit {
    printSection("保留子树（revision 命中）")
    reportRetainedHit()
}

/** Runs only the revision-changing retained miss in a fresh process for low-noise regression sampling. */
public func runRetainedMissBench(): Unit {
    printSection("保留子树（revision 每帧变化）")
    reportRetainedMiss()
}

private func reportRetainedHit(): Unit {
    let rect = Rect(0.0, 0.0, 720.0, 640.0)
    let hitFrames: Int64 = 1600
    let retainedHost = WidgetTestHost()
    let retainedScroll = State<Float32>(0.0)
    let stableBody: () -> Unit = {
        => let _ = RetainedSubtree("bench.retained", UInt64(0)) {
            let _ = contentScrollScene(retainedScroll, 24)
        }
    }
    let _ = retainedHost.frame(rect, body: stableBody) // warm retained identity and caches
    report("frame", "保留子树", timeit("revision 命中", hitFrames, {
        => Int64(retainedHost.frame(rect, body: stableBody).metrics.stabilizationPasses)
    }))
}

private func reportRetainedMiss(): Unit {
    let rect = Rect(0.0, 0.0, 720.0, 640.0)
    let missFrames: Int64 = 80
    let missHost = WidgetTestHost()
    let missScroll = State<Float32>(0.0)
    let revisions = RevisionSequence()
    report(
        "frame",
        "保留子树",
        timeit(
            "revision 每帧变化",
            missFrames,
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
}

/** Runs the transaction hot-path independently so full-suite stalls cannot hide its result. */
public func runStateSchedulerBench(includeModelStore!: Bool = true): Unit {
    printSection("状态调度")
    runMutationPolicyBench()
    runTransactionFailureBench()
    runDerivedObserverTransactionBenches()
    if (includeModelStore) {
        runModelStoreBenches()
    }
    runStateObserverScaleBench(1, 500000)
    runStateObserverScaleBench(256, 20000)
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

    let observedHost = WidgetTestHost()
    let observed = State<Int64>(0)
    let observedCounter = SubscriptionCounter()
    let observation = observed.observe({_, _ => observedCounter.hit()})
    report(
        "micro",
        "状态调度",
        timeit(
            "单 State 32 次写入合并为 1 次通知",
            20000,
            {
                =>
                    observedHost.batch({
                        => for (_ in 0..32) {
                            observed.value += 1
                        }
                    })
                    observed.value + observedCounter.calls
            }
        )
    )
    observation.close()
}

private func runMutationPolicyBench(): Unit {
    let writes: Int64 = 500000
    let defaultState = State<Int64>(0)
    report(
        "micro",
        "状态等价策略",
        timeit(
            "默认等值写入",
            writes,
            {
                =>
                    defaultState.value = 0
                    Int64(defaultState.revision)
            }
        )
    )

    let structural = State<Int64>(0, policy: structuralEqualityPolicy<Int64>())
    report(
        "micro",
        "状态等价策略",
        timeit(
            "结构等值写入抑制",
            writes,
            {
                =>
                    structural.value = 0
                    Int64(structural.revision)
            }
        )
    )

    let closure = State<Int64>(0, policy: stateMutationPolicy<Int64>({previous, current => previous == current}))
    report(
        "micro",
        "状态等价策略",
        timeit(
            "闭包等值写入抑制",
            writes,
            {
                =>
                    closure.value = 0
                    Int64(closure.revision)
            }
        )
    )
    reportCount("状态等价策略", "默认等值写入 revision", defaultState.revision)
    reportCount("状态等价策略", "结构策略等值写入 revision", structural.revision)
    reportCount("状态等价策略", "闭包策略等值写入 revision", closure.revision)
    runTransactionMutationPolicyBench()
}

private func runTransactionMutationPolicyBench(): Unit {
    let transactions: Int64 = 250000
    let defaultHost = WidgetTestHost()
    let defaultState = State<Int64>(0)
    let defaultCounter = SubscriptionCounter()
    let defaultObservation = defaultState.observe({_, _ => defaultCounter.hit()})
    report(
        "micro",
        "状态事务等价",
        timeit(
            "默认净零事务",
            transactions,
            {
                =>
                    defaultHost.batch(
                        {
                            =>
                                defaultState.value = 1
                                defaultState.value = 0
                        }
                    )
                    Int64(defaultState.revision)
            }
        )
    )

    let structuralHost = WidgetTestHost()
    let structuralState = State<Int64>(0, policy: structuralEqualityPolicy<Int64>())
    let structuralCounter = SubscriptionCounter()
    let structuralObservation = structuralState.observe({_, _ => structuralCounter.hit()})
    report(
        "micro",
        "状态事务等价",
        timeit(
            "结构策略净零事务",
            transactions,
            {
                =>
                    structuralHost.batch(
                        {
                            =>
                                structuralState.value = 1
                                structuralState.value = 0
                        }
                    )
                    Int64(structuralState.revision)
            }
        )
    )
    reportCount("状态事务等价", "默认净零事务通知", UInt64(defaultCounter.calls))
    reportCount("状态事务等价", "结构策略净零事务通知", UInt64(structuralCounter.calls))

    let defaultNotificationsBefore = defaultCounter.calls
    report(
        "micro",
        "状态事务等价",
        timeit(
            "默认净变化事务",
            transactions,
            {
                =>
                    defaultHost.batch(
                        {
                            =>
                                defaultState.value += 1
                                defaultState.value += 1
                        }
                    )
                    Int64(defaultState.revision)
            }
        )
    )
    let structuralNotificationsBefore = structuralCounter.calls
    report(
        "micro",
        "状态事务等价",
        timeit(
            "结构策略净变化事务",
            transactions,
            {
                =>
                    structuralHost.batch(
                        {
                            =>
                                structuralState.value += 1
                                structuralState.value += 1
                        }
                    )
                    Int64(structuralState.revision)
            }
        )
    )
    reportCount("状态事务等价", "默认净变化事务通知", UInt64(defaultCounter.calls - defaultNotificationsBefore))
    reportCount("状态事务等价", "结构策略净变化事务通知", UInt64(structuralCounter.calls - structuralNotificationsBefore))

    report(
        "micro",
        "状态事务等价",
        timeit(
            "默认单写事务",
            transactions,
            {
                =>
                    defaultHost.batch({=> defaultState.value += 1})
                    Int64(defaultState.revision)
            }
        )
    )
    report(
        "micro",
        "状态事务等价",
        timeit(
            "结构策略单写事务",
            transactions,
            {
                =>
                    structuralHost.batch({=> structuralState.value += 1})
                    Int64(structuralState.revision)
            }
        )
    )
    defaultObservation.close()
    structuralObservation.close()

    runTransactionMutationPolicyFrameBench()
}

private func runTransactionMutationPolicyFrameBench(): Unit {
    let frames: Int64 = 30000
    let rect = Rect(0.0, 0.0, 240.0, 120.0)
    let defaultHost = WidgetTestHost()
    let defaultState = State<Int64>(0)
    let defaultBodies = SubscriptionCounter()
    let defaultBody: () -> Unit = {
        =>
            defaultBodies.hit()
            let _ = defaultState.value
            Spacer()
    }
    let _ = defaultHost.frame(rect, body: defaultBody)
    let defaultBodiesBefore = defaultBodies.calls
    report(
        "frame",
        "状态事务等价",
        timeit(
            "默认净零事务后帧",
            frames,
            {
                =>
                    defaultHost.batch(
                        {
                            =>
                                defaultState.value = 1
                                defaultState.value = 0
                        }
                    )
                    Int64(defaultHost.frame(rect, body: defaultBody).metrics.stabilizationPasses)
            }
        )
    )

    let structuralHost = WidgetTestHost()
    let structuralState = State<Int64>(0, policy: structuralEqualityPolicy<Int64>())
    let structuralBodies = SubscriptionCounter()
    let structuralBody: () -> Unit = {
        =>
            structuralBodies.hit()
            let _ = structuralState.value
            Spacer()
    }
    let _ = structuralHost.frame(rect, body: structuralBody)
    let structuralBodiesBefore = structuralBodies.calls
    report(
        "frame",
        "状态事务等价",
        timeit(
            "结构策略净零事务后帧",
            frames,
            {
                =>
                    structuralHost.batch(
                        {
                            =>
                                structuralState.value = 1
                                structuralState.value = 0
                        }
                    )
                    Int64(structuralHost.frame(rect, body: structuralBody).metrics.stabilizationPasses)
            }
        )
    )
    reportCount("状态事务等价", "默认净零事务后 body", UInt64(defaultBodies.calls - defaultBodiesBefore))
    reportCount("状态事务等价", "结构策略净零事务后 body", UInt64(structuralBodies.calls - structuralBodiesBefore))
}

private func runStateObserverScaleBench(observerCount: Int64, writes: Int64): Unit {
    let observed = State<Int64>(0)
    let counter = SubscriptionCounter()
    var index: Int64 = 0
    while (index < observerCount) {
        let _ = observed.observe({_, _ => counter.hit()})
        index += 1
    }
    let result = timeit(
        "单 State ${observerCount} 个观察者直接通知",
        writes,
        {
            =>
                observed.value += 1
                observed.value + counter.calls
        }
    )
    let expected = observerCount * writes
    if (counter.calls != expected) {
        throw IllegalStateException("State observer benchmark expected ${expected} callbacks, got ${counter.calls}")
    }
    report("micro", "状态观察者", result)
    reportCount("状态观察者", "${observerCount} 个观察者每次写入回调", UInt64(observerCount))
}

private func runTransactionFailureBench(): Unit {
    let sourceCount: Int64 = 64
    let transactions: Int64 = 5000
    let host = WidgetTestHost()
    let sources = Array<State<Int64>>(sourceCount, {_ => State<Int64>(0)})
    let counter = TransactionFailureCounter()
    let observations = ArrayList<StateObservation<Int64>>()
    observations.add(sources[0].observe({_, _ => throw IllegalStateException("expected benchmark failure")}))
    for (index in 1..sourceCount) {
        observations.add(sources[index].observe({_, _ => counter.callback()}))
    }
    report("micro", "状态事务异常", timeit("首源失败后排空 64 State", transactions, {
        => try {
            host.batch({
                => for (source in sources) {
                source.value += 1
            }
            })
            Int64(0)
        } catch (_: IllegalStateException) {
            counter.failed()
            counter.callbacks
        }
    }))
    let expectedCallbacks = (sourceCount - 1) * transactions
    if (counter.failures != transactions || counter.callbacks != expectedCallbacks) {
        throw IllegalStateException(
            "Transaction failure benchmark expected ${transactions} failures and ${expectedCallbacks} callbacks")
    }
    reportCount("状态事务异常", "异常事务", UInt64(counter.failures))
    reportCount("状态事务异常", "异常后续 State 回调", UInt64(counter.callbacks))
    for (observation in observations) {
        observation.close()
    }
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
    let snapshotCreationsBefore = subscribedHost.frameSubscriptionSnapshotCreations()
    report("frame", "Frame 订阅表", timeit("512 个显式订阅", frames, {
        => Int64(subscribedHost.frame(rect, body: subscribedBody).metrics.frameSubscribers) + counter.calls
    }))
    let stableSnapshotCreations = subscribedHost.frameSubscriptionSnapshotCreations() - snapshotCreationsBefore
    if (stableSnapshotCreations != UInt64(0)) {
        throw IllegalStateException("Stable frame subscriptions rebuilt immutable fragments")
    }
    reportCount("Frame 订阅表", "512 个订阅稳定片段创建", stableSnapshotCreations)
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
