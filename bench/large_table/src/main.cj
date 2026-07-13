/*
 * End-to-end (display) benchmark: a full DesktopApp showing a large, sortable Table with real text
 * rendering. A BenchDriver sibling runs a bounded number of frames and closes the window on its
 * own, measuring the real per-frame cost of drawing the windowed table (visible rows only) against
 * SDL_ttf. Click a header to sort and scroll to feel the sort cost interactively; the automated
 * number here is the steady windowed-draw cost. frameDelay is 0 so the measured interval is the
 * real per-frame work.
 *
 * Run: cd bench/large_table && cjpm run
 */
package bench_large_table

import cui.{DesktopApp, FontSizes, Label, LengthUnits, State, Table, TableColumn, VStack, WindowSpec}
import bench_scenes.{BenchAccumulator, BenchDriver, makeTableRows}

private let ROW_COUNT = 5000

private func columns(): Array<TableColumn> {
    [
        TableColumn("Host", 180.0),
        TableColumn("Score", 100.0, numeric: true),
        TableColumn("Region", 140.0),
        TableColumn("Uptime", 140.0)
    ]
}

main(): Int64 {
    let rows = makeTableRows(ROW_COUNT)
    let selected = State<Int64>(-1)
    let accumulator = BenchAccumulator(group: "大表绘制（上机实测）", name: "${ROW_COUNT} 行窗口化", frames: 150)
    let app = DesktopApp(WindowSpec("CUI bench: large sorted table", 720, 560), frameDelay: 0)
    app.setMinimumSize(560, 400)
    app.run {
        BenchDriver(accumulator)
        largeTableView(rows, selected)
    }
    return 0
}

func largeTableView(rows: Array<Array<String>>, selected: State<Int64>): Unit {
    VStack {
        Label("大表滚动帧率基准：跑满固定帧数后自动退出（可手动点击列头排序、滚动体感）。").fontSize(FontSizes.BODY)
        Table("bench.table", columns(), rows, selected).flex()
    }.spacing(12.vp).padding(16.vp)
}
