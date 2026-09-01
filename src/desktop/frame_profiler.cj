package cui.desktop

import std.collection.ArrayList
import std.sort.sort
import sdl.system.PerformanceClock

private let PERCENTILE_50: Int64 = 50
private let PERCENTILE_90: Int64 = 90
private let PERCENTILE_95: Int64 = 95
private let PERCENTILE_99: Int64 = 99
private let NANOSECONDS_PER_HUNDREDTH_MILLISECOND: UInt64 = UInt64(10000)
private let HUNDREDTHS_PER_MILLISECOND: UInt64 = UInt64(100)
private let DECIMAL_RADIX: UInt64 = UInt64(10)

class FramePhaseTimes {
    let build: UInt64
    let layout: UInt64
    let event: UInt64
    let semantics: UInt64
    let begin: UInt64
    let tree: UInt64
    let resolve: UInt64
    let present: UInt64

    init(
        build: UInt64,
        layout: UInt64,
        event: UInt64,
        semantics: UInt64,
        begin: UInt64,
        tree: UInt64,
        resolve: UInt64,
        present: UInt64
    ) {
        this.build = build
        this.layout = layout
        this.event = event
        this.semantics = semantics
        this.begin = begin
        this.tree = tree
        this.resolve = resolve
        this.present = present
    }

    func total(): UInt64 {
        build + layout + event + semantics + begin + tree + resolve + present
    }
}

class FrameProfileSignals {
    let passes: Int64
    let input: Bool
    let state: Bool
    let timer: Bool
    let resized: Bool
    let forced: Bool
    let frameSubscribers: Int64
    let partialDamage: Bool

    init(
        passes: Int64,
        input: Bool,
        state: Bool,
        timer: Bool,
        resized: Bool,
        forced: Bool,
        frameSubscribers: Int64,
        partialDamage: Bool
    ) {
        this.passes = passes
        this.input = input
        this.state = state
        this.timer = timer
        this.resized = resized
        this.forced = forced
        this.frameSubscribers = frameSubscribers
        this.partialDamage = partialDamage
    }
}

class FrameTextCounts {
    let measures: UInt64
    let computes: UInt64
    let shapes: UInt64
    let draws: UInt64

    init(measures: UInt64, computes: UInt64, shapes: UInt64, draws: UInt64) {
        this.measures = measures
        this.computes = computes
        this.shapes = shapes
        this.draws = draws
    }
}

class FrameProfileSample {
    let phases: FramePhaseTimes
    let signals: FrameProfileSignals
    let text: FrameTextCounts

    init(phases: FramePhaseTimes, signals: FrameProfileSignals, text: FrameTextCounts) {
        this.phases = phases
        this.signals = signals
        this.text = text
    }
}

/*
 * Per-phase frame timing for the desktop loop, enabled with the `--profile` command-line flag so it
 * costs nothing in a normal run (no flag, no profiler instance, no clock reads). It splits the frame
 * into its real phases — tree rebuild, layout, event dispatch, semantics/platform commit, scene
 * setup, tree draw, supersample resolve, and present — and prints the averages every `interval` frames, so a slow frame can be
 * attributed to a specific phase instead of guessed at. DesktopApp avoids these clock reads entirely
 * when profiling is disabled.
 */
class FrameProfiler {
    private let interval: Int64
    private var frames: Int64 = 0
    private var buildNs: UInt64 = 0
    private var layoutNs: UInt64 = 0
    private var eventNs: UInt64 = 0
    private var semanticsNs: UInt64 = 0
    private var beginNs: UInt64 = 0
    private var treeNs: UInt64 = 0
    private var resolveNs: UInt64 = 0
    private var presentNs: UInt64 = 0
    private let frameTotals = ArrayList<UInt64>()
    private var stabilizationPasses: Int64 = 0
    private var maxStabilizationPasses: Int64 = 0
    private var inputFrames: Int64 = 0
    private var stateFrames: Int64 = 0
    private var timerFrames: Int64 = 0
    private var resizeFrames: Int64 = 0
    private var forcedFrames: Int64 = 0
    private var frameSubscribers: Int64 = 0
    private var partialDamageFrames: Int64 = 0
    private var textMeasures: UInt64 = 0
    private var textComputes: UInt64 = 0
    private var textShapes: UInt64 = 0
    private var textDraws: UInt64 = 0

    init(interval: Int64) {
        this.interval = max(1, interval)
    }

    static func now(): UInt64 {
        PerformanceClock.ticksNanoseconds()
    }

    // Adds one frame's sample and prints a rolling report every `interval`.
    func record(sample: FrameProfileSample): Unit {
        addPhases(sample.phases)
        addSignals(sample.signals)
        addText(sample.text)
        frames += 1
        if (frames >= interval) {
            report()
            reset()
        }
    }

    private func addPhases(phases: FramePhaseTimes): Unit {
        buildNs += phases.build
        layoutNs += phases.layout
        eventNs += phases.event
        semanticsNs += phases.semantics
        beginNs += phases.begin
        treeNs += phases.tree
        resolveNs += phases.resolve
        presentNs += phases.present
        frameTotals.add(phases.total())
    }

    private func addSignals(signals: FrameProfileSignals): Unit {
        stabilizationPasses += signals.passes
        maxStabilizationPasses = max(maxStabilizationPasses, signals.passes)
        inputFrames += if (signals.input) {
            1
        } else {
            0
        }
        stateFrames += if (signals.state) {
            1
        } else {
            0
        }
        timerFrames += if (signals.timer) {
            1
        } else {
            0
        }
        resizeFrames += if (signals.resized) {
            1
        } else {
            0
        }
        forcedFrames += if (signals.forced) {
            1
        } else {
            0
        }
        frameSubscribers += signals.frameSubscribers
        partialDamageFrames += if (signals.partialDamage) {
            1
        } else {
            0
        }
    }

    private func addText(text: FrameTextCounts): Unit {
        textMeasures += text.measures
        textComputes += text.computes
        textShapes += text.shapes
        textDraws += text.draws
    }

    private func report(): Unit {
        let n = UInt64(frames)
        let total = buildNs + layoutNs + eventNs + semanticsNs + beginNs + treeNs + resolveNs + presentNs
        let ordered = frameTotals.toArray()
        sort(ordered)
        let p50 = percentileOfSorted(ordered, PERCENTILE_50)
        let p90 = percentileOfSorted(ordered, PERCENTILE_90)
        let p95 = percentileOfSorted(ordered, PERCENTILE_95)
        let p99 = percentileOfSorted(ordered, PERCENTILE_99)
        let maximum = maxSample(ordered)
        println(
            "[profile] 每帧均值（${frames} 帧）：总 ${ms(total, n)} ＝ 构建 ${ms(buildNs, n)} ｜ 布局 ${ms(layoutNs, n)} ｜ 事件 ${ms(eventNs, n)} ｜ 语义提交 ${ms(semanticsNs, n)} ｜ 起帧 ${ms(beginNs, n)} ｜ 绘树 ${ms(treeNs, n)} ｜ 降采样 ${ms(resolveNs, n)} ｜ 呈现 ${ms(presentNs, n)}")
        println(
            "[profile] 延迟分布：P50 ${ms(p50, UInt64(1))} ｜ P90 ${ms(p90, UInt64(1))} ｜ P95 ${ms(p95, UInt64(1))} ｜ P99 ${ms(p99, UInt64(1))} ｜ 最大 ${ms(maximum, UInt64(1))} ｜ 稳定化 ${fixedAverage(stabilizationPasses, frames)} 次/帧（最大 ${maxStabilizationPasses}）")
        println(
            "[profile] 触发帧（可重叠）：输入 ${inputFrames} ｜ 状态 ${stateFrames} ｜ 计时/动画 ${timerFrames} ｜ 尺寸 ${resizeFrames} ｜ 强制 ${forcedFrames}")
        println(
            "[profile] Frame 显式订阅者/帧：${fixedAverage(frameSubscribers, frames)} ｜ retained 局部 damage 帧 ${partialDamageFrames}")
        println(
            "[profile] 文本/帧：度量 ${integerAverage(textMeasures, n)} ｜ 实算 ${integerAverage(textComputes, n)} ｜ 塑形 ${integerAverage(textShapes, n)} ｜ 绘制 ${integerAverage(textDraws, n)}")
        println(
            "@@FRAME_PROFILE|frames=${frames}|total_avg_ns=${integerAverage(total, n)}|p50_ns=${p50}|p90_ns=${p90}|p95_ns=${p95}|p99_ns=${p99}|max_ns=${maximum}|build_avg_ns=${integerAverage(buildNs, n)}|layout_avg_ns=${integerAverage(layoutNs, n)}|event_avg_ns=${integerAverage(eventNs, n)}|semantics_avg_ns=${integerAverage(semanticsNs, n)}|begin_avg_ns=${integerAverage(beginNs, n)}|tree_avg_ns=${integerAverage(treeNs, n)}|resolve_avg_ns=${integerAverage(resolveNs, n)}|present_avg_ns=${integerAverage(presentNs, n)}|stabilization_passes=${stabilizationPasses}|max_stabilization_passes=${maxStabilizationPasses}|input_frames=${inputFrames}|state_frames=${stateFrames}|timer_frames=${timerFrames}|resize_frames=${resizeFrames}|forced_frames=${forcedFrames}|frame_subscribers=${frameSubscribers}|partial_damage_frames=${partialDamageFrames}|text_measures=${textMeasures}|text_computes=${textComputes}|text_shapes=${textShapes}|text_draws=${textDraws}")
    }

    private func reset(): Unit {
        frames = 0
        buildNs = 0
        layoutNs = 0
        eventNs = 0
        semanticsNs = 0
        beginNs = 0
        treeNs = 0
        resolveNs = 0
        presentNs = 0
        frameTotals.clear()
        stabilizationPasses = 0
        maxStabilizationPasses = 0
        inputFrames = 0
        stateFrames = 0
        timerFrames = 0
        resizeFrames = 0
        forcedFrames = 0
        frameSubscribers = 0
        partialDamageFrames = 0
        textMeasures = 0
        textComputes = 0
        textShapes = 0
        textDraws = 0
    }

    // Formats an accumulated nanosecond sum as a per-frame millisecond average with two decimals.
    private func ms(sum: UInt64, n: UInt64): String {
        if (n == 0) {
            return "0.00ms"
        }
        let hundredths = (sum / n) / NANOSECONDS_PER_HUNDREDTH_MILLISECOND
        let whole = hundredths / HUNDREDTHS_PER_MILLISECOND
        let frac = hundredths % HUNDREDTHS_PER_MILLISECOND
        let fracText = if (frac < DECIMAL_RADIX) {
            "0${frac}"
        } else {
            "${frac}"
        }
        "${whole}.${fracText}ms"
    }

    private func integerAverage(sum: UInt64, n: UInt64): UInt64 {
        if (n == UInt64(0)) {
            UInt64(0)
        } else {
            sum / n
        }
    }

    private func fixedAverage(sum: Int64, n: Int64): String {
        if (n <= 0) {
            return "0.00"
        }
        let hundredths = sum * 100 / n
        let fraction = hundredths % 100
        "${hundredths / 100}.${if (fraction < 10) { "0${fraction}" } else { "${fraction}" }}"
    }
}

internal func percentileOfSorted(sorted: Array<UInt64>, percent: Int64): UInt64 {
    if (sorted.isEmpty()) {
        return UInt64(0)
    }
    let rank = max(Int64(0), (sorted.size * percent + 99) / 100 - 1)
    sorted[min(rank, sorted.size - 1)]
}

private func maxSample(samples: Array<UInt64>): UInt64 {
    var maximum: UInt64 = 0
    for (sample in samples) {
        maximum = max(maximum, sample)
    }
    maximum
}
