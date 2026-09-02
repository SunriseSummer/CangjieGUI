/*
 * Reusable benchmark tooling shared by every workload under `.dev/bench/workloads/`: a nanosecond stopwatch, a
 * timing loop that resists dead-code elimination, and fixed-width reporting. Timing uses the SDL
 * performance clock, so it works headless without a window. Reporting uses integer arithmetic
 * only, so no float formatting is required.
 */
package bench_harness

import std.collection.ArrayList
import std.sort.sort
import sdl.system.PerformanceClock

/** The outcome of one timed benchmark: total nanoseconds over `iterations` runs of the body. */
public struct BenchResult {
    public let name: String
    public let iterations: Int64
    public let totalNs: UInt64
    // A fold of every body return value, carried out of the loop so the optimiser cannot drop it.
    public let checksum: Int64

    public init(name: String, iterations: Int64, totalNs: UInt64, checksum: Int64) {
        this.name = name
        this.iterations = iterations
        this.totalNs = totalNs
        this.checksum = checksum
    }

    /** Average nanoseconds per iteration (0 when nothing ran). */
    public func perIterationNs(): UInt64 {
        if (iterations <= 0) {
            0
        } else {
            totalNs / UInt64(iterations)
        }
    }
}

/** Stable nearest-rank latency summary for one bounded sequence of measured frames. */
public struct FrameDistribution {
    public let samples: Int64
    public let p50Ns: UInt64
    public let p90Ns: UInt64
    public let p95Ns: UInt64
    public let p99Ns: UInt64
    public let maxNs: UInt64
    public let over120FpsBudget: Int64
    public let over60FpsBudget: Int64
    public let over30FpsBudget: Int64

    public init(
        samples: Int64,
        p50Ns: UInt64,
        p90Ns: UInt64,
        p95Ns: UInt64,
        p99Ns: UInt64,
        maxNs: UInt64,
        over120FpsBudget: Int64,
        over60FpsBudget: Int64,
        over30FpsBudget: Int64
    ) {
        this.samples = samples
        this.p50Ns = p50Ns
        this.p90Ns = p90Ns
        this.p95Ns = p95Ns
        this.p99Ns = p99Ns
        this.maxNs = maxNs
        this.over120FpsBudget = over120FpsBudget
        this.over60FpsBudget = over60FpsBudget
        this.over30FpsBudget = over30FpsBudget
    }
}

/** One per-frame timing run with both its compatibility average and within-run distribution. */
public struct SampledBenchResult {
    public let result: BenchResult
    public let distribution: FrameDistribution

    public init(result: BenchResult, distribution: FrameDistribution) {
        this.result = result
        this.distribution = distribution
    }
}

/** Computes nearest-rank percentiles without mutating the caller's sample array. */
public func frameDistribution(samples: Array<UInt64>): FrameDistribution {
    if (samples.isEmpty()) {
        return FrameDistribution(0, 0, 0, 0, 0, 0, 0, 0, 0)
    }
    let ordered = samples.clone()
    sort(ordered)
    var over120: Int64 = 0
    var over60: Int64 = 0
    var over30: Int64 = 0
    for (sample in ordered) {
        if (sample > UInt64(8333333)) {
            over120 += 1
        }
        if (sample > UInt64(16666667)) {
            over60 += 1
        }
        if (sample > UInt64(33333333)) {
            over30 += 1
        }
    }
    FrameDistribution(
        ordered.size,
        nearestRank(ordered, 50),
        nearestRank(ordered, 90),
        nearestRank(ordered, 95),
        nearestRank(ordered, 99),
        ordered[ordered.size - 1],
        over120,
        over60,
        over30
    )
}

private func nearestRank(ordered: Array<UInt64>, percentile: Int64): UInt64 {
    let rank = max(Int64(0), (ordered.size * percentile + 99) / 100 - 1)
    ordered[min(rank, ordered.size - 1)]
}

/*
 * Runs `body` `iterations` times and reports the elapsed time. `body` returns an Int64 that is
 * summed into a checksum carried out of the loop, which keeps the compiler from optimising away a
 * body whose result is otherwise unused. For a body whose work is a side effect (a widget draw),
 * return any cheap value — the side effect already prevents elimination.
 */
public func timeit(name: String, iterations: Int64, body: () -> Int64): BenchResult {
    var checksum: Int64 = 0
    let start = PerformanceClock.ticksNanoseconds()
    var i = 0
    while (i < iterations) {
        checksum += body()
        i += 1
    }
    let end = PerformanceClock.ticksNanoseconds()
    BenchResult(name, iterations, elapsed(start, end), checksum)
}

/** Times each frame separately so tail latency and frame-budget misses remain observable. */
public func sampleFrames(name: String, iterations: Int64, body: () -> Int64): SampledBenchResult {
    let count = max(Int64(0), iterations)
    let samples = ArrayList<UInt64>()
    var checksum: Int64 = 0
    var totalNs: UInt64 = 0
    var i: Int64 = 0
    while (i < count) {
        let start = PerformanceClock.ticksNanoseconds()
        checksum += body()
        let end = PerformanceClock.ticksNanoseconds()
        let sample = elapsed(start, end)
        samples.add(sample)
        totalNs += sample
        i += 1
    }
    SampledBenchResult(BenchResult(name, count, totalNs, checksum), frameDistribution(samples.toArray()))
}

// SDL's tick counter is monotonic; guard against a same-or-backwards reading just in case.
private func elapsed(start: UInt64, end: UInt64): UInt64 {
    if (end > start) {
        end - start
    } else {
        0
    }
}

/*
 * A raw nanosecond timestamp from the SDL performance clock. Exposed for phase-split benchmarks that
 * time the sub-phases of one frame (build / layout / draw) separately, the way the desktop
 * FrameProfiler does, instead of the single elapsed span `timeit` reports.
 */
public func nowNanos(): UInt64 {
    PerformanceClock.ticksNanoseconds()
}

/** The nanoseconds from `start` to `end`, guarding against a same-or-backwards clock reading. */
public func spanNs(start: UInt64, end: UInt64): UInt64 {
    elapsed(start, end)
}

/** Prints a section title with surrounding blank line. */
public func printSection(title: String): Unit {
    println("")
    println("== ${title} ==")
}

/** Prints one result row: a left-padded name and a human-readable per-iteration duration. */
public func printResult(result: BenchResult): Unit {
    println("  ${padRight(result.name, 36)}${formatDuration(result.perIterationNs())}")
}

/** Prints a before/after row with the speedup ratio. */
public func printComparison(label: String, before: BenchResult, after: BenchResult): Unit {
    let beforeText = padRight(formatDuration(before.perIterationNs()), 14)
    let afterText = padRight(formatDuration(after.perIterationNs()), 14)
    println(
        "  ${padRight(label, 36)}${beforeText}-> ${afterText}(${formatRatio(before.perIterationNs(), after.perIterationNs())})")
}

// --- formatting (integer arithmetic only) ---

/*
 * Formats a nanosecond duration adaptively: bare nanoseconds below 10 us, microseconds with two
 * decimals below 10 ms, and milliseconds with three decimals above that.
 */
public func formatDuration(ns: UInt64): String {
    if (ns < UInt64(10000)) {
        "${ns} ns"
    } else if (ns < UInt64(10000000)) {
        "${fixed(ns, UInt64(1000), 2)} us"
    } else {
        "${fixed(ns, UInt64(1000000), 3)} ms"
    }
}

// Renders value/unit with `decimals` fractional digits using integer math.
private func fixed(value: UInt64, unit: UInt64, decimals: Int64): String {
    var scale: UInt64 = 1
    var d = 0
    while (d < decimals) {
        scale *= UInt64(10)
        d += 1
    }
    let scaled = value * scale / unit
    "${scaled / scale}.${padZeros(scaled % scale, decimals)}"
}

private func formatRatio(beforeNs: UInt64, afterNs: UInt64): String {
    if (afterNs == UInt64(0)) {
        "n/a"
    } else {
        let hundredths = beforeNs * UInt64(100) / afterNs
        "${hundredths / UInt64(100)}.${padZeros(hundredths % UInt64(100), 2)}x"
    }
}

private func padZeros(value: UInt64, width: Int64): String {
    let text = "${value}"
    var pad = ""
    var n = width - text.size
    while (n > 0) {
        pad = pad + "0"
        n -= 1
    }
    pad + text
}

private func padRight(text: String, width: Int64): String {
    var result = text
    var n = width - text.size
    while (n > 0) {
        result = result + " "
        n -= 1
    }
    result
}

// --- machine-readable output + reusable drivers ---

/*
 * Emits a result in both forms: the human-readable console row, plus a machine-readable line the
 * report generator (`python .dev/cli.py bench run`) parses into the HTML summary. The machine line is
 *   @@RESULT|<kind>|<group>|<name>|<nsPerIteration>|<iterations>
 * `kind` is "frame" (a per-frame cost, judged against the frame budget) or "micro" (an isolated
 * operation, judged on raw throughput). `group` and `name` must not contain '|'.
 */
public func report(kind: String, group: String, result: BenchResult): Unit {
    printResult(result)
    println("@@RESULT|${kind}|${group}|${result.name}|${result.perIterationNs()}|${result.iterations}")
}

/*
 * Emits the within-run latency distribution for a display benchmark. This is intentionally a
 * separate record from @@RESULT so existing parsers keep accepting the average result while newer
 * tooling can judge tail latency and budget misses:
 *   @@FRAME_DIST|group|name|p50|p90|p95|p99|max|over120|over60|over30|samples
 */
public func reportFrameDistribution(group: String, name: String, distribution: FrameDistribution): Unit {
    println(
        "@@FRAME_DIST|${group}|${name}|${distribution.p50Ns}|${distribution.p90Ns}|${distribution.p95Ns}|${distribution.p99Ns}|${distribution.maxNs}|${distribution.over120FpsBudget}|${distribution.over60FpsBudget}|${distribution.over30FpsBudget}|${distribution.samples}")
}

/** Emits the actual display backend used by one benchmark case. */
public func reportBenchmarkEnvironment(
    group: String,
    name: String,
    driver: String,
    supersample: Int32,
    vsync: Int32
): Unit {
    println("@@BENCH_ENV|${group}|${name}|${driver}|${supersample}|${vsync}")
}

/*
 * Emits a per-frame count metric (for example, text measurements performed in one frame) rather
 * than a timing. The report shows these as a diagnostic: the count of measurements a tree performs
 * per frame is identical headless and on a display, so it localises a text-bound cost without a
 * window. The machine line is @@COUNT|<group>|<name>|<count>.
 */
public func reportCount(group: String, name: String, count: UInt64): Unit {
    println("  ${padRight(name, 36)}${count} 次/帧")
    println("@@COUNT|${group}|${name}|${count}")
}

/*
 * A ping-pong scroll-offset source for frame-cost benchmarks: each `next()` advances the offset by
 * `step`, reversing at 0 and `maxOffset`, so successive frames sweep the content up and down as a
 * user dragging the bar would. A class rather than a captured local because a benchmark body is a
 * single-expression lambda and cannot mutate captured variables.
 */
public class ScrollSweep {
    private let maxOffset: Float32
    private let step: Float32
    private var current: Float32 = 0.0
    private var rising: Bool = true

    public init(maxOffset: Float32, step: Float32) {
        this.maxOffset = max(0.0, maxOffset)
        this.step = max(0.0, step)
    }

    /** The next offset along the sweep. */
    public func next(): Float32 {
        if (rising) {
            current += step
            if (current >= maxOffset) {
                current = maxOffset
                rising = false
            }
        } else {
            current -= step
            if (current <= 0.0) {
                current = 0.0
                rising = true
            }
        }
        current
    }
}
