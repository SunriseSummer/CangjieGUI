/*
 * Scenario: scrolling a long composed page (the shape of the planner overview / preferences pane),
 * rebuilding the tree every frame as the real loop does. Two variants are compared:
 *
 *  - unwindowed (ScrollView + VStack): every block is built, laid out and drawn each frame, so cost
 *    scales with total content;
 *  - LazyColumn: only the rows near the viewport are built, so cost is O(visible) and flat as the
 *    list grows.
 *
 * This is the headless (CPU-only) half; text rasterisation cost is measured on a display by
 * bench/planner_scroll. See also the text-measurement diagnostic for the per-frame draw counts.
 */
package bench_micro

import cui.{Rect, State, Widget}
import bench_scenes.{contentScrollScene, lazyContentScrollScene}
import bench_harness.{ScrollSweep, printSection, report, timeit}

public func runContentScrollBench(): Unit {
    printSection("内容页滚动（每帧重建：未窗口化 vs LazyColumn）")
    measureContentScroll("12 区块 未窗口化", 12, 120, false)
    measureContentScroll("12 区块 LazyColumn", 12, 120, true)
    measureContentScroll("48 区块 未窗口化", 48, 40, false)
    measureContentScroll("48 区块 LazyColumn", 48, 120, true)
}

private func measureContentScroll(name: String, blocks: Int64, frames: Int64, lazy: Bool): Unit {
    let ctx = headlessContext()
    let rect = Rect(0.0, 0.0, 720.0, 560.0)
    let scroll = State<Float32>(0.0)
    let sweep = ScrollSweep(Float32(blocks) * 300.0, 40.0)
    // A faithful frame: advance the offset, rebuild the tree (so the lazy window recomputes), then
    // lay out and draw. Rebuilding each frame is what the real per-frame loop does.
    report("frame", "内容页滚动", timeit(name, frames, {=>
        scroll.value = sweep.next()
        let scene = buildScene(scroll, blocks, lazy)
        ctx.renderer.beginScene(rect.w, rect.h, ctx.theme.bg)
        scene.layout(ctx, rect)
        scene.draw(ctx)
        ctx.renderer.endScene()
        0
    }))
}

private func buildScene(scroll: State<Float32>, blocks: Int64, lazy: Bool): Widget {
    if (lazy) {
        lazyContentScrollScene(scroll, blocks)
    } else {
        contentScrollScene(scroll, blocks)
    }
}
