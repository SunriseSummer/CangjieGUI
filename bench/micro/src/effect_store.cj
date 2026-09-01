package bench_micro

import cui.{EffectReducer, EffectStore, ModelStore, Transition}
import cui.testing.WidgetTestHost
import bench_harness.{report, reportCount, timeit}

private class EffectStoreBenchCounter {
    var callbacks: Int64 = 0
    var effects: Int64 = 0

    func callback(): Unit {
        callbacks += 1
    }

    func handle(count: Int64): Unit {
        effects += count
    }
}

func runEffectStoreBenches(): Unit {
    runEmptyEffectDispatchBench()
    runEmptyEffectActionFoldBench()
    runEffectActionFoldBench()
    runWideEffectActionFoldBench()
}

private func runWideEffectActionFoldBench(): Unit {
    let transactions: Int64 = 5000
    let actions = Array<Int64>(128, repeat: Int64(1))
    let reducer = EffectReducer<Int64, Int64, Int64>(
        {model, action => Transition<Int64, Int64>(model + action, effect: action)})
    let store = EffectStore<Int64, Int64, Int64>(0, reducer)
    let counter = EffectStoreBenchCounter()
    let observation = store.observe({_, _ => counter.callback()})
    report(
        "micro",
        "EffectStore",
        timeit(
            "128 effect action 单次折叠",
            transactions,
            {
                =>
                    store.dispatchAll(actions, handleEffects: {effects => counter.handle(effects.size)})
                    store.get()
            }
        )
    )
    reportCount("EffectStore", "128 折叠 revision", store.revision)
    reportCount("EffectStore", "128 折叠回调", UInt64(counter.callbacks))
    reportCount("EffectStore", "128 折叠数量", UInt64(counter.effects))
    observation.close()
}

private func runEmptyEffectActionFoldBench(): Unit {
    let transactions: Int64 = 20000
    let actions = Array<Int64>(32, repeat: Int64(1))
    let reducer = EffectReducer<Int64, Int64, Int64>({model, action => Transition<Int64, Int64>(model + action)})
    let store = EffectStore<Int64, Int64, Int64>(0, reducer)
    let counter = EffectStoreBenchCounter()
    let observation = store.observe({_, _ => counter.callback()})
    report(
        "micro",
        "EffectStore",
        timeit(
            "32 zero-effect action 单次折叠",
            transactions,
            {
                =>
                    store.dispatchAll(actions, handleEffects: {effects => counter.handle(effects.size)})
                    store.get()
            }
        )
    )
    reportCount("EffectStore", "零效果折叠 revision", store.revision)
    reportCount("EffectStore", "零效果折叠回调", UInt64(counter.callbacks))
    reportCount("EffectStore", "零效果折叠数量", UInt64(counter.effects))
    observation.close()
}

private func runEmptyEffectDispatchBench(): Unit {
    let actions: Int64 = 250000
    let modelStore = ModelStore<Int64, Int64>(0, update: {model, action => model + action})
    let modelCounter = EffectStoreBenchCounter()
    let modelObservation = modelStore.observe({_, _ => modelCounter.callback()})
    report(
        "micro",
        "EffectStore",
        timeit(
            "ModelStore 单 action",
            actions,
            {
                =>
                    modelStore.dispatch(1)
                    modelStore.get()
            }
        )
    )

    let effectReducer = EffectReducer<Int64, Int64, Int64>({model, action => Transition<Int64, Int64>(model + action)})
    let effectStore = EffectStore<Int64, Int64, Int64>(0, effectReducer)
    let effectCounter = EffectStoreBenchCounter()
    let effectObservation = effectStore.observe({_, _ => effectCounter.callback()})
    report(
        "micro",
        "EffectStore",
        timeit(
            "零效果单 action",
            actions,
            {
                =>
                    let effects = effectStore.dispatch(1)
                    effectStore.get() + effects.size
            }
        )
    )

    let handledStore = EffectStore<Int64, Int64, Int64>(0, effectReducer)
    let handledCounter = EffectStoreBenchCounter()
    let handledObservation = handledStore.observe({_, _ => handledCounter.callback()})
    report(
        "micro",
        "EffectStore",
        timeit(
            "显式 handler 零效果单 action",
            actions,
            {
                =>
                    handledStore.dispatch(1, handleEffects: {effects => handledCounter.handle(effects.size)})
                    handledStore.get()
            }
        )
    )

    let connectedRoot = EffectStore<Int64, Int64, Int64>(0, effectReducer)
    let connectedCounter = EffectStoreBenchCounter()
    let connected = connectedRoot.connect(handleEffects: {effects => connectedCounter.handle(effects.size)})
    let connectedObservation = connected.observe({_, _ => connectedCounter.callback()})
    report(
        "micro",
        "EffectStore",
        timeit(
            "connect 门面零效果单 action",
            actions,
            {
                =>
                    connected.dispatch(1)
                    connectedRoot.get()
            }
        )
    )
    report("micro", "EffectStore", timeit("connect 门面稳定读取", actions, {=> connected.get()}))
    reportCount("EffectStore", "ModelStore 单写回调", UInt64(modelCounter.callbacks))
    reportCount("EffectStore", "零效果单写回调", UInt64(effectCounter.callbacks))
    reportCount("EffectStore", "显式 handler 单写回调", UInt64(handledCounter.callbacks))
    reportCount("EffectStore", "connect 单写回调", UInt64(connectedCounter.callbacks))
    modelObservation.close()
    effectObservation.close()
    handledObservation.close()
    connectedObservation.close()
}

private func runEffectActionFoldBench(): Unit {
    let transactions: Int64 = 20000
    let actions = Array<Int64>(32, repeat: Int64(1))
    let reducer = EffectReducer<Int64, Int64, Int64>(
        {model, action => Transition<Int64, Int64>(model + action, effect: action)})

    let sequentialHost = WidgetTestHost()
    let sequential = EffectStore<Int64, Int64, Int64>(0, reducer)
    let sequentialCounter = EffectStoreBenchCounter()
    let sequentialObservation = sequential.observe({_, _ => sequentialCounter.callback()})
    report(
        "micro",
        "EffectStore",
        timeit(
            "32 effect action 逐次 dispatch",
            transactions,
            {
                =>
                    sequentialHost.batch({
                        => for (action in actions) {
                            sequentialCounter.handle(sequential.dispatch(action).size)
                        }
                    })
                    sequential.get()
            }
        )
    )

    let foldedHost = WidgetTestHost()
    let folded = EffectStore<Int64, Int64, Int64>(0, reducer)
    let foldedCounter = EffectStoreBenchCounter()
    let foldedObservation = folded.observe({_, _ => foldedCounter.callback()})
    report(
        "micro",
        "EffectStore",
        timeit(
            "32 effect action 单次折叠",
            transactions,
            {
                =>
                    foldedHost.batch({
                        => folded.dispatchAll(actions, handleEffects: {effects => foldedCounter.handle(effects.size)})
                    })
                    folded.get()
            }
        )
    )

    let connectedHost = WidgetTestHost()
    let connectedRoot = EffectStore<Int64, Int64, Int64>(0, reducer)
    let connectedCounter = EffectStoreBenchCounter()
    let connected = connectedRoot.connect(handleEffects: {effects => connectedCounter.handle(effects.size)})
    let connectedObservation = connected.observe({_, _ => connectedCounter.callback()})
    report(
        "micro",
        "EffectStore",
        timeit(
            "32 effect action connect 融合",
            transactions,
            {
                =>
                    connectedHost.batch({=> connected.dispatchAll(actions)})
                    connectedRoot.get()
            }
        )
    )
    reportCount("EffectStore", "逐次 effect revision", sequential.revision)
    reportCount("EffectStore", "折叠 effect revision", folded.revision)
    reportCount("EffectStore", "connect effect revision", connectedRoot.revision)
    reportCount("EffectStore", "逐次 effect 回调", UInt64(sequentialCounter.callbacks))
    reportCount("EffectStore", "折叠 effect 回调", UInt64(foldedCounter.callbacks))
    reportCount("EffectStore", "connect effect 回调", UInt64(connectedCounter.callbacks))
    reportCount("EffectStore", "逐次 effect 数", UInt64(sequentialCounter.effects))
    reportCount("EffectStore", "折叠 effect 数", UInt64(foldedCounter.effects))
    reportCount("EffectStore", "connect effect 数", UInt64(connectedCounter.effects))
    sequentialObservation.close()
    foldedObservation.close()
    connectedObservation.close()
}
