/*
 * End-to-end (display) benchmark for the planner right-panel scroll that felt janky. It animates
 * the same content-scroll scene the headless benchmark measures (bench_scenes.contentScrollScene),
 * sweeping the offset up and down automatically, and measures the real per-frame cost.
 *
 * A BenchDriver sibling runs a bounded number of frames and then closes the window on its own, so
 * the benchmark is self-terminating and self-measuring — no human has to read a meter. Unlike the
 * headless run, this rebuilds the tree every frame against a real renderer, so every Label
 * re-measures through SDL_ttf and visible text is rasterised: exactly the cost headless (estimated
 * text) cannot see. frameDelay is 0, so the measured interval is the real per-frame work; the
 * shipping DesktopApp additionally sleeps ~16ms/frame, so the felt rate is lower still.
 *
 * Run: cd bench/planner_scroll && cjpm run
 */
package bench_planner_scroll

import cui.{DesktopApp, FontSizes, Label, LengthUnits, Panel, State, VStack, WindowSpec}
import bench_scenes.{BenchAccumulator, BenchDriver, contentScrollScene}
import bench_harness.ScrollSweep

private let BLOCKS = 16
private let SCROLL_STEP: Float32 = 24.0
private let SCROLL_SPAN: Float32 = 3200.0

main(): Int64 {
    let scroll = State<Float32>(0.0)
    let sweep = ScrollSweep(SCROLL_SPAN, SCROLL_STEP)
    let accumulator = BenchAccumulator(group: "内容页滚动（上机实测）", name: "${BLOCKS} 区块", scroll: scroll,
        sweep: sweep, frames: 150)
    let app = DesktopApp(WindowSpec("CUI bench: planner scroll", 1120, 720, scale: 1.5), frameDelay: 0)
    app.setMinimumSize(760, 560)
    app.run {
        BenchDriver(accumulator)
        plannerScrollView(scroll)
    }
    return 0
}

func plannerScrollView(scroll: State<Float32>): Unit {
    VStack {
        Label("规划台滚动基准：右栏内容自动上下滚动，跑满固定帧数后自动退出。").fontSize(FontSizes.BODY)
        Panel {
            contentScrollScene(scroll, BLOCKS)
        }.contentPadding(18.vp).flex()
    }.spacing(14.vp).padding(18.vp)
}
