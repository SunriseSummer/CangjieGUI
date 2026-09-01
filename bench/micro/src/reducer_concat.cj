package bench_micro

import cui.Reducer
import bench_harness.{report, timeit}

func runReducerConcatBenches(): Unit {
    measureReducerConcat(8, 200000)
    measureReducerConcat(128, 20000)
    measureReducerConcat(512, 4000)
    measureReducerConcat(513, 4000)
    measureReducerConcat(768, 3000)
    measureReducerConcat(1024, 2000)
}

private func measureReducerConcat(depth: Int64, iterations: Int64): Unit {
    let reducers = Array<Reducer<Int64, Int64>>(depth, {_ => Reducer<Int64, Int64>({model, _ => model + 1})})
    let left = leftReducerProduct(reducers)
    let balanced = Reducer<Int64, Int64>.concat(reducers)
    report("micro", "Reducer concat", timeit("${depth} 项左结合 reduce", iterations, {=> left.reduce(0, 0)}))
    report("micro", "Reducer concat", timeit("${depth} 项平衡 reduce", iterations, {=> balanced.reduce(0, 0)}))
    report("micro", "Reducer concat", timeit("${depth} 项左结合组合并 reduce", iterations, {
        => leftReducerProduct(reducers).reduce(0, 0)
    }))
    report("micro", "Reducer concat", timeit("${depth} 项平衡组合并 reduce", iterations, {
        => Reducer<Int64, Int64>.concat(reducers).reduce(0, 0)
    }))
}

private func leftReducerProduct(reducers: Array<Reducer<Int64, Int64>>): Reducer<Int64, Int64> {
    var result = reducers[0]
    for (index in 1..reducers.size) {
        result = result.then(reducers[index])
    }
    result
}
