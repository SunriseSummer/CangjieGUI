/*
 * Reusable benchmark tooling shared by every bench under `bench/`: a nanosecond stopwatch, a
 * timing loop that resists dead-code elimination, and fixed-width reporting. Timing uses the SDL
 * performance clock, so it works headless without a window. Reporting uses integer arithmetic
 * only, so no float formatting is required.
 */
package bench_harness

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

// SDL's tick counter is monotonic; guard against a same-or-backwards reading just in case.
private func elapsed(start: UInt64, end: UInt64): UInt64 {
    if (end > start) {
        end - start
    } else {
        0
    }
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
    println("  ${padRight(label, 36)}${beforeText}-> ${afterText}(${formatRatio(before.perIterationNs(), after.perIterationNs())})")
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
