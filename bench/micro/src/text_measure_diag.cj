/*
 * Diagnostic: how many text measurements a tree performs in one frame. The per-frame rebuild model
 * builds fresh widgets every frame, so each Label's own measurement cache is cold and every visible
 * string is measured anew — through SDL_ttf on a display. The count of those measurements is the
 * same headless or on a display (same tree), so it localises a text-bound cost, such as the
 * planner-scroll frame rate, without opening a window: measurements-per-frame times the per-call
 * SDL_ttf cost is the frame's text budget.
 *
 * Note the contrast with the windowed controls: Table and ListView measure only visible rows, while
 * the generic content page measures every descendant. Each scene is built fresh (cold caches) and
 * one frame of layout + draw is counted.
 */
package bench_micro

import cui.{ListView, Rect, State, Table, TableColumn, UiContext}
import bench_scenes.{contentScrollScene, makeListItems, makeTableRows}
import bench_harness.{printSection, reportCount}

public func runTextMeasureDiag(): Unit {
    printSection("每帧文本度量次数（越少越好）")
    diagContentPage("内容页 16 区块（未窗口化）", 16)
    diagContentPage("内容页 48 区块（未窗口化）", 48)
    diagTable("表格 5000 行（窗口化）", 5000)
    diagList("长列表 5000 项（窗口化）", 5000)
}

private func diagContentPage(name: String, blocks: Int64): Unit {
    let ctx = headlessContext()
    let rect = Rect(0.0, 0.0, 720.0, 560.0)
    let scroll = State<Float32>(0.0)
    let scene = contentScrollScene(scroll, blocks) // fresh tree: cold Label caches, as a rebuild yields
    reportCount("每帧文本度量", name, oneFrameMeasureCount(ctx, rect) {=> scene.layout(ctx, rect); scene.draw(ctx)})
}

private func diagTable(name: String, rows: Int64): Unit {
    let ctx = headlessContext()
    let rect = Rect(0.0, 0.0, 560.0, 480.0)
    let table = Table("diag", diagColumns(), makeTableRows(rows), State<Int64>(-1))
    reportCount("每帧文本度量", name, oneFrameMeasureCount(ctx, rect) {=> table.layout(ctx, rect); table.draw(ctx)})
}

private func diagList(name: String, count: Int64): Unit {
    let ctx = headlessContext()
    let rect = Rect(0.0, 0.0, 360.0, 560.0)
    let list = ListView(makeListItems(count), State<Int64>(-1))
    reportCount("每帧文本度量", name, oneFrameMeasureCount(ctx, rect) {=> list.layout(ctx, rect); list.draw(ctx)})
}

// Runs one frame of `render` against a scene bracket and returns the text measurements it performed.
private func oneFrameMeasureCount(ctx: UiContext, rect: Rect, render: () -> Unit): UInt64 {
    ctx.renderer.resetTextMeasureCount()
    ctx.renderer.beginScene(rect.w, rect.h, ctx.theme.bg)
    render()
    ctx.renderer.endScene()
    ctx.renderer.textMeasureCount()
}

private func diagColumns(): Array<TableColumn> {
    [
        TableColumn("Host", 180.0),
        TableColumn("Score", 100.0, numeric: true),
        TableColumn("Region", 140.0),
        TableColumn("Uptime", 140.0)
    ]
}
