/*
 * Scenario: scrolling a long ListView. Unlike the generic content page, ListView windows its rows —
 * only the visible slice is drawn — so the per-frame cost should stay roughly flat as the item
 * count grows. Measuring 5000 against 50000 items makes that windowing visible (or exposes it if it
 * regresses).
 */
package bench_micro

import cui.{ListView, Rect, State}
import bench_scenes.makeListItems
import bench_harness.{ScrollSweep, printSection, report, timeit}

public func runListBench(): Unit {
    printSection("长列表滚动（窗口化绘制）")
    measureList("5000 项", 5000, 200)
    measureList("50000 项", 50000, 200)
}

private func measureList(name: String, count: Int64, frames: Int64): Unit {
    let ctx = headlessContext()
    let rect = Rect(0.0, 0.0, 360.0, 560.0)
    let scroll = State<Float32>(0.0)
    let selected = State<Int64>(-1)
    let list = ListView(makeListItems(count), selected, scroll: scroll)
    list.layout(ctx, rect)
    let sweep = ScrollSweep(Float32(count) * 24.0, 96.0)
    report("frame", "长列表滚动", timeit(name, frames, {=>
        scroll.value = sweep.next()
        ctx.renderer.beginScene(rect.w, rect.h, ctx.theme.bg)
        list.draw(ctx)
        ctx.renderer.endScene()
        0
    }))
}
