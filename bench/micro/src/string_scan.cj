/*
 * Scenario: string-operation costs in this runtime. Records a repeatedly-observed characteristic
 * — per-byte String indexing (bounds-checked) is costly, so a hand-rolled byte scan can lose to
 * the heavily optimised stdlib `split`, and string-interpolation key building is not free. These
 * numbers are why the TextArea line-window and text-metrics-cache changes were measured and
 * reverted (see done.md).
 */
package bench_micro

import bench_harness.{printResult, printSection, timeit}

private func buildDocument(lines: Int64): String {
    let builder = StringBuilder()
    var i = 0
    while (i < lines) {
        builder.append("row ")
        builder.append(i)
        builder.append(": the quick brown fox jumps over the lazy dog")
        if (i < lines - 1) {
            builder.append("\n")
        }
        i += 1
    }
    builder.toString()
}

// Counts newlines by direct byte scan — the hand-rolled alternative to splitting.
private func scanLineCount(text: String): Int64 {
    var count: Int64 = 1
    var i = 0
    while (i < text.size) {
        if (text[i] == UInt8(10)) {
            count += 1
        }
        i += 1
    }
    count
}

public func runStringScanBench(): Unit {
    printSection("String operations")
    let document = buildDocument(3000)
    let reps = 500
    // Counting lines: stdlib split versus a hand-rolled byte scan over the same document.
    printResult(timeit("stdlib split.size (3000 lines)", reps, {=> document.split("\n").size}))
    printResult(timeit("hand byte-scan line count", reps, {=> scanLineCount(document)}))
    // Interpolated key build, as a per-call metrics-cache key would do.
    let size: Float32 = 15.0
    let label = "Menu Item Label"
    printResult(timeit("interp key build", 100000, {=> "${size}#${label}".size}))
}
