/*
 * Scenario: scrolling a large multi-line document in a TextArea (read-only, as a log or document
 * viewer). Only the visible lines are painted, but the per-frame cost still grows with the document
 * size: textContentHeight and drawLines each re-split the whole text every frame (see
 * src/text/text_area.cj). Splitting is already the fast primitive here — the string benchmark shows
 * stdlib split beats a hand byte-scan — so the opportunity is caching the split result across frames
 * (keyed by text revision), not re-counting it differently. Measuring 3000 against 30000 lines makes
 * that O(document) growth visible.
 */
package bench_micro

import cui.{Rect, State, TextArea}
import bench_scenes.makeDocument
import bench_harness.{ScrollSweep, printSection, report, timeit}

public func runTextBench(): Unit {
    printSection("文本区域滚动（窗口化绘制）")
    measureTextArea("3000 行文档", 3000, 200)
    measureTextArea("30000 行文档", 30000, 200)
}

private func measureTextArea(name: String, lines: Int64, frames: Int64): Unit {
    let ctx = headlessContext()
    let rect = Rect(0.0, 0.0, 640.0, 480.0)
    let document = State<String>(makeDocument(lines))
    let scroll = State<Float32>(0.0)
    let area = TextArea(document, key: "bench.area", scroll: scroll, editable: false)
    area.layout(ctx, rect)
    let sweep = ScrollSweep(Float32(lines) * 18.0, 72.0)
    report("frame", "文本区域滚动", timeit(name, frames, {=>
        scroll.value = sweep.next()
        ctx.renderer.beginScene(rect.w, rect.h, ctx.theme.bg)
        area.layout(ctx, rect)
        area.draw(ctx)
        ctx.renderer.endScene()
        0
    }))
}
