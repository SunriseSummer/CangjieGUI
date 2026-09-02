/*
 * Deterministic data generators shared across benchmarks. Every value is derived from its index
 * with no randomness, so each run measures the identical workload and results stay comparable over
 * time. Sizes of zero yield empty collections, so callers can reuse these for edge-case scenes.
 */
package bench_scenes

import std.collection.ArrayList

/*
 * Table rows shaped [host, score, region, uptime]. `score` is scrambled by a large multiplier so a
 * sort does real comparisons instead of walking a pre-ordered fast path.
 */
public func makeTableRows(n: Int64): Array<Array<String>> {
    let rows = ArrayList<Array<String>>()
    var i = 0
    while (i < n) {
        let score = (i * 48271) % 100000
        rows.add(["host-${i}", "${score}", "region-${i % 12}", "up ${i % 720} h"])
        i += 1
    }
    rows.toArray()
}

/*
 * Table rows whose sort key is identical in every row, so a sort touches every element yet never
 * reorders — the worst case for a comparison sort that cannot early-exit.
 */
public func makeEqualKeyRows(n: Int64): Array<Array<String>> {
    let rows = ArrayList<Array<String>>()
    var i = 0
    while (i < n) {
        rows.add(["host-${i}", "5000", "region-0", "up 1 h"])
        i += 1
    }
    rows.toArray()
}

/** Single-column list items for ListView benchmarks. */
public func makeListItems(n: Int64): Array<String> {
    let items = ArrayList<String>()
    var i = 0
    while (i < n) {
        items.add("第 ${i} 项 · 会后确认空状态与键盘路径")
        i += 1
    }
    items.toArray()
}

/** A multi-line document of `lines` lines for TextArea benchmarks. */
public func makeDocument(lines: Int64): String {
    let builder = StringBuilder()
    var i = 0
    while (i < lines) {
        builder.append("第 ")
        builder.append(i)
        builder.append(" 行：the quick brown fox jumps over the lazy dog")
        if (i < lines - 1) {
            builder.append("\n")
        }
        i += 1
    }
    builder.toString()
}
