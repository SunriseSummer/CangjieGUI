/*
 * Diagnostic: how many text measurements a tree performs per frame, and how many survive the
 * renderer's cross-frame metrics cache. The per-frame rebuild builds fresh widgets every frame, so
 * each Label's own cache is cold and every visible string is requested anew; the shared metrics
 * cache (keyed by point size + text) then serves the repeats. The request count is the same
 * headless or on a display, and the surviving computations equal the SDL_ttf calls on a display —
 * so this localises and quantifies a text-bound cost, such as the planner-scroll frame rate,
 * without opening a window.
 *
 * Each scene is warmed with one render, then a second freshly-built render (cold instance caches) is
 * measured: requests are the raw call volume, computations are the misses left after the cache.
 */
package bench_micro

import cui.{ListView, Rect, State, Table, TableColumn, UiContext, Widget}
import bench_scenes.{contentScrollScene, lazyContentScrollScene, makeListItems, makeTableRows}
import bench_harness.{printSection, reportCount}

public func runTextMeasureDiag(): Unit {
    printSection("每帧文本度量（请求次数 / 暖缓存后实算次数 / 绘制次数）")
    let ctx = headlessContext()
    diagContentPage(ctx, "内容页 16 区块（未窗口化）", 16, false)
    diagContentPage(ctx, "内容页 16 区块（LazyColumn）", 16, true)
    diagContentPage(ctx, "内容页 48 区块（未窗口化）", 48, false)
    diagContentPage(ctx, "内容页 48 区块（LazyColumn）", 48, true)
    diagTable(ctx, "表格 5000 行（窗口化）", 5000)
    diagList(ctx, "长列表 5000 项（窗口化）", 5000)
}

private func diagContentPage(ctx: UiContext, name: String, blocks: Int64, lazy: Bool): Unit {
    let rect = Rect(0.0, 0.0, 720.0, 560.0)
    let scroll = State<Float32>(0.0)
    if (lazy) {
        reportPair(ctx, name, rect) {=> lazyContentScrollScene(scroll, blocks)}
    } else {
        reportPair(ctx, name, rect) {=> contentScrollScene(scroll, blocks)}
    }
}

private func diagTable(ctx: UiContext, name: String, rows: Int64): Unit {
    let rect = Rect(0.0, 0.0, 560.0, 480.0)
    let data = makeTableRows(rows)
    reportPair(ctx, name, rect) {=> Table("diag", diagColumns(), data, State<Int64>(-1))}
}

private func diagList(ctx: UiContext, name: String, count: Int64): Unit {
    let rect = Rect(0.0, 0.0, 360.0, 560.0)
    let items = makeListItems(count)
    reportPair(ctx, name, rect) {=> ListView(items, State<Int64>(-1))}
}

// Warms the shared metrics cache with one render, then measures a second freshly-built render (cold
// instance caches, as a per-frame rebuild yields): requests are the raw call volume, computations
// are the misses left after the cross-frame cache.
private func reportPair(ctx: UiContext, name: String, rect: Rect, build: () -> Widget): Unit {
    renderScene(ctx, rect, build())
    let fresh = build()
    ctx.renderer.resetTextMeasureCount()
    renderScene(ctx, rect, fresh)
    reportCount("每帧文本度量", "${name} · 度量请求", ctx.renderer.textMeasureCount())
    reportCount("每帧文本度量", "${name} · 度量实算(暖缓存)", ctx.renderer.textComputeCount())
    reportCount("每帧文本度量", "${name} · 文本绘制", ctx.renderer.textDrawCount())
}

private func renderScene(ctx: UiContext, rect: Rect, scene: Widget): Unit {
    ctx.renderer.beginScene(rect.w, rect.h, ctx.theme.bg)
    scene.layout(ctx, rect)
    scene.draw(ctx)
    ctx.renderer.endScene()
}

private func diagColumns(): Array<TableColumn> {
    [
        TableColumn("Host", 180.0),
        TableColumn("Score", 100.0, numeric: true),
        TableColumn("Region", 140.0),
        TableColumn("Uptime", 140.0)
    ]
}
