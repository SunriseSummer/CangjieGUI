package bench_micro

import cui.{DerivedState, Label, ModelStore, Panel, Rect, ScopedStore, State, VStack, structuralEqualityPolicy}
import cui.testing.WidgetTestHost
import bench_harness.{BenchResult, report, reportCount, timeit}

private let MODEL_STORE_SELECTOR_COUNT: Int64 = 240
// Keep both selector paths above a 400 ms process-local timing window on the reference machine.
// The old 100-frame window let a single GC/scheduler interval produce 16% cross-process MAD.
private let MODEL_STORE_SELECTOR_FRAMES: Int64 = 400

private class ModelStoreBenchCounter {
    var callbacks: Int64 = 0

    func hit(): Unit {
        callbacks += 1
    }
}

private class ModelStoreSelectorModel {
    let values: Array<Int64>

    init(values: Array<Int64>) {
        this.values = values
    }
}

private class ModelStoreSelectorAction {
    let index: Int64

    init(index: Int64) {
        this.index = index
    }
}

private class ModelStoreSelectorScene {
    let store: ModelStore<ModelStoreSelectorModel, ModelStoreSelectorAction>
    let selectors: Array<DerivedState<Int64>>
    let bodyBuilds = Array<Int64>(MODEL_STORE_SELECTOR_COUNT, repeat: Int64(0))
    private var nextIndex: Int64 = 0

    init(distinct: Bool) {
        let createdStore = ModelStore<ModelStoreSelectorModel, ModelStoreSelectorAction>(
            ModelStoreSelectorModel(Array<Int64>(MODEL_STORE_SELECTOR_COUNT, repeat: Int64(0))),
            update: {
                model, action =>
                    let next = model.values.clone()
                    next[action.index] += 1
                    ModelStoreSelectorModel(next)
            }
        )
        store = createdStore
        selectors = Array<DerivedState<Int64>>(
            MODEL_STORE_SELECTOR_COUNT,
            {
                index => if (distinct) {
                    createdStore.select<Int64>({model => model.values[index]}, policy: structuralEqualityPolicy<Int64>())
                } else {
                    createdStore.select<Int64>({model => model.values[index]})
                }
            }
        )
    }

    func changeNext(): Int64 {
        let changed = nextIndex
        store.dispatch(ModelStoreSelectorAction(changed))
        nextIndex = (nextIndex + 1) % selectors.size
        changed
    }

    func build(): Unit {
        VStack {
            for (index in 0..selectors.size) {
                let row = index
                Panel(flexible: false) {
                    bodyBuilds[row] += 1
                    Label("selector ${row}: ${selectors[row].value}")
                }
            }
        }
    }

    func totalBodyBuilds(): Int64 {
        var total: Int64 = 0
        for (builds in bodyBuilds) {
            total += builds
        }
        total
    }
}

private class ModelStoreSelectorBuildTime {
    var ns: UInt64 = UInt64(0)
}

func runModelStoreBenches(): Unit {
    runModelStoreSingleActionBench()
    runModelStoreActionFoldBench()
    runScopedStoreBenches()
    runReducerFeatureBenches()
    runModelStoreSelectorBench()
    runEffectStoreBenches()
}

private func deepScopedStore(
    root: ModelStore<Int64, Int64>,
    depth: Int64
): ScopedStore<Int64, Int64> {
    var scoped = root.scope<Int64, Int64>(state: {value => value}, action: {action => action})
    var level: Int64 = 1
    while (level < depth) {
        scoped = scoped.scope<Int64, Int64>(state: {value => value}, action: {action => action})
        level += 1
    }
    scoped
}

func runScopedStoreBenches(): Unit {
    let actions: Int64 = 150000
    runScopedStoreDepthVariant(1, actions)
    runScopedStoreDepthVariant(8, actions)
    runScopedStoreDepthVariant(32, actions)
    runScopedStoreReadVariant(1, actions)
    runScopedStoreReadVariant(8, actions)
    runScopedStoreReadVariant(32, actions)
    runScopedStoreWriteReadVariant(1, actions)
    runScopedStoreWriteReadVariant(8, actions)
    runScopedStoreWriteReadVariant(32, actions)
    measureScopedSelectorFusion()

    let transactions: Int64 = 20000
    let batch = Array<Int64>(32, repeat: Int64(1))
    let direct = ModelStore<Int64, Int64>(0, update: {model, action => model + action})
    report(
        "micro",
        "ScopedStore",
        timeit(
            "根 store / 32 action 折叠",
            transactions,
            {
                =>
                    direct.dispatchAll(batch)
                    direct.get()
            }
        )
    )
    reportCount("ScopedStore", "根折叠 revision", direct.revision)

    runScopedStoreBatchVariant(1, transactions, batch)
    runScopedStoreBatchVariant(8, transactions, batch)
    runScopedStoreBatchVariant(32, transactions, batch)
}

private func measureScopedSelectorFusion(): Unit {
    let stableReads: Int64 = 500000
    let invalidations: Int64 = 100000
    let layeredRoot = ModelStore<Int64, Int64>(0, update: {model, action => model + action})
    let layeredScope = deepScopedStore(layeredRoot, 8)
    let layered = layeredScope.map({value => value * 2})
    let fusedRoot = ModelStore<Int64, Int64>(0, update: {model, action => model + action})
    let fusedScope = deepScopedStore(fusedRoot, 8)
    let fused = fusedScope.select<Int64>({value => value * 2})
    let _ = layered.value
    let _ = fused.value

    report("micro", "ScopedStore selector", timeit("layered 稳定读取", stableReads, {=> layered.value}))
    report("micro", "ScopedStore selector", timeit("融合稳定读取", stableReads, {=> fused.value}))
    report(
        "micro",
        "ScopedStore selector",
        timeit(
            "layered dispatch 后读取",
            invalidations,
            {
                =>
                    layeredRoot.dispatch(1)
                    layered.value
            }
        )
    )
    report(
        "micro",
        "ScopedStore selector",
        timeit(
            "融合 dispatch 后读取",
            invalidations,
            {
                =>
                    fusedRoot.dispatch(1)
                    fused.value
            }
        )
    )
    reportCount("ScopedStore selector", "layered 派生节点", UInt64(2))
    reportCount("ScopedStore selector", "融合派生节点", UInt64(1))
}

private func runScopedStoreBatchVariant(depth: Int64, transactions: Int64, batch: Array<Int64>): Unit {
    let root = ModelStore<Int64, Int64>(0, update: {model, action => model + action})
    let scoped = deepScopedStore(root, depth)
    report(
        "micro",
        "ScopedStore",
        timeit(
            "${depth} 层 scope / 32 action 融合",
            transactions,
            {
                =>
                    scoped.dispatchAll(batch)
                    root.get()
            }
        )
    )
    reportCount("ScopedStore", "${depth} 层融合 revision", root.revision)
}

private func runScopedStoreDepthVariant(depth: Int64, actions: Int64): Unit {
    let root = ModelStore<Int64, Int64>(0, update: {model, action => model + action})
    let scoped = deepScopedStore(root, depth)
    report(
        "micro",
        "ScopedStore",
        timeit(
            "${depth} 层 scope / 单 action",
            actions,
            {
                =>
                    scoped.dispatch(1)
                    root.get()
            }
        )
    )
}

private func runScopedStoreReadVariant(depth: Int64, reads: Int64): Unit {
    let root = ModelStore<Int64, Int64>(0, update: {model, action => model + action})
    let scoped = deepScopedStore(root, depth)
    let _ = scoped.get()
    report(
        "micro",
        "ScopedStore",
        timeit("${depth} 层 scope / 稳定局部读取", reads, {=> scoped.get()})
    )
}

private func runScopedStoreWriteReadVariant(depth: Int64, actions: Int64): Unit {
    let root = ModelStore<Int64, Int64>(0, update: {model, action => model + action})
    let scoped = deepScopedStore(root, depth)
    let _ = scoped.get()
    report(
        "micro",
        "ScopedStore",
        timeit(
            "${depth} 层 scope / dispatch 后局部读取",
            actions,
            {
                =>
                    scoped.dispatch(1)
                    scoped.get()
            }
        )
    )
}

private func runModelStoreSelectorBench(): Unit {
    let rect = Rect(0.0, 0.0, 720.0, 1800.0)
    runModelStoreSelectorVariant(rect, false, "普通 selector")
    runModelStoreSelectorVariant(rect, true, "等价 selector")
}

private func runModelStoreSelectorVariant(rect: Rect, distinct: Bool, name: String): Unit {
    let host = WidgetTestHost()
    let scene = ModelStoreSelectorScene(distinct)
    let body: () -> Unit = {=> scene.build()}
    let _ = host.frame(rect, body: body)
    let before = scene.totalBodyBuilds()
    let _ = scene.changeNext()
    let _ = host.frame(rect, body: body)
    reportCount("ModelStore selector", "${name}单字段变更执行分支体", UInt64(scene.totalBodyBuilds() - before))

    let buildTime = ModelStoreSelectorBuildTime()
    let result = timeit(
        "240 投影 / ${name}",
        MODEL_STORE_SELECTOR_FRAMES,
        {
            =>
                let changed = scene.changeNext()
                let frame = host.frame(rect, body: body)
                buildTime.ns += frame.metrics.buildNs
                changed + frame.metrics.stabilizationPasses
        }
    )
    report("frame", "ModelStore selector", result)
    report(
        "micro",
        "ModelStore selector 构建",
        BenchResult("240 投影 / ${name} build", MODEL_STORE_SELECTOR_FRAMES, buildTime.ns, 0)
    )
}

private func runModelStoreSingleActionBench(): Unit {
    let actions: Int64 = 250000
    let direct = State<Int64>(0)
    let directCounter = ModelStoreBenchCounter()
    let directObservation = direct.observe({_, _ => directCounter.hit()})
    report(
        "micro",
        "ModelStore",
        timeit(
            "直接 State.update",
            actions,
            {
                =>
                    direct.update({value => value + 1})
                    direct.value
            }
        )
    )

    let store = ModelStore<Int64, Int64>(0, update: {model, action => model + action})
    let storeCounter = ModelStoreBenchCounter()
    let storeObservation = store.observe({_, _ => storeCounter.hit()})
    report(
        "micro",
        "ModelStore",
        timeit(
            "单 action dispatch",
            actions,
            {
                =>
                    store.dispatch(1)
                    store.get()
            }
        )
    )
    reportCount("ModelStore", "直接单写回调", UInt64(directCounter.callbacks))
    reportCount("ModelStore", "dispatch 单写回调", UInt64(storeCounter.callbacks))
    directObservation.close()
    storeObservation.close()
}

private func runModelStoreActionFoldBench(): Unit {
    let transactions: Int64 = 20000
    let actions = Array<Int64>(32, repeat: Int64(1))
    let sequentialHost = WidgetTestHost()
    let sequential = ModelStore<Int64, Int64>(0, update: {model, action => model + action})
    let sequentialCounter = ModelStoreBenchCounter()
    let sequentialObservation = sequential.observe({_, _ => sequentialCounter.hit()})
    report(
        "micro",
        "ModelStore",
        timeit(
            "32 action 逐次 dispatch",
            transactions,
            {
                =>
                    sequentialHost.batch({
                        => for (action in actions) {
                            sequential.dispatch(action)
                        }
                    })
                    sequential.get()
            }
        )
    )

    let foldedHost = WidgetTestHost()
    let folded = ModelStore<Int64, Int64>(0, update: {model, action => model + action})
    let foldedCounter = ModelStoreBenchCounter()
    let foldedObservation = folded.observe({_, _ => foldedCounter.hit()})
    report(
        "micro",
        "ModelStore",
        timeit(
            "32 action 单次折叠",
            transactions,
            {
                =>
                    foldedHost.batch({=> folded.dispatchAll(actions)})
                    folded.get()
            }
        )
    )
    reportCount("ModelStore", "逐次 dispatch revision", sequential.revision)
    reportCount("ModelStore", "单次折叠 revision", folded.revision)
    reportCount("ModelStore", "逐次 dispatch 回调", UInt64(sequentialCounter.callbacks))
    reportCount("ModelStore", "单次折叠回调", UInt64(foldedCounter.callbacks))
    sequentialObservation.close()
    foldedObservation.close()
}
