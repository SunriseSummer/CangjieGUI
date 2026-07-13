/*
 * Scenario: the reactive layer's pull-model DerivedState (see src/core/derived.cj). Reading `value`
 * recomputes only when a source revision moved since the last read, so a steady source is a cheap
 * cache hit while a changing source pays the recompute. Both paths are measured to show the gap.
 */
package bench_micro

import cui.{State, derive}
import bench_harness.{printSection, report, timeit}

public func runDerivedBench(): Unit {
    printSection("派生状态（拉取模型）")
    measureCacheHit()
    measureRecompute()
}

private func measureCacheHit(): Unit {
    let source = State<Int64>(0)
    let derived = derive<Int64, Int64>(source, {v => v * 2 + 1})
    let _ = derived.value // warm the cache; the source revision never moves below
    report("micro", "派生状态", timeit("缓存命中读取", 200000, {=> derived.value}))
}

private func measureRecompute(): Unit {
    let source = State<Int64>(0)
    let derived = derive<Int64, Int64>(source, {v => v * 2 + 1})
    // Moving the source before each read invalidates the cache, forcing a recompute every time.
    report("micro", "派生状态", timeit("每次失效重算", 100000, {=>
        source.value = source.value + 1
        derived.value
    }))
}
