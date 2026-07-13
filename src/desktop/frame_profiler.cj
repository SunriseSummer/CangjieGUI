package cui.desktop

import sdl.system.PerformanceClock

/*
 * Per-phase frame timing for the desktop loop, enabled with the `--profile` command-line flag so it
 * costs nothing in a normal run (no flag, no profiler instance, no clock reads). It splits the frame
 * into its real phases — tree rebuild, layout, event dispatch, scene setup, tree draw, supersample
 * resolve, and present — and prints the averages every `interval` frames, so a slow frame can be
 * attributed to a specific phase instead of guessed at.
 */
class FrameProfiler {
    private let interval: Int64
    private var frames: Int64 = 0
    private var buildNs: UInt64 = 0
    private var layoutNs: UInt64 = 0
    private var eventNs: UInt64 = 0
    private var beginNs: UInt64 = 0
    private var treeNs: UInt64 = 0
    private var resolveNs: UInt64 = 0
    private var presentNs: UInt64 = 0

    init(interval: Int64) {
        this.interval = max(1, interval)
    }

    static func now(): UInt64 {
        PerformanceClock.ticksNanoseconds()
    }

    // Adds one frame's phase durations (nanoseconds) and prints a rolling average every `interval`.
    func record(
        build: UInt64,
        layout: UInt64,
        event: UInt64,
        begin: UInt64,
        tree: UInt64,
        resolve: UInt64,
        present: UInt64
    ): Unit {
        buildNs += build
        layoutNs += layout
        eventNs += event
        beginNs += begin
        treeNs += tree
        resolveNs += resolve
        presentNs += present
        frames += 1
        if (frames >= interval) {
            report()
            reset()
        }
    }

    private func report(): Unit {
        let n = UInt64(frames)
        let total = buildNs + layoutNs + eventNs + beginNs + treeNs + resolveNs + presentNs
        println("[profile] 每帧均值（${frames} 帧）：总 ${ms(total, n)} ＝ 构建 ${ms(buildNs, n)} ｜ 布局 ${ms(layoutNs, n)} ｜ 事件 ${ms(eventNs, n)} ｜ 起帧 ${ms(beginNs, n)} ｜ 绘树 ${ms(treeNs, n)} ｜ 降采样 ${ms(resolveNs, n)} ｜ 呈现 ${ms(presentNs, n)}")
    }

    private func reset(): Unit {
        frames = 0
        buildNs = 0
        layoutNs = 0
        eventNs = 0
        beginNs = 0
        treeNs = 0
        resolveNs = 0
        presentNs = 0
    }

    // Formats an accumulated nanosecond sum as a per-frame millisecond average with two decimals.
    private func ms(sum: UInt64, n: UInt64): String {
        if (n == 0) {
            return "0.00ms"
        }
        let hundredths = (sum / n) / UInt64(10000) // ns -> 0.01ms units
        let whole = hundredths / UInt64(100)
        let frac = hundredths % UInt64(100)
        let fracText = if (frac < UInt64(10)) {
            "0${frac}"
        } else {
            "${frac}"
        }
        "${whole}.${fracText}ms"
    }
}
