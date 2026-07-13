/*
 * Scenario: the per-frame cost of Table's sort, which runs on every draw while a sort column is
 * active (see src/controls/table.cj displayOrder). Drawing is windowed, so this isolates the
 * sort. Both a text column and a numeric column are measured, since numeric sorting parses cell
 * strings into numbers.
 */
package bench_micro

import std.collection.ArrayList
import cui.{MouseButton, Rect, Renderer, State, Table, TableColumn, Theme, UiContext, UiEvent}
import bench_harness.{printResult, printSection, timeit}

private func makeRows(n: Int64): Array<Array<String>> {
    let rows = ArrayList<Array<String>>()
    var i = 0
    while (i < n) {
        // A shuffled-looking key so the sort does real comparisons, not a pre-sorted fast path.
        let key = (i * 48271) % 100000
        rows.add(["item ${i}", "${key}", "row ${i} payload"])
        i += 1
    }
    rows.toArray()
}

// Builds a table and activates a sort on the column under `headerX`, ready for repeated draws.
private func sortedTable(rowCount: Int64, headerX: Float32): (Table, UiContext) {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let columns = [
        TableColumn("Name", 160.0),
        TableColumn("Score", 80.0, numeric: true),
        TableColumn("Note", 200.0)
    ]
    let table = Table("bench", columns, makeRows(rowCount), State<Int64>(-1))
    table.layout(ctx, Rect(0.0, 0.0, 440.0, 400.0))
    let _ = table.handle(ctx, UiEvent.MouseDown(MouseButton.Left, headerX, 10.0)) // activate sort
    (table, ctx)
}

public func runTableSortBench(rowCount: Int64, frames: Int64): Unit {
    printSection("Table per-frame sort (${rowCount} rows)")
    let (textTable, textCtx) = sortedTable(rowCount, 20.0) // Name column (text, x in [0,160))
    printResult(timeit("text column", frames, {=> textTable.draw(textCtx); 0}))
    let (numericTable, numericCtx) = sortedTable(rowCount, 200.0) // Score column (numeric, [160,240))
    printResult(timeit("numeric column", frames, {=> numericTable.draw(numericCtx); 0}))
}
