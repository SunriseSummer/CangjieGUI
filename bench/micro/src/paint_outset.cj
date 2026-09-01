package bench_micro

import std.collection.ArrayList
import cui.{Axis, PaintOutset, Rect, RetainedTestMode, Size, UiContext, UiEvent, Widget, WidgetTestHost, ZStack, emit}
import bench_harness.{BenchResult, SampledBenchResult, frameDistribution, nowNanos, printSection, report,
    reportFrameDistribution, spanNs}

private let PAINT_OUTSET_VIEWPORT = Rect(0.0, 0.0, 640.0, 720.0)

private class PaintOutsetScaleWidget <: Widget {
    private let overflow: PaintOutset

    init(overflow: PaintOutset) {
        this.overflow = overflow
        emit(this)
    }

    public func measure(_: UiContext, _: Size): Size {
        Size(1.0, 1.0)
    }

    public func layout(_: UiContext, _: Rect): Unit {}

    public func draw(_: UiContext): Unit {}

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }

    public func acceptsStretch(_: Axis): Bool {
        false
    }

    public func paintOutset(): PaintOutset {
        overflow
    }
}

private func paintOutsetBody(count: Int64, overflow: PaintOutset): () -> Unit {
    {
        => ZStack {
            for (_ in 0..count) {
                PaintOutsetScaleWidget(overflow)
            }
        }
    }
}

// Measure both variants in ABBA order inside the same allocation/clock history. Running all zero
// frames before all declared frames made a long-lived full-suite process occasionally assign a GC
// phase to only one side, even though isolated reruns showed no implementation regression.
private func samplePaintOutsetPair(
    zeroName: String,
    declaredName: String,
    iterations: Int64,
    zeroBody: () -> Int64,
    declaredBody: () -> Int64
): (SampledBenchResult, SampledBenchResult) {
    let zeroSamples = ArrayList<UInt64>()
    let declaredSamples = ArrayList<UInt64>()
    var zeroTotal: UInt64 = 0
    var declaredTotal: UInt64 = 0
    var zeroChecksum: Int64 = 0
    var declaredChecksum: Int64 = 0
    var index: Int64 = 0
    while (index < iterations) {
        let zeroFirst = index % 4 == 0 || index % 4 == 3
        if (zeroFirst) {
            let zeroStart = nowNanos()
            zeroChecksum += zeroBody()
            let zeroSample = spanNs(zeroStart, nowNanos())
            zeroSamples.add(zeroSample)
            zeroTotal += zeroSample

            let declaredStart = nowNanos()
            declaredChecksum += declaredBody()
            let declaredSample = spanNs(declaredStart, nowNanos())
            declaredSamples.add(declaredSample)
            declaredTotal += declaredSample
        } else {
            let declaredStart = nowNanos()
            declaredChecksum += declaredBody()
            let declaredSample = spanNs(declaredStart, nowNanos())
            declaredSamples.add(declaredSample)
            declaredTotal += declaredSample

            let zeroStart = nowNanos()
            zeroChecksum += zeroBody()
            let zeroSample = spanNs(zeroStart, nowNanos())
            zeroSamples.add(zeroSample)
            zeroTotal += zeroSample
        }
        index += 1
    }
    let zeroResult = BenchResult(zeroName, iterations, zeroTotal, zeroChecksum)
    let declaredResult = BenchResult(declaredName, iterations, declaredTotal, declaredChecksum)
    (SampledBenchResult(zeroResult, frameDistribution(zeroSamples.toArray())), SampledBenchResult(declaredResult,
            frameDistribution(declaredSamples.toArray())))
}

public func runPaintOutsetBench(): Unit {
    printSection("PaintOutset 合成")
    let count: Int64 = 10000
    let frames: Int64 = 400
    let zeroHost = WidgetTestHost(retainedMode: RetainedTestMode.Full)
    let declaredHost = WidgetTestHost(retainedMode: RetainedTestMode.Full)
    let zeroBody = paintOutsetBody(count, PaintOutset())
    let declaredBody = paintOutsetBody(count, PaintOutset(left: 48.0, top: 24.0, right: 72.0, bottom: 36.0))
    for (_ in 0..3) {
        let _ = zeroHost.frame(PAINT_OUTSET_VIEWPORT, body: zeroBody)
        let _ = declaredHost.frame(PAINT_OUTSET_VIEWPORT, body: declaredBody)
    }
    let pair = samplePaintOutsetPair(
        "${count} 节点零 overflow 全量帧",
        "${count} 节点显式 overflow 全量帧",
        frames,
        {=> zeroHost.frame(PAINT_OUTSET_VIEWPORT, body: zeroBody).metrics.stabilizationPasses},
        {=> declaredHost.frame(PAINT_OUTSET_VIEWPORT, body: declaredBody).metrics.stabilizationPasses}
    )
    let zero = pair[0]
    let declared = pair[1]
    let allowance = max(UInt64(50000), zero.distribution.p50Ns / UInt64(4))
    if (declared.distribution.p50Ns > zero.distribution.p50Ns + allowance) {
        throw IllegalStateException("PaintOutset value aggregation added more than the 25%/50 us gate")
    }
    report("frame", "PaintOutset 合成", zero.result)
    report("frame", "PaintOutset 合成", declared.result)
    reportFrameDistribution("PaintOutset 合成", zero.result.name, zero.distribution)
    reportFrameDistribution("PaintOutset 合成", declared.result.name, declared.distribution)
}
