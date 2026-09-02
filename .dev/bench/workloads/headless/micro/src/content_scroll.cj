/*
 * Scenario: scrolling a long composed page (the shape of the planner overview / preferences pane).
 * The first A/B measures the real retained host and proves how often LazyColumn crosses a discrete
 * materialization boundary. The second group deliberately rebuilds complete widget values to
 * isolate the raw windowing cost of three variants:
 *
 *  - unwindowed (ScrollView + VStack): every block is built, laid out and drawn each frame, so cost
 *    scales with total content;
 *  - LazyColumn: only the rows near the viewport are built, so cost is O(visible) and flat as the
 *    list grows.
 *  - self-measuring LazyList: the same windowing without an application-owned row-height model.
 *
 * This is the headless (CPU-only) half; text rasterisation cost is measured on a display by
 * .dev/bench/workloads/display/planner_scroll. See also the text-measurement diagnostic for the per-frame draw counts.
 */
package bench_micro

import cui.{Rect, RetainedTestMode, State, Widget, WidgetTestHost}
import bench_scenes.{contentScrollScene, lazyContentScrollScene, measuredContentScrollScene}
import bench_harness.{BenchResult, ScrollSweep, printComparison, printSection, report, reportCount, timeit}

private let CONTENT_SCROLL_12_LAZY_MAX_NS = UInt64(650000)
private let CONTENT_SCROLL_48_LAZY_MAX_NS = UInt64(750000)
private let CONTENT_SCROLL_12_FULL_FRAMES: Int64 = 300
private let CONTENT_SCROLL_48_FULL_FRAMES: Int64 = 80
private let CONTENT_SCROLL_LAZY_FRAMES: Int64 = 800
private let LAZY_PHASE_SPLIT_FRAMES: Int64 = 800

private class LazyPhaseSplitEvidence {
    let result: BenchResult
    let bodyBuilds: Int64
    let buildNs: UInt64
    let stabilizationPasses: Int64

    init(result: BenchResult, bodyBuilds: Int64, buildNs: UInt64, stabilizationPasses: Int64) {
        this.result = result
        this.bodyBuilds = bodyBuilds
        this.buildNs = buildNs
        this.stabilizationPasses = stabilizationPasses
    }
}

private class LazyPhaseSplitCounter {
    var bodyBuilds: Int64 = 0
    var buildNs: UInt64 = UInt64(0)
    var stabilizationPasses: Int64 = 0

    func reset(): Unit {
        bodyBuilds = 0
        buildNs = UInt64(0)
        stabilizationPasses = 0
    }

    func build(): Unit {
        bodyBuilds += 1
    }

    func frame(buildNs: UInt64, passes: Int64): Unit {
        this.buildNs += buildNs
        stabilizationPasses += passes
    }
}

public func runContentScrollBench(reverse!: Bool = false): Unit {
    if (reverse) {
        requireContentScrollResults(measureContentScrollVariants(true))
        runLazyColumnPhaseSplitBench()
    } else {
        runLazyColumnPhaseSplitBench()
        requireContentScrollResults(measureContentScrollVariants(false))
    }
}

private func measureContentScrollVariants(reverse: Bool): (BenchResult, BenchResult, BenchResult, BenchResult,
    BenchResult, BenchResult) {
    printSection("内容页滚动（显式完整重建：普通 / 固定高度 / 自测量）")
    // Keep every timing window above roughly 100 ms on the reference machine. The previous lazy
    // windows lasted only 18–48 ms, so one scheduler/GC interval could make a still-3.95x win miss
    // the strict 4x relation before run.py had a chance to take its cross-process median.
    if (reverse) {
        let measured48 = measureContentScroll("48 区块 自测量", 48, CONTENT_SCROLL_LAZY_FRAMES, false, true)
        let lazy48 = measureContentScroll("48 区块 LazyColumn", 48, CONTENT_SCROLL_LAZY_FRAMES, true, false)
        let unwindowed48 = measureContentScroll("48 区块 未窗口化", 48, CONTENT_SCROLL_48_FULL_FRAMES, false, false)
        let measured12 = measureContentScroll("12 区块 自测量", 12, CONTENT_SCROLL_LAZY_FRAMES, false, true)
        let lazy12 = measureContentScroll("12 区块 LazyColumn", 12, CONTENT_SCROLL_LAZY_FRAMES, true, false)
        let unwindowed12 = measureContentScroll("12 区块 未窗口化", 12, CONTENT_SCROLL_12_FULL_FRAMES, false, false)
        return (unwindowed12, lazy12, measured12, unwindowed48, lazy48, measured48)
    }
    let unwindowed12 = measureContentScroll("12 区块 未窗口化", 12, CONTENT_SCROLL_12_FULL_FRAMES, false, false)
    let lazy12 = measureContentScroll("12 区块 LazyColumn", 12, CONTENT_SCROLL_LAZY_FRAMES, true, false)
    let measured12 = measureContentScroll("12 区块 自测量", 12, CONTENT_SCROLL_LAZY_FRAMES, false, true)
    let unwindowed48 = measureContentScroll("48 区块 未窗口化", 48, CONTENT_SCROLL_48_FULL_FRAMES, false, false)
    let lazy48 = measureContentScroll("48 区块 LazyColumn", 48, CONTENT_SCROLL_LAZY_FRAMES, true, false)
    let measured48 = measureContentScroll("48 区块 自测量", 48, CONTENT_SCROLL_LAZY_FRAMES, false, true)
    (unwindowed12, lazy12, measured12, unwindowed48, lazy48, measured48)
}

private func requireContentScrollResults(
    results: (BenchResult, BenchResult, BenchResult, BenchResult, BenchResult, BenchResult)): Unit {
    requireContentScrollEvidence(
        results[0].perIterationNs(),
        results[1].perIterationNs(),
        results[3].perIterationNs(),
        results[4].perIterationNs(),
        results[2].perIterationNs(),
        results[5].perIterationNs()
    )
}

private func runLazyColumnPhaseSplitBench(): Unit {
    printSection("LazyColumn 滚动相位分离（增量 / 强制全量）")
    let incremental = measureLazyColumnPhaseSplit("增量物化", RetainedTestMode.Incremental)
    let full = measureLazyColumnPhaseSplit("强制全量", RetainedTestMode.Full)
    printComparison("800 帧端到端", full.result, incremental.result)
    report("micro", "LazyColumn 滚动构建", BenchResult("增量物化 build", LAZY_PHASE_SPLIT_FRAMES, incremental.buildNs, 0))
    report("micro", "LazyColumn 滚动构建", BenchResult("强制全量 build", LAZY_PHASE_SPLIT_FRAMES, full.buildNs, 0))
    reportCount("LazyColumn 滚动相位", "增量 body 总执行", UInt64(incremental.bodyBuilds))
    reportCount("LazyColumn 滚动相位", "强制全量 body 总执行", UInt64(full.bodyBuilds))
    reportCount("LazyColumn 滚动相位", "增量稳定化总 pass", UInt64(incremental.stabilizationPasses))
    if (full.bodyBuilds != LAZY_PHASE_SPLIT_FRAMES || incremental.bodyBuilds * 4 >= full.bodyBuilds) {
        throw IllegalStateException(
            "LazyColumn phase split lost its build-frequency advantage: incremental=${incremental.bodyBuilds}, full=${full.bodyBuilds}")
    }
}

private func measureLazyColumnPhaseSplit(name: String, mode: RetainedTestMode): LazyPhaseSplitEvidence {
    let host = WidgetTestHost(retainedMode: mode)
    let rect = Rect(0.0, 0.0, 1120.0, 720.0)
    let scroll = State<Float32>(0.0)
    let sweep = ScrollSweep(3200.0, 24.0)
    let counter = LazyPhaseSplitCounter()
    let body: () -> Unit = {
        =>
            counter.build()
            let _ = lazyContentScrollScene(scroll, 16)
    }
    let _ = host.frame(rect, body: body)
    counter.reset()
    let result = timeit(
        name,
        LAZY_PHASE_SPLIT_FRAMES,
        {
            =>
                scroll.value = sweep.next()
                let frame = host.frame(rect, body: body)
                counter.frame(frame.metrics.buildNs, frame.metrics.stabilizationPasses)
                frame.metrics.stabilizationPasses
        }
    )
    report("frame", "LazyColumn 滚动相位", result)
    LazyPhaseSplitEvidence(result, counter.bodyBuilds, counter.buildNs, counter.stabilizationPasses)
}

private func measureContentScroll(
    name: String,
    blocks: Int64,
    frames: Int64,
    lazy: Bool,
    measured: Bool
): BenchResult {
    let ctx = headlessContext()
    let rect = Rect(0.0, 0.0, 720.0, 560.0)
    let scroll = State<Float32>(0.0)
    let sweep = ScrollSweep(Float32(blocks) * 300.0, 40.0)
    // This deliberately bypasses the retained host: advance the offset, construct a complete widget
    // value, then lay out and draw. It isolates raw virtualization from phase-cache effects.
    let result = timeit(
        name,
        frames,
        {
            =>
                scroll.value = sweep.next()
                let scene = buildScene(scroll, blocks, lazy, measured)
                ctx.renderer.beginScene(rect.w, rect.h, ctx.theme.bg)
                scene.layout(ctx, rect)
                scene.draw(ctx)
                ctx.renderer.endScene()
                0
        }
    )
    report("frame", "内容页滚动", result)
    result
}

private func requireContentScrollEvidence(
    unwindowed12: UInt64,
    lazy12: UInt64,
    unwindowed48: UInt64,
    lazy48: UInt64,
    measured12: UInt64,
    measured48: UInt64
): Unit {
    if (lazy12 > CONTENT_SCROLL_12_LAZY_MAX_NS || lazy48 > CONTENT_SCROLL_48_LAZY_MAX_NS) {
        throw IllegalStateException("Unified spatial clipping exceeded the recorded LazyColumn frame budget")
    }
    if (lazy12 > unwindowed12 || lazy48 * UInt64(4) > unwindowed48) {
        throw IllegalStateException("LazyColumn no longer preserves its visible-window scaling advantage")
    }
    if (measured12 > unwindowed12 || measured48 * UInt64(2) > unwindowed48) {
        throw IllegalStateException("Self-measuring virtualization lost its bounded-window advantage")
    }
}

private func buildScene(scroll: State<Float32>, blocks: Int64, lazy: Bool, measured: Bool): Widget {
    if (lazy) {
        lazyContentScrollScene(scroll, blocks)
    } else if (measured) {
        measuredContentScrollScene(scroll, blocks)
    } else {
        contentScrollScene(scroll, blocks)
    }
}
