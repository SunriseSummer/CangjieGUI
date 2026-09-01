package bench_micro

import cui.{Overlay, Rect, Renderer, Size, Theme, UiContext, UiEvent, Widget, WidgetTestHost, emit}
import bench_harness.{BenchResult, printSection, report, reportCount, timeit}

private let OVERLAY_SMALL_COUNT: Int64 = 1000
private let OVERLAY_LARGE_COUNT: Int64 = 4000

private class OverlayFrameMeasurement {
    let result: BenchResult
    let replayVisits: UInt64

    init(result: BenchResult, replayVisits: UInt64) {
        this.result = result
        this.replayVisits = replayVisits
    }
}

private class OverlayDispatchProbe {
    var visits: Int64 = 0
}

private class OverlayScaleProbe <: Widget {
    private let overlays: Array<Overlay>

    init(overlays: Array<Overlay>) {
        this.overlays = overlays
        emit(this)
    }

    public func measure(_: UiContext, available: Size): Size {
        available
    }

    public func layout(ctx: UiContext, _: Rect): Unit {
        for (overlay in overlays) {
            ctx.setOverlay(overlay)
        }
    }

    public func draw(_: UiContext): Unit {}

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }
}

public func runOverlayScaleBench(): Unit {
    printSection("Overlay 注册与路由扩展性")
    let smallProbe = OverlayDispatchProbe()
    let largeProbe = OverlayDispatchProbe()
    let small = buildOverlaySet(OVERLAY_SMALL_COUNT, smallProbe)
    let large = buildOverlaySet(OVERLAY_LARGE_COUNT, largeProbe)

    let registerSmall = measureOverlayRegistration(small, 80)
    let registerLarge = measureOverlayRegistration(large, 40)
    report("micro", "Overlay 扩展性", registerSmall)
    report("micro", "Overlay 扩展性", registerLarge)

    // Keep both sides above a 100 ms timing window and execute the same total number of handlers.
    // The former 2.4/9.6 ms windows could turn one scheduler interval into a false >8x scale failure.
    let dispatchSmall = measureOverlayDispatch(small, smallProbe, 4000)
    let dispatchLarge = measureOverlayDispatch(large, largeProbe, 1000)
    report("micro", "Overlay 扩展性", dispatchSmall)
    report("micro", "Overlay 扩展性", dispatchLarge)
    let stableFrame = measureStableOverlayFrame(large, 120)
    report("frame", "Overlay 扩展性", stableFrame.result)
    if (stableFrame.replayVisits != UInt64(0)) {
        throw IllegalStateException("Stable overlay layout replay materialized a committed fragment")
    }
    if (dispatchLarge.perIterationNs() > dispatchSmall.perIterationNs() * UInt64(8)) {
        throw IllegalStateException("Keyed overlay dispatch scaled superlinearly")
    }
    reportCount("Overlay 扩展性", "稳定帧 overlay 片段逐项重放", stableFrame.replayVisits)
    reportCount("Overlay 扩展性", "大规模 overlay 数", UInt64(large.size))
}

private func measureStableOverlayFrame(overlays: Array<Overlay>, iterations: Int64): OverlayFrameMeasurement {
    let host = WidgetTestHost()
    let rect = Rect(0.0, 0.0, 200.0, 80.0)
    let body: () -> Unit = {=> OverlayScaleProbe(overlays)}
    let _ = host.frame(rect, body: body)
    let replayVisitsBefore = host.overlayFragmentReplayVisits()
    let result = timeit("${overlays.size} keyed 稳定帧", iterations, {
        => Int64(host.frame(rect, body: body).metrics.overlayCount)
    })
    OverlayFrameMeasurement(result, host.overlayFragmentReplayVisits() - replayVisitsBefore)
}

private func buildOverlaySet(count: Int64, probe: OverlayDispatchProbe): Array<Overlay> {
    Array<Overlay>(count, {
        index => Overlay(
            handleEvent: {
                _, _ =>
                    probe.visits += 1
                    false
            },
            render: {_ => ()},
            owner: "overlay-${index}"
        )
    })
}

private func measureOverlayRegistration(overlays: Array<Overlay>, iterations: Int64): BenchResult {
    let context = UiContext(Renderer.headless(), Theme.light())
    timeit(
        "${overlays.size} keyed 注册",
        iterations,
        {
            =>
                context.clearActiveOverlay()
                for (overlay in overlays) {
                    context.setOverlay(overlay)
                }
                context.overlayCount()
        }
    )
}

private func measureOverlayDispatch(
    overlays: Array<Overlay>,
    probe: OverlayDispatchProbe,
    iterations: Int64
): BenchResult {
    let context = UiContext(Renderer.headless(), Theme.light())
    for (overlay in overlays) {
        context.setOverlay(overlay)
    }
    let visitsBefore = probe.visits
    let result = timeit("${overlays.size} keyed 未处理事件", iterations, {
        => if (context.dispatchOverlay(UiEvent.Unknown(UInt32(0)))) {
            Int64(1)
        } else {
            Int64(0)
        }
    })
    let visits = probe.visits - visitsBefore
    if (visits != overlays.size * iterations) {
        throw IllegalStateException("Keyed overlay dispatch visited ${visits}/${overlays.size * iterations} handlers")
    }
    result
}
