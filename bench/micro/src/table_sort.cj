/*
 * Scenario: Table's sort, which runs on every draw while a sort column is active (see
 * src/controls/table.cj displayOrder). Drawing is windowed, so this isolates the sort itself. Both
 * a text column and a numeric column are measured, since numeric sorting parses cell strings into
 * numbers. An edge set covers the empty table, a single row, and the all-equal-keys worst case
 * where the sort touches every element yet never reorders.
 */
package bench_micro

import cui.{MouseButton, Rect, State, Table, TableColumn, UiContext, UiEvent}
import bench_scenes.{makeEqualKeyRows, makeTableRows}
import bench_harness.{printSection, report, timeit}

private func columns(): Array<TableColumn> {
    [
        TableColumn("Host", 180.0),
        TableColumn("Score", 100.0, numeric: true),
        TableColumn("Region", 140.0),
        TableColumn("Uptime", 140.0)
    ]
}

// Builds a table over `rows` and activates a sort on the column under `headerX`, ready for draws.
private func sortedTable(rows: Array<Array<String>>, headerX: Float32): (Table, UiContext) {
    let ctx = headlessContext()
    let table = Table(columns(), rows, State<Int64>(-1), key: "bench")
    table.layout(ctx, Rect(0.0, 0.0, 560.0, 480.0))
    let _ = table.handle(ctx, UiEvent.MouseDown(MouseButton.Left, headerX, 10.0)) // activate sort
    (table, ctx)
}

public func runTableSortBench(rowCount: Int64, frames: Int64): Unit {
    printSection("表格每帧排序（${rowCount} 行）")
    let rows = makeTableRows(rowCount)
    let group = "表格排序 ${rowCount} 行"
    let (textTable, textCtx) = sortedTable(rows, 20.0) // Host column (text, x in [0, 180))
    report("frame", group, timeit("文本列", frames, {=> textTable.draw(textCtx); 0}))
    let (numericTable, numericCtx) = sortedTable(rows, 220.0) // Score column (numeric, x in [180, 280))
    report("frame", group, timeit("数值列", frames, {=> numericTable.draw(numericCtx); 0}))
}

public func runTableEdgeBench(): Unit {
    printSection("表格排序边界")
    let (empty, emptyCtx) = sortedTable(makeTableRows(0), 20.0)
    report("frame", "表格排序边界", timeit("空表", 200, {=> empty.draw(emptyCtx); 0}))
    let (single, singleCtx) = sortedTable(makeTableRows(1), 20.0)
    report("frame", "表格排序边界", timeit("单行", 200, {=> single.draw(singleCtx); 0}))
    let (equal, equalCtx) = sortedTable(makeEqualKeyRows(2000), 220.0)
    report("frame", "表格排序边界", timeit("2000 行等键值", 60, {=> equal.draw(equalCtx); 0}))
}
