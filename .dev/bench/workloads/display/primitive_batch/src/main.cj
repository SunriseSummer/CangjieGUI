/*
 * Same 2048 rectangles and final pixels, submitted either as ordinary calls or through a recorded
 * command buffer whose contiguous same-colour run becomes one SDL_RenderFillRects call. No command
 * reordering is permitted; this isolates driver-call amortisation from scene construction.
 */
package bench_primitive_batch

import std.collection.ArrayList
import sdl.{Color, Rect, RenderCommandBuffer, Renderer, SdlWindow, WindowSpec}
import bench_harness.{report, reportBenchmarkEnvironment, reportCount, reportFrameDistribution, sampleFrames}

private let RECT_COUNT: Int64 = 2048
private let FRAMES: Int64 = 80

main(): Int64 {
    let window = SdlWindow(WindowSpec("CUI bench: primitive batch", 720, 480, vsync: false, supersample: 1))
    try {
        let renderer = window.renderer
        let color = Color.rgb(55, 125, 220)
        let rects = makeRects()
        let buffer = renderer.recordCommands {
            for (rect in rects) {
                renderer.fill(rect, color)
            }
        }
        for (_ in 0..10) {
            drawDirect(renderer, rects, color)
            drawRecorded(renderer, buffer)
        }
        let direct = sampleFrames("2048 rect 单条提交", FRAMES, {=>
            drawDirect(renderer, rects, color)
            RECT_COUNT
        })
        let batched = sampleFrames("2048 rect 相邻批处理", FRAMES, {=>
            drawRecorded(renderer, buffer)
            RECT_COUNT
        })
        report("display", "原语提交（上机实测）", direct.result)
        reportFrameDistribution("原语提交（上机实测）", direct.result.name, direct.distribution)
        reportBenchmarkEnvironment("原语提交（上机实测）", direct.result.name, renderer.driverName(),
            renderer.supersampleFactor(), renderer.vsync())
        report("display", "原语提交（上机实测）", batched.result)
        reportFrameDistribution("原语提交（上机实测）", batched.result.name, batched.distribution)
        reportBenchmarkEnvironment("原语提交（上机实测）", batched.result.name, renderer.driverName(),
            renderer.supersampleFactor(), renderer.vsync())
        let stats = buffer.stats()
        reportCount("原语批处理", "native batch", stats.batchSubmissionCount)
        reportCount("原语批处理", "batched commands", stats.batchedCommandCount)
    } finally {
        window.close()
    }
    return 0
}

private func makeRects(): Array<Rect> {
    let rects = ArrayList<Rect>()
    for (index in 0..RECT_COUNT) {
        let column = index % 64
        let row = (index / 64) % 32
        rects.add(Rect(Float32(column) * 11.0, Float32(row) * 14.0, 9.0, 11.0))
    }
    rects.toArray()
}

private func drawDirect(renderer: Renderer, rects: Array<Rect>, color: Color): Unit {
    renderer.beginScene(720.0, 480.0, Color.rgb(248, 249, 251))
    for (rect in rects) {
        renderer.fill(rect, color)
    }
    renderer.endScene()
}

private func drawRecorded(renderer: Renderer, buffer: RenderCommandBuffer): Unit {
    renderer.beginScene(720.0, 480.0, Color.rgb(248, 249, 251))
    let _ = buffer.replay(renderer)
    renderer.endScene()
}
