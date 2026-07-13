/*
 * A self-terminating, self-instrumenting driver for the display benchmarks. Because the widget tree
 * is rebuilt every frame, a driver's own fields would reset each frame — so the accumulator that
 * counts frames and totals timings lives in a BenchAccumulator created once in main and captured
 * across frames, while the per-frame BenchDriver widget merely forwards each Frame to it.
 *
 * Placed as a sibling in the tree, the driver receives every frame (containers fan Frame out to all
 * children). On each frame it advances an optional scroll offset, times the interval with the
 * high-resolution clock, and after a fixed number of measured frames prints the aggregate and asks
 * the app to close. That removes the need for a human to read a meter and close the window: the
 * benchmark runs a bounded workload, prints a machine-readable @@RESULT|display line, and exits.
 * The measured interval is the full frame period (build + layout + draw + present), so with
 * frameDelay = 0 it is the real per-frame cost including SDL text rasterisation.
 */
package bench_scenes

import cui.{PerformanceClock, Rect, Size, State, UiContext, UiEvent, Widget, emit}
import bench_harness.{BenchResult, ScrollSweep, formatDuration, report}

/** Persistent benchmark state: created once, survives the per-frame rebuild via capture. */
public class BenchAccumulator {
    private let group: String
    private let name: String
    private let scroll: ?State<Float32>
    private let sweep: ?ScrollSweep
    private let warmup: Int64
    private let target: Int64
    private var frame: Int64 = 0
    private var measured: Int64 = 0
    private var lastTicks: UInt64 = 0
    private var sumNs: UInt64 = 0
    private var minNs: UInt64 = UInt64.Max
    private var maxNs: UInt64 = 0
    private var done: Bool = false

    public init(
        group!: String,
        name!: String,
        scroll!: ?State<Float32> = None,
        sweep!: ?ScrollSweep = None,
        warmup!: Int64 = 20,
        frames!: Int64 = 150
    ) {
        this.group = group
        this.name = name
        this.scroll = scroll
        this.sweep = sweep
        this.warmup = max(0, warmup)
        this.target = max(1, frames)
    }

    func onFrame(ctx: UiContext): Unit {
        if (done) {
            return
        }
        match ((scroll, sweep)) {
            case (Some(offset), Some(motion)) => offset.value = motion.next()
            case _ => ()
        }
        let now = PerformanceClock.ticksNanoseconds()
        frame += 1
        // Zero the text-cost counters as measurement begins, so the totals printed at the end cover
        // exactly the measured window: draws scale with frames, shapes (cache misses) should not.
        if (frame == warmup + 1) {
            ctx.renderer.resetTextMeasureCount()
        }
        if (frame == 1) {
            lastTicks = now
            return
        }
        let delta = if (now > lastTicks) {
            now - lastTicks
        } else {
            UInt64(0)
        }
        lastTicks = now
        // Discard warm-up frames (first paint, glyph priming, window settling) before sampling.
        if (frame > warmup + 1) {
            sumNs += delta
            if (delta < minNs) {
                minNs = delta
            }
            if (delta > maxNs) {
                maxNs = delta
            }
            measured += 1
            if (measured >= target) {
                finish(ctx)
            }
        }
    }

    private func finish(ctx: UiContext): Unit {
        done = true
        let avg = if (measured > 0) {
            sumNs / UInt64(measured)
        } else {
            UInt64(0)
        }
        let fps = if (avg > 0) {
            UInt64(1000000000) / avg
        } else {
            UInt64(0)
        }
        println("[bench] ${group} / ${name}: avg ${formatDuration(avg)}/frame (~${fps} fps), min ${formatDuration(minNs)}, max ${formatDuration(maxNs)} over ${measured} frames")
        // The shaped-text cache working: draws grow with the frame count, shapes (TTF_CreateText
        // misses) stay near the working-set size no matter how long the run.
        println("[bench]   文本：${ctx.renderer.textDrawCount()} 次绘制 / ${ctx.renderer.textShapeCount()} 次成形（成形越少＝复用越充分）")
        report("display", group, BenchResult(name, measured, sumNs, 0))
        ctx.requestClose()
    }
}

/** A zero-footprint sibling widget that forwards each frame to the shared accumulator. */
public class BenchDriver <: Widget {
    private let accumulator: BenchAccumulator

    public init(accumulator: BenchAccumulator) {
        this.accumulator = accumulator
        emit(this)
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        match (event) {
            case UiEvent.Frame(_) => accumulator.onFrame(ctx)
            case _ => ()
        }
        false
    }

    public func measure(_: UiContext, _: Size): Size {
        Size.zero()
    }

    public func layout(_: UiContext, _: Rect): Unit {}

    public func draw(_: UiContext): Unit {}

    public func participatesInLayout(): Bool {
        false
    }
}
