/*
 * End-to-end (display) benchmark for a controls-dense settings page — the scenario that most
 * exercises the interactive controls' geometry (circles for switch/radio/slider knobs, rounded rects
 * for panels and buttons). It auto-scrolls the page and measures the real per-frame cost, mirroring
 * the planner-scroll benchmark for the panel/shadow case.
 *
 * Arguments (via cjpm's --run-args):
 *   --run-args "24"          section count (default 40)
 *   --run-args "ss1"         supersample factor 1 (off); ss2 is the default
 *   --run-args "--profile"   per-phase frame breakdown (build/layout/draw/resolve/present)
 *
 * Run: cd bench/controls_form && cjpm run                        (default 40 sections)
 *      cd bench/controls_form && cjpm run --run-args "--profile" (per-phase timing)
 */
package bench_controls_form

import std.env.getCommandLine
import cui.{DesktopApp, State, WindowSpec}
import bench_scenes.{BenchAccumulator, BenchDriver, controlsFormScene}
import bench_harness.ScrollSweep

private let DEFAULT_SECTIONS = 40
private let SCROLL_STEP: Float32 = 24.0
private let SCROLL_SPAN: Float32 = 6000.0

main(): Int64 {
    let sections = sectionsArgument()
    let supersample = supersampleArgument()
    let scroll = State<Float32>(0.0)
    let sweep = ScrollSweep(SCROLL_SPAN, SCROLL_STEP)
    let accumulator = BenchAccumulator(group: "控件密集表单（上机实测）", name: "${sections} 分区 ss${supersample}x",
        scroll: scroll, sweep: sweep, frames: 150)
    // vsync off + frameDelay 0 so the measured frame period is true per-frame work.
    let app = DesktopApp(
        WindowSpec("CUI bench: controls form", 640, 720, vsync: false, supersample: supersample),
        frameDelay: 0)
    app.setMinimumSize(480, 480)
    app.run {
        BenchDriver(accumulator)
        controlsFormScene(scroll, sections)
    }
    return 0
}

private func sectionsArgument(): Int64 {
    for (arg in getCommandLine()) {
        let value = parsePositiveInt(arg)
        if (value > 0) {
            return value
        }
    }
    DEFAULT_SECTIONS
}

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
