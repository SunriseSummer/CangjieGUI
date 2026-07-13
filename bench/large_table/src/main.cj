/*
 * End-to-end (display) benchmark: a full DesktopApp showing a large, sortable Table. Click a
 * column header to activate sorting, then scroll — the per-frame sort cost surfaces as a reduced
 * frame rate, printed to the console once per second by the in-app FPS meter. Unlike the headless
 * micro-benchmarks, this exercises real text rendering, so it needs a display.
 *
 * Run: cd bench/large_table && cjpm run
 */
package bench_large_table

import std.collection.ArrayList
import cui.{DesktopApp, FontSizes, FrameHandler, FrameInfo, Label, LengthUnits, State, Table, TableColumn, VStack,
    WindowSpec}
import bench_harness.formatDuration

private let ROW_COUNT = 5000

// Accumulates frames over a one-second window and prints the rate. A reference type because the
// per-frame callback mutates it.
class FpsMeter {
    private var frames: Int64 = 0
    private var windowStartMs: UInt64 = 0
    private var started = false

    func tick(info: FrameInfo): Unit {
        if (!started) {
            windowStartMs = info.elapsedMs
            started = true
            return
        }
        frames += 1
        let elapsed = info.elapsedMs - windowStartMs
        if (elapsed >= UInt64(1000) && frames > 0) {
            let fps = UInt64(frames) * UInt64(1000) / elapsed
            let perFrameNs = elapsed * UInt64(1000000) / UInt64(frames)
            println("[fps] ~${fps} frames/s (avg ${formatDuration(perFrameNs)}/frame over ${frames} frames)")
            frames = 0
            windowStartMs = info.elapsedMs
        }
    }
}

private func makeRows(n: Int64): Array<Array<String>> {
    let rows = ArrayList<Array<String>>()
    var i = 0
    while (i < n) {
        let score = (i * 48271) % 100000
        rows.add(["host-${i}", "${score}", "region-${i % 12}", "up ${i % 720} h"])
        i += 1
    }
    rows.toArray()
}

private func columns(): Array<TableColumn> {
    [
        TableColumn("Host", 180.0),
        TableColumn("Score", 100.0, numeric: true),
        TableColumn("Region", 140.0),
        TableColumn("Uptime", 140.0)
    ]
}

main(): Int64 {
    let meter = FpsMeter()
    let rows = makeRows(ROW_COUNT)
    let selected = State<Int64>(-1)
    let app = DesktopApp(WindowSpec("CUI bench: large sorted table", 720, 560))
    app.setMinimumSize(560, 400)
    app.run {
        FrameHandler(onFrame: {info => meter.tick(info)}) {
            largeTableView(rows, selected)
        }
    }
    return 0
}

func largeTableView(rows: Array<Array<String>>, selected: State<Int64>): Unit {
    VStack {
        Label("大表滚动帧率基准：点击列头排序后滚动，控制台每秒打印 [fps]。").fontSize(FontSizes.BODY)
        Table("bench.table", columns(), rows, selected).flex()
    }.spacing(12.vp).padding(16.vp)
}
