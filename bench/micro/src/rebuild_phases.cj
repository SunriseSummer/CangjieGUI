/*
 * Phase split of the per-frame rebuild loop. The real desktop loop rebuilds the whole widget tree
 * every frame, then lays it out, then draws it; FrameProfiler attributes each frame to those phases
 * on a display. This headless bench does the same split deterministically, so the share spent in
 * 构建 (tree construction) — the phase an incremental-rebuild optimization removes — can be read
 * directly rather than guessed at from the bundled build+layout+draw of the content-scroll bench.
 *
 * Method: for each frame, time construction, layout and draw as three separate spans on the same
 * tree (each phase feeds the next, so nothing is dead-code eliminated), and report the per-frame
 * average of each. The scene is rebuilt every frame exactly as the loop does.
 */
package bench_micro

import cui.{Rect, State, UiContext, Widget}
import bench_scenes.{contentScrollScene, controlsFormScene}
import bench_harness.{BenchResult, ScrollSweep, nowNanos, printSection, report, spanNs}

public func runRebuildPhaseBench(): Unit {
    printSection("每帧重建相分解（构建 / 布局 / 绘树）")
    measureRebuildPhases("内容页 12 区块", 12, 120, false)
    measureRebuildPhases("内容页 48 区块", 48, 40, false)
    measureRebuildPhases("控件表单 12 分区", 12, 120, true)
    measureRebuildPhases("控件表单 40 分区", 40, 40, true)
}

private func measureRebuildPhases(name: String, count: Int64, frames: Int64, form: Bool): Unit {
    let ctx = headlessContext()
    let rect = Rect(0.0, 0.0, 720.0, 640.0)
    let scroll = State<Float32>(0.0)
    let sweep = ScrollSweep(Float32(count) * 300.0, 40.0)
    var buildNs: UInt64 = 0
    var layoutNs: UInt64 = 0
    var drawNs: UInt64 = 0
    var i = 0
    while (i < frames) {
        scroll.value = sweep.next()
        let t0 = nowNanos()
        let scene = buildRebuildScene(scroll, count, form)
        let t1 = nowNanos()
        ctx.renderer.beginScene(rect.w, rect.h, ctx.theme.bg)
        scene.layout(ctx, rect)
        let t2 = nowNanos()
        scene.draw(ctx)
        ctx.renderer.endScene()
        let t3 = nowNanos()
        buildNs += spanNs(t0, t1)
        layoutNs += spanNs(t1, t2)
        drawNs += spanNs(t2, t3)
        i += 1
    }
    report("frame", "每帧重建相分解", BenchResult("${name} 构建", frames, buildNs, 0))
    report("frame", "每帧重建相分解", BenchResult("${name} 布局", frames, layoutNs, 0))
    report("frame", "每帧重建相分解", BenchResult("${name} 绘树", frames, drawNs, 0))
}

private func buildRebuildScene(scroll: State<Float32>, count: Int64, form: Bool): Widget {
    if (form) {
        controlsFormScene(scroll, count)
    } else {
        contentScrollScene(scroll, count)
    }
}

/*
 * Isolates the layout cost of instance reuse on the identical scene. Both paths share a ctx whose
 * text-measurement cache is warmed before timing, so the only difference is whether the widget tree
 * (and its per-instance measure caches — Label's wrapped lines and text width) is rebuilt fresh each
 * frame or reused. The gap is what an incremental rebuild that reuses unchanged instances (Tier 1)
 * could recover in the layout phase, which the phase split shows dominates the frame.
 */
public func runInstanceReuseBench(): Unit {
    printSection("实例复用对布局的影响（同一场景：每帧重建 vs 复用实例）")
    measureReuseAB("内容页 12 区块", 12, 120, false)
    measureReuseAB("内容页 48 区块", 48, 40, false)
    measureReuseAB("控件表单 12 分区", 12, 120, true)
    measureReuseAB("控件表单 40 分区", 40, 40, true)
}

private func measureReuseAB(name: String, count: Int64, frames: Int64, form: Bool): Unit {
    let rect = Rect(0.0, 0.0, 720.0, 640.0)
    let cold = measureColdLayout(count, frames, form, rect)
    let warm = measureWarmLayout(count, frames, form, rect)
    report("frame", "实例复用-布局", BenchResult("${name} 每帧重建", frames, cold, 0))
    report("frame", "实例复用-布局", BenchResult("${name} 复用实例", frames, warm, 0))
}

// Layout time when the tree is rebuilt every frame (cold per-instance caches; ctx cache warm).
private func measureColdLayout(count: Int64, frames: Int64, form: Bool, rect: Rect): UInt64 {
    let ctx = headlessContext()
    let scroll = State<Float32>(0.0)
    let sweep = ScrollSweep(Float32(count) * 300.0, 40.0)
    // Prime the ctx text-measurement cache so the timed loop measures only per-instance cache misses.
    primeFrame(ctx, buildRebuildScene(scroll, count, form), rect)
    var layoutNs: UInt64 = 0
    var i = 0
    while (i < frames) {
        scroll.value = sweep.next()
        let scene = buildRebuildScene(scroll, count, form)
        ctx.renderer.beginScene(rect.w, rect.h, ctx.theme.bg)
        let t0 = nowNanos()
        scene.layout(ctx, rect)
        let t1 = nowNanos()
        scene.draw(ctx)
        ctx.renderer.endScene()
        layoutNs += spanNs(t0, t1)
        i += 1
    }
    layoutNs
}

// Layout time when a single tree is reused every frame (warm per-instance caches).
private func measureWarmLayout(count: Int64, frames: Int64, form: Bool, rect: Rect): UInt64 {
    let ctx = headlessContext()
    let scroll = State<Float32>(0.0)
    let sweep = ScrollSweep(Float32(count) * 300.0, 40.0)
    let scene = buildRebuildScene(scroll, count, form)
    primeFrame(ctx, scene, rect) // warms both the ctx cache and the tree's per-instance caches
    var layoutNs: UInt64 = 0
    var i = 0
    while (i < frames) {
        scroll.value = sweep.next()
        ctx.renderer.beginScene(rect.w, rect.h, ctx.theme.bg)
        let t0 = nowNanos()
        scene.layout(ctx, rect)
        let t1 = nowNanos()
        scene.draw(ctx)
        ctx.renderer.endScene()
        layoutNs += spanNs(t0, t1)
        i += 1
    }
    layoutNs
}

private func primeFrame(ctx: UiContext, scene: Widget, rect: Rect): Unit {
    ctx.renderer.beginScene(rect.w, rect.h, ctx.theme.bg)
    scene.layout(ctx, rect)
    scene.draw(ctx)
    ctx.renderer.endScene()
}
