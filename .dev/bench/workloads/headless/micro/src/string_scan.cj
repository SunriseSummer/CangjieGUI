/*
 * Scenario: string-operation costs in this runtime. Records a repeatedly-observed characteristic —
 * per-byte String indexing (bounds-checked) is costly, so a hand-rolled byte scan can lose to the
 * heavily optimised stdlib `split`, and string-interpolation key building is not free. These
 * numbers are why the TextArea line-window and text-metrics-cache changes were measured rather than
 * assumed (see .todo/done.md).
 */
package bench_micro

import bench_scenes.makeDocument
import bench_harness.{printSection, report, timeit}

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
    printSection("字符串操作")
    let document = makeDocument(3000)
    let reps = 500
    // Counting lines: stdlib split versus a hand-rolled byte scan over the same document.
    report("micro", "字符串", timeit("split.size（3000 行）", reps, {=> document.split("\n").size}))
    report("micro", "字符串", timeit("手写字节扫描计行", reps, {=> scanLineCount(document)}))
    // Interpolated key build, as a per-call metrics-cache key would do.
    let size: Float32 = 15.0
    let label = "Menu Item Label"
    report("micro", "字符串", timeit("插值构键", 100000, {=> "${size}#${label}".size}))
}
