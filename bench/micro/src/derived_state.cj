/*
 * Scenario: the reactive layer's pull-model DerivedState (see src/core/derived.cj). Reading `value`
 * recomputes only when a source revision moved since the last read, so a steady source is a cheap
 * cache hit while a changing source pays the recompute. Both paths are measured to show the gap.
 */
package bench_micro

import cui.{Bindable, DerivedState, Lens, Observable, Rect, Reducer, RetainedTestMode, Size, State, UiContext, UiEvent, Widget,
    WidgetTestHost, derive, deriveStates, emit, remember, structuralEqualityPolicy}
import bench_harness.{printSection, report, reportCount, timeit}

private class DerivedComputeCounter {
    var calls: Int64 = 0

    func hit(): Unit {
        calls += 1
    }
}

private class ReducerModelBox {
    var value: Int64 = 0
}

private class DerivedCollectorValue <: Widget {
    private let checksum: Int64

    init(checksum: Int64) {
        this.checksum = checksum
        emit(this)
    }

    public func measure(_: UiContext, _: Size): Size {
        Size(Float32(checksum % 2), 0.0)
    }

    public func layout(_: UiContext, _: Rect): Unit {}

    public func draw(_: UiContext): Unit {}

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }
}

public func runDerivedBench(): Unit {
    printSection("派生状态（拉取模型）")
    measureCacheHit(1, 500000)
    measureCacheHit(256, 100000)
    measureRecompute()
    measureFourSourceFusion()
    measureFourSourceDistinctFusion()
    measureDependencyCollection(1, 5000)
    measureDependencyCollection(256, 2000)
    measureRememberedDependencyCollection(1, 5000)
    measureRememberedDependencyCollection(256, 2000)
    measureInlineDependencyCollection(1, 5000)
    measureInlineDependencyCollection(256, 2000)
    measureInlineStateDependencyCollection(1, 5000)
    measureInlineStateDependencyCollection(256, 2000)
    measureInlineManualCollection(1, 5000)
    measureInlineManualCollection(256, 2000)
    runBindingCompositionBench()
}

public func runBindingCompositionBench(): Unit {
    measureNestedBindingWrite(1, 200000)
    measureNaiveLensBindingWrite(1, 200000)
    measureComposedLensBindingWrite(1, 200000)
    measureNestedBindingWrite(8, 100000)
    measureNaiveLensBindingWrite(8, 100000)
    measureComposedLensBindingWrite(8, 100000)
    measureNestedBindingWrite(32, 20000)
    measureNaiveLensBindingWrite(32, 20000)
    measureComposedLensBindingWrite(32, 20000)
    measureNestedBindingUpdate(1, 200000)
    measureNaiveLensBindingUpdate(1, 200000)
    measureComposedLensBindingUpdate(1, 200000)
    measureNestedBindingUpdate(8, 100000)
    measureNaiveLensBindingUpdate(8, 100000)
    measureComposedLensBindingUpdate(8, 100000)
    measureNestedBindingUpdate(32, 20000)
    measureNaiveLensBindingUpdate(32, 20000)
    measureComposedLensBindingUpdate(32, 20000)
    measureLensReducerPullback("1 层朴素 Lens Reducer pullback", naiveComposedIdentityLens(1), 200000)
    measureLensReducerPullback("1 层 Lens 融合 Reducer pullback", composedIdentityLens(1), 200000)
    measureLensReducerPullback("8 层朴素 Lens Reducer pullback", naiveComposedIdentityLens(8), 100000)
    measureLensReducerPullback("8 层 Lens 融合 Reducer pullback", composedIdentityLens(8), 100000)
    measureLensReducerPullback("32 层朴素 Lens Reducer pullback", naiveComposedIdentityLens(32), 20000)
    measureLensReducerPullback("32 层 Lens 融合 Reducer pullback", composedIdentityLens(32), 20000)
}

private func measureFourSourceDistinctFusion(): Unit {
    let policy = structuralEqualityPolicy<Int64>()
    let first = State<Int64>(1)
    let second = State<Int64>(2)
    let third = State<Int64>(3)
    let fourth = State<Int64>(4)
    let layeredComputes = DerivedComputeCounter()
    let fusedComputes = DerivedComputeCounter()
    let layered = derive(
        first,
        second,
        third,
        fourth,
        {
            a, b, c, d =>
                layeredComputes.hit()
                (a + b + c + d) % 2
        }
    ).distinct(policy)
    let fused = derive(
        first,
        second,
        third,
        fourth,
        {
            a, b, c, d =>
                fusedComputes.hit()
                (a + b + c + d) % 2
        },
        policy: policy
    )
    let _ = layered.value
    let _ = fused.value
    let stableReads: Int64 = 500000
    let layeredStable = timeit("4 源 layered distinct 稳定读取", stableReads, {=> layered.value})
    let fusedStable = timeit("4 源融合 policy 稳定读取", stableReads, {=> fused.value})
    if (layeredComputes.calls != 1 || fusedComputes.calls != 1) {
        throw IllegalStateException("Stable four-source quotient unexpectedly recomputed")
    }
    report("micro", "派生结果商融合", layeredStable)
    report("micro", "派生结果商融合", fusedStable)

    let layeredSource = State<Int64>(0)
    let layeredOther = State<Int64>(1)
    let layeredThird = State<Int64>(2)
    let layeredFourth = State<Int64>(3)
    let layeredMissComputes = DerivedComputeCounter()
    let layeredMissNode = derive(
        layeredSource,
        layeredOther,
        layeredThird,
        layeredFourth,
        {
            a, b, c, d =>
                layeredMissComputes.hit()
                (a + b + c + d) % 2
        }
    ).distinct(policy)
    let fusedSource = State<Int64>(0)
    let fusedOther = State<Int64>(1)
    let fusedThird = State<Int64>(2)
    let fusedFourth = State<Int64>(3)
    let fusedMissComputes = DerivedComputeCounter()
    let fusedMissNode = derive(
        fusedSource,
        fusedOther,
        fusedThird,
        fusedFourth,
        {
            a, b, c, d =>
                fusedMissComputes.hit()
                (a + b + c + d) % 2
        },
        policy: policy
    )
    let _ = layeredMissNode.value
    let _ = fusedMissNode.value
    let invalidations: Int64 = 100000
    let layeredMiss = timeit(
        "4 源 layered distinct 等价失效",
        invalidations,
        {
            =>
                layeredSource.value += 2
                layeredMissNode.value
        }
    )
    let fusedMiss = timeit(
        "4 源融合 policy 等价失效",
        invalidations,
        {
            =>
                fusedSource.value += 2
                fusedMissNode.value
        }
    )
    if (layeredMissComputes.calls != invalidations + 1 || fusedMissComputes.calls != invalidations + 1) {
        throw IllegalStateException("Four-source quotient invalidation lost a recomputation")
    }
    report("micro", "派生结果商融合", layeredMiss)
    report("micro", "派生结果商融合", fusedMiss)
    reportCount("派生结果商融合", "layered distinct 派生节点", UInt64(2))
    reportCount("派生结果商融合", "融合 policy 派生节点", UInt64(1))
}

private func measureFourSourceFusion(): Unit {
    let first = State<Int64>(1)
    let second = State<Int64>(2)
    let third = State<Int64>(3)
    let fourth = State<Int64>(4)
    let nestedLeafComputes = DerivedComputeCounter()
    let nestedRootComputes = DerivedComputeCounter()
    let fusedComputes = DerivedComputeCounter()
    let nestedLeaf = derive(
        first,
        second,
        {
            a, b =>
                nestedLeafComputes.hit()
                a + b
        }
    )
    let nested = derive(
        nestedLeaf,
        third,
        fourth,
        {
            firstTwo, c, d =>
                nestedRootComputes.hit()
                firstTwo + c + d
        }
    )
    let fused = derive(
        first,
        second,
        third,
        fourth,
        {
            a, b, c, d =>
                fusedComputes.hit()
                a + b + c + d
        }
    )
    let _ = nested.value
    let _ = fused.value
    let stableReads: Int64 = 500000
    let nestedStable = timeit("4 异构源嵌套 workaround 稳定读取", stableReads, {=> nested.value})
    let fusedStable = timeit("4 异构源融合稳定读取", stableReads, {=> fused.value})
    if (nestedLeafComputes.calls != 1 || nestedRootComputes.calls != 1 || fusedComputes.calls != 1) {
        throw IllegalStateException("Stable four-source derive unexpectedly recomputed")
    }
    report("micro", "异构派生积", nestedStable)
    report("micro", "异构派生积", fusedStable)

    let nestedSource = State<Int64>(0)
    let nestedOther = State<Int64>(1)
    let nestedThird = State<Int64>(2)
    let nestedFourth = State<Int64>(3)
    let nestedInvalidatedLeaf = DerivedComputeCounter()
    let nestedInvalidatedRoot = DerivedComputeCounter()
    let nestedPair = derive(
        nestedSource,
        nestedOther,
        {
            a, b =>
                nestedInvalidatedLeaf.hit()
                a + b
        }
    )
    let nestedInvalidated = derive(
        nestedPair,
        nestedThird,
        nestedFourth,
        {
            pair, c, d =>
                nestedInvalidatedRoot.hit()
                pair + c + d
        }
    )
    let fusedSource = State<Int64>(0)
    let fusedOther = State<Int64>(1)
    let fusedThird = State<Int64>(2)
    let fusedFourth = State<Int64>(3)
    let fusedInvalidatedComputes = DerivedComputeCounter()
    let fusedInvalidated = derive(
        fusedSource,
        fusedOther,
        fusedThird,
        fusedFourth,
        {
            a, b, c, d =>
                fusedInvalidatedComputes.hit()
                a + b + c + d
        }
    )
    let _ = nestedInvalidated.value
    let _ = fusedInvalidated.value
    let invalidations: Int64 = 100000
    let nestedMiss = timeit(
        "4 异构源嵌套 workaround 失效",
        invalidations,
        {
            =>
                nestedSource.value += 1
                nestedInvalidated.value
        }
    )
    let fusedMiss = timeit(
        "4 异构源融合失效",
        invalidations,
        {
            =>
                fusedSource.value += 1
                fusedInvalidated.value
        }
    )
    if (nestedInvalidatedLeaf.calls != invalidations + 1 || nestedInvalidatedRoot.calls != invalidations + 1 ||
        fusedInvalidatedComputes.calls != invalidations + 1) {
        throw IllegalStateException("Four-source derive invalidation lost a recomputation")
    }
    report("micro", "异构派生积", nestedMiss)
    report("micro", "异构派生积", fusedMiss)
    reportCount("异构派生积", "嵌套 workaround 每次失效计算节点", UInt64(2))
    reportCount("异构派生积", "四源融合每次失效计算节点", UInt64(1))
}

private func measureNestedBindingWrite(depth: Int64, writes: Int64): Unit {
    let root = State<Int64>(0)
    var leaf: Bindable<Int64> = root
    for (_ in 0..depth) {
        leaf = leaf.project(get: {value => value}, set: {_, value => value})
    }
    let target = leaf
    let result = timeit(
        "${depth} 层 Binding 写入",
        writes,
        {
            =>
                target.value += 1
                root.value
        }
    )
    if (root.value != writes) {
        throw IllegalStateException("Nested Binding wrote ${root.value}/${writes} values at depth ${depth}")
    }
    report("micro", "Binding 组合", result)
}

private func measureNestedBindingUpdate(depth: Int64, writes: Int64): Unit {
    let root = State<Int64>(0)
    var leaf: Bindable<Int64> = root
    for (_ in 0..depth) {
        leaf = leaf.project(get: {value => value}, set: {_, value => value})
    }
    let target = leaf
    let result = timeit(
        "${depth} 层 Binding update",
        writes,
        {
            =>
                target.update({value => value + 1})
                root.value
        }
    )
    if (root.value != writes) {
        throw IllegalStateException("Nested Binding update produced ${root.value}/${writes} values at depth ${depth}")
    }
    report("micro", "Binding 组合", result)
}

private func identityLens(): Lens<Int64, Int64> {
    Lens<Int64, Int64>(get: {value => value}, set: {_, value => value})
}

private func composedIdentityLens(depth: Int64): Lens<Int64, Int64> {
    var lens = identityLens()
    for (_ in 1..depth) {
        lens = lens.then(identityLens())
    }
    lens
}

/* Reconstructs the former get/set-only `then` representation for a paired regression control. */
private func naiveComposedIdentityLens(depth: Int64): Lens<Int64, Int64> {
    var lens = identityLens()
    for (_ in 1..depth) {
        let parent = lens
        let child = identityLens()
        lens = Lens<Int64, Int64>(
            get: {value => child.get(parent.get(value))},
            set: {
                value, focused => parent.set(value, child.set(parent.get(value), focused))
            }
        )
    }
    lens
}

private func measureNaiveLensBindingWrite(depth: Int64, writes: Int64): Unit {
    let root = State<Int64>(0)
    let target = root.project(naiveComposedIdentityLens(depth))
    let result = timeit(
        "${depth} 层朴素 Lens Binding 写入",
        writes,
        {
            =>
                target.value += 1
                root.value
        }
    )
    if (root.value != writes) {
        throw IllegalStateException("Naive Lens Binding wrote ${root.value}/${writes} values at depth ${depth}")
    }
    report("micro", "Binding 组合", result)
}

private func measureComposedLensBindingWrite(depth: Int64, writes: Int64): Unit {
    let root = State<Int64>(0)
    let target = root.project(composedIdentityLens(depth))
    let result = timeit(
        "${depth} 层 Lens 融合 Binding 写入",
        writes,
        {
            =>
                target.value += 1
                root.value
        }
    )
    if (root.value != writes) {
        throw IllegalStateException("Composed Lens Binding wrote ${root.value}/${writes} values at depth ${depth}")
    }
    report("micro", "Binding 组合", result)
}

private func measureComposedLensBindingUpdate(depth: Int64, writes: Int64): Unit {
    let root = State<Int64>(0)
    let target = root.project(composedIdentityLens(depth))
    let result = timeit(
        "${depth} 层 Lens 融合 Binding update",
        writes,
        {
            =>
                target.update({value => value + 1})
                root.value
        }
    )
    if (root.value != writes) {
        throw IllegalStateException("Composed Lens Binding update produced ${root.value}/${writes} values at depth ${depth}")
    }
    report("micro", "Binding 组合", result)
}

private func measureNaiveLensBindingUpdate(depth: Int64, writes: Int64): Unit {
    let root = State<Int64>(0)
    let target = root.project(naiveComposedIdentityLens(depth))
    let result = timeit(
        "${depth} 层朴素 Lens Binding update",
        writes,
        {
            =>
                target.update({value => value + 1})
                root.value
        }
    )
    if (root.value != writes) {
        throw IllegalStateException("Naive Lens Binding update produced ${root.value}/${writes} values at depth ${depth}")
    }
    report("micro", "Binding 组合", result)
}

private func measureLensReducerPullback(name: String, lens: Lens<Int64, Int64>, actions: Int64): Unit {
    let reducer = Reducer<Int64, Int64>({model, action => model + action})
        .pullback<Int64, Int64>(state: lens, action: {action => Some(action)})
    let model = ReducerModelBox()
    for (_ in 0..1000) {
        model.value = reducer.reduce(model.value, 1)
    }
    model.value = 0
    let result = timeit(
        name,
        actions,
        {
            =>
                model.value = reducer.reduce(model.value, 1)
                model.value
        }
    )
    if (model.value != actions) {
        throw IllegalStateException("Lens Reducer pullback produced ${model.value}/${actions} actions")
    }
    report("micro", "Lens pullback", result)
}

private func measureCacheHit(sourceCount: Int64, reads: Int64): Unit {
    let states = Array<State<Int64>>(sourceCount, {index => State<Int64>(index)})
    let sources = Array<Observable<Int64>>(sourceCount, {index => states[index]})
    let counter = DerivedComputeCounter()
    let derived = derive<Int64, Int64>(
        sources,
        {
            values =>
                counter.hit()
                var total: Int64 = 1
                for (value in values) {
                    total += value
                }
                total
        }
    )
    let _ = derived.value // warm the cache; the source revision never moves below
    report("micro", "派生状态", timeit("${sourceCount} 源缓存命中读取", reads, {=> derived.value}))
    if (counter.calls != Int64(1)) {
        throw IllegalStateException("Derived cache-hit benchmark recomputed ${counter.calls} times")
    }
    reportCount("派生状态", "${sourceCount} 源稳定期重算", UInt64(counter.calls - 1))
}

private func measureRecompute(): Unit {
    let source = State<Int64>(0)
    let counter = DerivedComputeCounter()
    let derived = derive<Int64, Int64>(
        source,
        {
            v =>
                counter.hit()
                v * 2 + 1
        }
    )
    // Moving the source before each read invalidates the cache, forcing a recompute every time.
    let iterations: Int64 = 100000
    report(
        "micro",
        "派生状态",
        timeit(
            "每次失效重算",
            iterations,
            {
                =>
                    source.value = source.value + 1
                    derived.value
            }
        )
    )
    if (counter.calls != iterations) {
        throw IllegalStateException("Derived recompute benchmark expected ${iterations} calls, got ${counter.calls}")
    }
    reportCount("派生状态", "每次失效精确重算", UInt64(counter.calls / iterations))
}

private func measureDependencyCollection(sourceCount: Int64, frames: Int64): Unit {
    let states = Array<State<Int64>>(sourceCount, {index => State<Int64>(index)})
    let sources = Array<Observable<Int64>>(sourceCount, {index => states[index]})
    let counter = DerivedComputeCounter()
    let derived = derive<Int64, Int64>(
        sources,
        {
            values =>
                counter.hit()
                var total: Int64 = 0
                for (value in values) {
                    total += value
                }
                total
        }
    )
    let host = WidgetTestHost(retainedMode: RetainedTestMode.Full)
    let viewport = Rect(0.0, 0.0, 640.0, 480.0)
    let body: () -> Unit = {=> DerivedCollectorValue(derived.value)}
    let _ = host.frame(viewport, body: body)
    let dependencies = maximumBuildDependencies(host)
    let result = timeit("${sourceCount} 源依赖收集重登记", frames, {
        => host.frame(viewport, body: body).metrics.stabilizationPasses
    })
    if (counter.calls != Int64(1)) {
        throw IllegalStateException("Derived dependency collector recomputed ${counter.calls} times")
    }
    if (dependencies != Int64(1)) {
        throw IllegalStateException("Stable Derived dependency collector committed ${dependencies} edges")
    }
    report("frame", "派生依赖收集", result)
    reportCount("派生依赖收集", "${sourceCount} 源提交依赖边", UInt64(dependencies))
}

private func maximumBuildDependencies(host: WidgetTestHost): Int64 {
    let diagnostics = host.retainedDiagnostics()
    var result: Int64 = 0
    for (scope in diagnostics.scopes) {
        result = max(result, scope.stats.buildDependencyCount)
    }
    for (scope in diagnostics.automaticScopes) {
        result = max(result, scope.buildDependencyCount)
    }
    result
}

private func measureRememberedDependencyCollection(sourceCount: Int64, frames: Int64): Unit {
    let states = Array<State<Int64>>(sourceCount, {index => State<Int64>(index)})
    let creations = DerivedComputeCounter()
    let computes = DerivedComputeCounter()
    let host = WidgetTestHost(retainedMode: RetainedTestMode.Full)
    let viewport = Rect(0.0, 0.0, 640.0, 480.0)
    let body: () -> Unit = {
        =>
            let derived = remember<DerivedState<Int64>> {
                creations.hit()
                deriveStates<Int64, Int64>(
                    states,
                    {
                        values =>
                            computes.hit()
                            values[values.size - 1]
                    }
                )
            }
            DerivedCollectorValue(derived.value)
    }
    let _ = host.frame(viewport, body: body)
    let result = timeit("${sourceCount} 源 remember 稳定派生", frames, {
        => host.frame(viewport, body: body).metrics.stabilizationPasses
    })
    if (creations.calls != Int64(1) || computes.calls != Int64(1)) {
        throw IllegalStateException(
            "Remembered Derived expected one creation/compute, got ${creations.calls}/${computes.calls}")
    }
    let dependencies = maximumBuildDependencies(host)
    if (dependencies != Int64(1)) {
        throw IllegalStateException("Remembered Derived committed ${dependencies} dependencies")
    }
    report("frame", "派生依赖收集", result)
    reportCount("派生依赖收集", "${sourceCount} 源 remember 提交依赖边", UInt64(dependencies))
}

private func measureInlineDependencyCollection(sourceCount: Int64, frames: Int64): Unit {
    let states = Array<State<Int64>>(sourceCount, {index => State<Int64>(index)})
    let sources = Array<Observable<Int64>>(sourceCount, {index => states[index]})
    let counter = DerivedComputeCounter()
    let host = WidgetTestHost(retainedMode: RetainedTestMode.Full)
    let viewport = Rect(0.0, 0.0, 640.0, 480.0)
    let body: () -> Unit = {
        =>
            let derived = derive<Int64, Int64>(
                sources,
                {
                    values =>
                        counter.hit()
                        values[values.size - 1]
                }
            )
            DerivedCollectorValue(derived.value)
    }
    let _ = host.frame(viewport, body: body)
    let result = timeit("${sourceCount} 源内联擦除派生", frames, {
        => host.frame(viewport, body: body).metrics.stabilizationPasses
    })
    if (counter.calls != frames + 1) {
        throw IllegalStateException("Inline Derived benchmark expected ${frames + 1} computes, got ${counter.calls}")
    }
    let dependencies = maximumBuildDependencies(host)
    if (dependencies != sourceCount) {
        throw IllegalStateException("Inline Derived benchmark committed ${dependencies}/${sourceCount} source edges")
    }
    report("frame", "派生依赖收集", result)
    reportCount("派生依赖收集", "${sourceCount} 源内联提交依赖边", UInt64(dependencies))
}

private func measureInlineStateDependencyCollection(sourceCount: Int64, frames: Int64): Unit {
    let states = Array<State<Int64>>(sourceCount, {index => State<Int64>(index)})
    let counter = DerivedComputeCounter()
    let host = WidgetTestHost(retainedMode: RetainedTestMode.Full)
    let viewport = Rect(0.0, 0.0, 640.0, 480.0)
    let body: () -> Unit = {
        =>
            let derived = deriveStates<Int64, Int64>(
                states,
                {
                    values =>
                        counter.hit()
                        values[values.size - 1]
                }
            )
            DerivedCollectorValue(derived.value)
    }
    let _ = host.frame(viewport, body: body)
    let result = timeit("${sourceCount} State 内联专用派生", frames, {
        => host.frame(viewport, body: body).metrics.stabilizationPasses
    })
    if (counter.calls != frames + 1) {
        throw IllegalStateException(
            "Inline State Derived benchmark expected ${frames + 1} computes, got ${counter.calls}")
    }
    let dependencies = maximumBuildDependencies(host)
    if (dependencies != sourceCount) {
        throw IllegalStateException("Inline State Derived committed ${dependencies}/${sourceCount} source edges")
    }
    report("frame", "派生依赖收集", result)
    reportCount("派生依赖收集", "${sourceCount} State 专用提交依赖边", UInt64(dependencies))
}

private func measureInlineManualCollection(sourceCount: Int64, frames: Int64): Unit {
    let states = Array<State<Int64>>(sourceCount, {index => State<Int64>(index)})
    let counter = DerivedComputeCounter()
    let host = WidgetTestHost(retainedMode: RetainedTestMode.Full)
    let viewport = Rect(0.0, 0.0, 640.0, 480.0)
    let body: () -> Unit = {
        =>
            counter.hit()
            var total: Int64 = 0
            for (state in states) {
                total += state.value
            }
            DerivedCollectorValue(total)
    }
    let _ = host.frame(viewport, body: body)
    let result = timeit("${sourceCount} 源内联手工读取", frames, {
        => host.frame(viewport, body: body).metrics.stabilizationPasses
    })
    if (counter.calls != frames + 1) {
        throw IllegalStateException("Inline manual benchmark expected ${frames + 1} reads, got ${counter.calls}")
    }
    let dependencies = maximumBuildDependencies(host)
    if (dependencies != sourceCount) {
        throw IllegalStateException("Inline manual benchmark committed ${dependencies}/${sourceCount} source edges")
    }
    report("frame", "派生依赖收集", result)
    reportCount("派生依赖收集", "${sourceCount} 源手工提交依赖边", UInt64(dependencies))
}
