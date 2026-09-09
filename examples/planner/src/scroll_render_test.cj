package cui_planner

import std.fs.{Directory, File}
import cui.{MouseButton, Rect, RetainedTestMode, SdlWindow, UiEvent, WidgetTestHost, WindowSpec}

// Exercises the actual example view, input routing and native GPU rendering. The artifacts
// include full/incremental pairs and both pages at their lower scroll limit.
@Test
func plannerPagesReachTheirLastCardsWithNativeRendering(): Unit {
    let directory = Directory.createTemp("target").toString()
    for (width in [Int32(760), Int32(1120)]) {
        for (sampling in [Int32(1), Int32(2)]) {
            try (window = SdlWindow(WindowSpec("Planner scroll E2E", width, 560, scale: 1.5,
                supersample: sampling, vsync: false), hidden: true)) {
                let renderer = window.renderer
                let bounds = Rect(0.0, 0.0, Float32(width) + 0.5, 560.75)
                renderer.prepareTextLayout(bounds.w, bounds.h)
                for (full in [false, true]) {
                let mode = if (full) { RetainedTestMode.Full } else { RetainedTestMode.Incremental }
                let suffix = if (full) { "full" } else { "incremental" }
                let host = WidgetTestHost(renderer: renderer, theme: plannerTheme(), retainedMode: mode)
                let model = PlannerModel()
                let view: () -> Unit = {=> plannerView(model)}
                try {
                    let _ = host.frame(bounds, body: view)
                    for (page in 0..2) {
                        if (page == 1) {
                            let _ = host.frame(bounds, events: [
                                UiEvent.MouseDown(MouseButton.Left, 110.0, 210.0),
                                UiEvent.MouseUp(MouseButton.Left, 110.0, 210.0)], body: view)
                            @Expect(model.page.value, Int64(1))
                        }
                        let wheel = UiEvent.MouseWheel(0.0, -1000.0, Float32(width) - 100.0, 350.0)
                        let _ = host.frame(bounds, events: [wheel], body: view)
                        let name = "${directory}/page-${page}-${width}-${sampling}-${suffix}"
                        renderer.captureBmp(name + ".bmp")
                        @Expect(plannerBottomBorderVisible(name + ".bmp", bounds))
                        let _ = host.frame(bounds, events: [wheel], body: view)
                        renderer.captureBmp(name + "-edge.bmp")
                        @Expect(samePlannerPixels(name + ".bmp", name + "-edge.bmp"))
                    }
                } finally { host.reset() }
                }
                for (page in 0..2) {
                    let prefix = "${directory}/page-${page}-${width}-${sampling}"
                    @Expect(samePlannerPixels(prefix + "-full.bmp", prefix + "-incremental.bmp"))
                }
            }
        }
    }
    println("@@PLANNER_SCROLL_ARTIFACTS|${directory}")
}

// Check actual bottom-border pixels, away from corners and text. The viewport ends
// 18 vp (root padding) + 18 vp (panel padding) above the bottom of the root frame.
// This assertion catches clipping even when two equally broken snapshots match.
private func plannerBottomBorderVisible(path: String, bounds: Rect): Bool {
    let bytes = File.readFrom(path)
    let pixelOffset = plannerBmpInt(bytes, 10)
    let width = plannerBmpInt(bytes, 18)
    let signedHeight = plannerBmpInt(bytes, 22)
    let height = if (signedHeight < 0) { -signedHeight } else { signedHeight }
    let pixelBytes = (Int64(bytes[28]) + Int64(bytes[29]) * 256) / 8
    if (width <= 0 || height <= 0 || (pixelBytes != 3 && pixelBytes != 4)) { return false }
    let stride = ((width * pixelBytes + 3) / 4) * 4
    let x = Int64(Float32(width) * 350.0 / bounds.w)
    let edge = Float32(height) * (bounds.h - 36.0) / bounds.h
    let start = Int64(edge - Float32(height) * 0.6 / bounds.h)
    var darkest: Int64 = 255
    for (y in start..Int64(edge) + 1) {
        let sourceY = if (signedHeight > 0) { height - 1 - y } else { y }
        let red = Int64(bytes[pixelOffset + sourceY * stride + x * pixelBytes + 2])
        darkest = min(darkest, red)
    }
    darkest < 238 // midpoint between soft-card fill (251) and border (224)
}

private func plannerBmpInt(bytes: Array<UInt8>, index: Int64): Int64 {
    var value: Int64 = 0
    for (i in 0..4) { value += Int64(bytes[index + i]) << (i * 8) }
    if (value >= 2147483648) { value - 4294967296 } else { value }
}

private func samePlannerPixels(left: String, right: String): Bool {
    let a = File.readFrom(left)
    let b = File.readFrom(right)
    if (a.size != b.size) { return false }
    for (i in 0..a.size) { if (a[i] != b[i]) { return false } }
    true
}
