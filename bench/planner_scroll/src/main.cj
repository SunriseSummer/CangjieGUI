/*
 * End-to-end (display) benchmark for the planner right-panel scroll that felt janky. It animates
 * the same content-scroll scene the headless benchmark measures (bench_scenes.contentScrollScene),
 * sweeping the offset up and down automatically, and measures the real per-frame cost.
 *
 * A BenchDriver sibling runs a bounded number of frames and then closes the window on its own, so
 * the benchmark is self-terminating and self-measuring. frameDelay is 0, so the measured interval is
 * the real per-frame work.
 *
 * Arguments are passed through cjpm's `--run-args`:
 *   --run-args "8"          block count (default 16)
 *   --run-args "ss1"        supersample factor 1 (off); ss2 is the default — isolates fill cost
 *   --run-args "--profile"  per-phase frame breakdown (build/layout/draw/resolve/present)
 * combine freely, e.g. --run-args "8 ss1 --profile".
 *
 * Run: cd bench/planner_scroll && cjpm run                        (default 16 blocks)
 *      cd bench/planner_scroll && cjpm run --run-args "--profile" (per-phase timing)
 */
package bench_planner_scroll

import std.env.getCommandLine
import cui.{DesktopApp, FontSizes, Label, LengthUnits, Panel, State, VStack, WindowSpec}
import bench_scenes.{BenchAccumulator, BenchDriver, lazyContentScrollScene}
import bench_harness.ScrollSweep

private let DEFAULT_BLOCKS = 16
private let SCROLL_STEP: Float32 = 24.0
private let SCROLL_SPAN: Float32 = 3200.0

main(): Int64 {
    let blocks = blocksArgument()
    let supersample = supersampleArgument()
    let scroll = State<Float32>(0.0)
    let sweep = ScrollSweep(SCROLL_SPAN, SCROLL_STEP)
    let accumulator = BenchAccumulator(group: "内容页滚动（上机实测）", name: "${blocks} 区块 ss${supersample}x", scroll: scroll,
        sweep: sweep, frames: 150)
    // vsync off + frameDelay 0 so the measured frame period is true per-frame work, not a refresh
    // multiple — otherwise every result snaps to 60/30/20/15 fps and sub-refresh gains are invisible.
    // Pass `ss1`/`ss2` to isolate the supersample fill cost, `--profile` for a per-phase breakdown.
    let app = DesktopApp(
        WindowSpec("CUI bench: planner scroll", 1120, 720, scale: 1.5, vsync: false, supersample: supersample),
        frameDelay: 0)
    app.setMinimumSize(760, 560)
    app.run {
        BenchDriver(accumulator)
        plannerScrollView(scroll, blocks)
    }
    return 0
}

func plannerScrollView(scroll: State<Float32>, blocks: Int64): Unit {
    VStack {
        Label("规划台滚动基准：右栏内容（LazyColumn 虚拟化）自动上下滚动，跑满固定帧数后自动退出。").fontSize(FontSizes.BODY)
        Panel {
            lazyContentScrollScene(scroll, blocks)
        }.contentPadding(18.vp).flex()
    }.spacing(14.vp).padding(18.vp)
}

// Reads the first all-digit argument as the block count, defaulting when none is given.
private func blocksArgument(): Int64 {
    let args = getCommandLine()
    var i = 1
    while (i < args.size) {
        let value = parsePositiveInt(args[i])
        if (value > 0) {
            return value
        }
        i += 1
    }
    DEFAULT_BLOCKS
}

// Reads a supersample factor from a `ssN` argument (e.g. `ss1`, `ss2`), defaulting to 2. Isolates
// the supersample fill cost: `ss1` turns it off, so the difference from `ss2` is that cost alone.
private func supersampleArgument(): Int32 {
    for (arg in getCommandLine()) {
        if (arg.size == 3 && arg[0] == UInt8(115) && arg[1] == UInt8(115)) { // "ss" + one digit
            let digit = arg[2]
            if (digit >= UInt8(49) && digit <= UInt8(57)) {
                return Int32(digit - UInt8(48))
            }
        }
    }
    2
}

private func parsePositiveInt(text: String): Int64 {
    if (text.isEmpty()) {
        return -1
    }
    var n: Int64 = 0
    var i = 0
    while (i < text.size) {
        let b = text[i]
        if (b < UInt8(48) || b > UInt8(57)) {
            return -1
        }
        n = n * 10 + Int64(b - UInt8(48))
        i += 1
    }
    n
}
