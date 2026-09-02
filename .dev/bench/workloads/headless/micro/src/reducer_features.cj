package bench_micro

import cui.{FeaturePath, IdentifiedAction, IdentifiedArray, Lens, ModelStore, Prism, Reducer, ScopedStore,
    identifiedBatchReducer, identifiedReducer, optionalReducer}
import bench_harness.{report, reportCount, timeit}

private let IDENTIFIED_BATCH_STEP: Int64 = 7919

private class ReducerFeatureBenchRow {
    let id: Int64
    let value: Int64

    init(id: Int64, value: Int64) {
        this.id = id
        this.value = value
    }
}

private class ReducerFeatureCollectionBench {
    private let manualReducer: Reducer<Array<ReducerFeatureBenchRow>, IdentifiedAction<Int64, Int64>>
    private let indexedReducer: Reducer<IdentifiedArray<Int64, ReducerFeatureBenchRow>, IdentifiedAction<Int64, Int64>>
    private let action: IdentifiedAction<Int64, Int64>
    private var manual: Array<ReducerFeatureBenchRow>
    private var indexed: IdentifiedArray<Int64, ReducerFeatureBenchRow>

    init(size: Int64) {
        let rows = Array<ReducerFeatureBenchRow>(size, {index => ReducerFeatureBenchRow(index, 0)})
        manual = rows
        indexed = IdentifiedArray<Int64, ReducerFeatureBenchRow>(rows, id: {row => row.id})
        action = IdentifiedAction<Int64, Int64>(size - 1, 1)
        manualReducer = Reducer<Array<ReducerFeatureBenchRow>, IdentifiedAction<Int64, Int64>>(
            {
                current, identifiedAction =>
                    var target: Int64 = -1
                    for (index in 0..current.size) {
                        if (current[index].id == identifiedAction.id) {
                            target = index
                            break
                        }
                    }
                    if (target < 0) {
                        throw IllegalStateException("manual benchmark target missing")
                    }
                    let next = current.clone()
                    let row = current[target]
                    next[target] = ReducerFeatureBenchRow(row.id, row.value + identifiedAction.action)
                    next
            }
        )
        let child = Reducer<ReducerFeatureBenchRow, Int64>(
            {row, amount => ReducerFeatureBenchRow(row.id, row.value + amount)})
        indexedReducer = identifiedReducer<Int64, ReducerFeatureBenchRow, Int64>(child)
    }

    func updateManual(): Int64 {
        manual = manualReducer.reduce(manual, action)
        manual[manual.size - 1].value
    }

    func updateIndexed(): Int64 {
        indexed = indexedReducer.reduce(indexed, action)
        indexed.at(indexed.size - 1).value
    }

    func indexedSize(): UInt64 {
        UInt64(indexed.size)
    }
}

private class IdentifiedReducerBatchBench {
    private let actions: Array<IdentifiedAction<Int64, Int64>>
    private let singleReducer: Reducer<IdentifiedArray<Int64, ReducerFeatureBenchRow>, IdentifiedAction<Int64, Int64>>
    private let batchReducer: Reducer<IdentifiedArray<Int64, ReducerFeatureBenchRow>, Array<IdentifiedAction<Int64,
        Int64>>>
    private var sequential: IdentifiedArray<Int64, ReducerFeatureBenchRow>
    private var batched: IdentifiedArray<Int64, ReducerFeatureBenchRow>

    init(size: Int64, width: Int64) {
        let rows = Array<ReducerFeatureBenchRow>(size, {index => ReducerFeatureBenchRow(index, 0)})
        let child = Reducer<ReducerFeatureBenchRow, Int64>({
            row, amount => ReducerFeatureBenchRow(row.id, row.value + amount)
        })
        singleReducer = identifiedReducer<Int64, ReducerFeatureBenchRow, Int64>(child)
        batchReducer = identifiedBatchReducer<Int64, ReducerFeatureBenchRow, Int64>(child)
        sequential = IdentifiedArray<Int64, ReducerFeatureBenchRow>(rows, id: {row => row.id})
        batched = IdentifiedArray<Int64, ReducerFeatureBenchRow>(rows, id: {row => row.id})
        actions = Array<IdentifiedAction<Int64, Int64>>(width, {
            index => IdentifiedAction<Int64, Int64>((index * IDENTIFIED_BATCH_STEP) % size, 1)
        })
    }

    func updateSequential(): Int64 {
        for (action in actions) {
            sequential = singleReducer.reduce(sequential, action)
        }
        sequential.get(actions[actions.size - 1].id).getOrThrow().value
    }

    func updateBatch(): Int64 {
        batched = batchReducer.reduce(batched, actions)
        batched.get(actions[actions.size - 1].id).getOrThrow().value
    }

    func batchSize(): UInt64 {
        UInt64(batched.size)
    }
}

private func identityFeaturePath(): FeaturePath<Int64, Int64, Int64, Int64> {
    FeaturePath<Int64, Int64, Int64, Int64>(
        state: Lens<Int64, Int64>(get: {value => value}, set: {_, value => value}),
        action: Prism<Int64, Int64>(extract: {action => Some(action)}, embed: {action => action})
    )
}

private class FeaturePathReducerBench {
    private let directReducer: Reducer<Int64, Int64>
    private let pathReducer: Reducer<Int64, Int64>
    private var directModel: Int64 = 0
    private var pathModel: Int64 = 0

    init() {
        let child = Reducer<Int64, Int64>({model, action => model + action})
        let lens = Lens<Int64, Int64>(get: {value => value}, set: {_, value => value})
        directReducer = child.pullback<Int64, Int64>(state: lens, action: {action => Some(action)})
        pathReducer = child.pullback<Int64, Int64>(identityFeaturePath())
    }

    func reduceDirect(): Int64 {
        directModel = directReducer.reduce(directModel, 1)
        directModel
    }

    func reducePath(): Int64 {
        pathModel = pathReducer.reduce(pathModel, 1)
        pathModel
    }
}

private class FeaturePathStoreBench {
    private let direct: ScopedStore<Int64, Int64>
    private let path: ScopedStore<Int64, Int64>

    init() {
        let directRoot = ModelStore<Int64, Int64>(0, update: {model, action => model + action})
        let pathRoot = ModelStore<Int64, Int64>(0, update: {model, action => model + action})
        direct = directRoot.scope<Int64, Int64>(
            state: Lens<Int64, Int64>(get: {value => value}, set: {_, value => value}),
            action: {action => action}
        )
        path = pathRoot.scope<Int64, Int64>(identityFeaturePath())
    }

    func dispatchDirect(): Int64 {
        direct.dispatch(1)
        direct.get()
    }

    func dispatchPath(): Int64 {
        path.dispatch(1)
        path.get()
    }
}

func runReducerFeatureBenches(): Unit {
    runFeaturePathBenches()
    runEntityTableBenches()
    runOptionalReducerBench()
    runIdentifiedArrayBenches()
}

func runIdentifiedArrayBenches(): Unit {
    runIdentifiedReducerBench(16, 150000)
    runIdentifiedReducerBench(1024, 12000)
    runIdentifiedReducerBench(2048, 6000)
    runIdentifiedReducerBench(4096, 3500)
    runIdentifiedReducerBench(8192, 1800)
    runIdentifiedReducerBench(10000, 1500)
    runIdentifiedBatchReducerBench(16, 4, 100000)
    runIdentifiedBatchReducerBench(1024, 4, 10000)
    runIdentifiedBatchReducerBench(10000, 1, 3000)
    runIdentifiedBatchReducerBench(10000, 4, 1500)
    runIdentifiedBatchReducerBench(10000, 8, 900)
    runIdentifiedBatchReducerBench(10000, 16, 500)
    runIdentifiedBatchReducerBench(10000, 32, 300)
    runIdentifiedBatchReducerBench(10000, 128, 100)
    runIdentifiedBatchReducerBench(100000, 32, 160)
}

func runFeaturePathBenches(): Unit {
    let reducerIterations: Int64 = 1000000
    let reducer = FeaturePathReducerBench()
    report("micro", "FeaturePath", timeit("手写 Lens + Action 提取", reducerIterations, {=> reducer.reduceDirect()}))
    report("micro", "FeaturePath", timeit("复用 FeaturePath", reducerIterations, {=> reducer.reducePath()}))

    let storeIterations: Int64 = 250000
    let store = FeaturePathStoreBench()
    report("micro", "FeaturePath", timeit("手写 store scope", storeIterations, {=> store.dispatchDirect()}))
    report("micro", "FeaturePath", timeit("FeaturePath store scope", storeIterations, {=> store.dispatchPath()}))
}

private func runOptionalReducerBench(): Unit {
    let iterations: Int64 = 500000
    let child = Reducer<Int64, Int64>({model, action => model + action})
    let manual = Reducer<?Int64, Int64>({
        model, action => match (model) {
            case Some(value) => Some(child.reduce(value, action))
            case None => None
        }
    })
    let lifted = optionalReducer(child)
    let initial: ?Int64 = Some(0)
    report("micro", "特征 Reducer", timeit("手写 Option lift", iterations, {
        => manual.reduce(initial, 1).getOrThrow()
    }))
    report("micro", "特征 Reducer", timeit("optionalReducer", iterations, {
        => lifted.reduce(initial, 1).getOrThrow()
    }))
}

private func runIdentifiedReducerBench(size: Int64, iterations: Int64): Unit {
    let manual = ReducerFeatureCollectionBench(size)
    report("micro", "特征 Reducer", timeit("${size} 项线性末项更新", iterations, {=> manual.updateManual()}))

    let indexed = ReducerFeatureCollectionBench(size)
    report("micro", "特征 Reducer", timeit("${size} 项 ID 索引末项更新", iterations, {=> indexed.updateIndexed()}))
    reportCount("特征 Reducer", "${size} 项索引规模", indexed.indexedSize())
}

private func runIdentifiedBatchReducerBench(size: Int64, width: Int64, iterations: Int64): Unit {
    let sequential = IdentifiedReducerBatchBench(size, width)
    report(
        "micro",
        "Identified reducer batch",
        timeit("${size} 项 / ${width} Action 逐次", iterations, {=> sequential.updateSequential()})
    )

    let batched = IdentifiedReducerBatchBench(size, width)
    report(
        "micro",
        "Identified reducer batch",
        timeit("${size} 项 / ${width} Action 批次", iterations, {=> batched.updateBatch()})
    )
    reportCount("Identified reducer batch", "${size} 项 / ${width} Action 规模", batched.batchSize())
}
