/*
 * Scenario: scrolling a long composed page (the shape of the planner overview / preferences pane).
 * ScrollView does not window generic container content, so every descendant is measured, laid out
 * and drawn each frame regardless of visibility — the per-frame cost scales with total content, not
 * with the viewport. This is the headless (CPU-only) half of the planner-scroll investigation; the
 * display counterpart under bench/planner_scroll adds the real text rasterisation cost.
 */
package bench_micro

import cui.{Rect, State}
import bench_scenes.contentScrollScene
import bench_harness.{ScrollSweep, printSection, report, timeit}

public func runContentScrollBench(): Unit {
    printSection("内容页滚动（未窗口化的组合内容）")
    measureContentScroll("12 区块", 12, 120)
    measureContentScroll("48 区块", 48, 40)
}

private func measureContentScroll(name: String, blocks: Int64, frames: Int64): Unit {
    let ctx = headlessContext()
    let rect = Rect(0.0, 0.0, 720.0, 560.0)
    let scroll = State<Float32>(0.0)
    let scene = contentScrollScene(scroll, blocks)
    scene.layout(ctx, rect) // establish content height before sweeping
    let sweep = ScrollSweep(Float32(blocks) * 220.0, 40.0)
    // A faithful frame: advance the offset, then re-layout and re-draw the whole page.
    report("frame", "内容页滚动", timeit(name, frames, {=>
        scroll.value = sweep.next()
        ctx.renderer.beginScene(rect.w, rect.h, ctx.theme.bg)
        scene.layout(ctx, rect)
        scene.draw(ctx)
        ctx.renderer.endScene()
        0
    }))
}
