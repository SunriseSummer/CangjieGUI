/* Same-process A/B for flat command copying versus stable hierarchical scene references. */
package bench_micro

import cui.{Color, HStack, Panel, Rect, RenderCommandBuffer, RenderCommandSlot, Renderer, RetainedTestMode, Size, State,
    UiContext, UiEvent, VStack, Widget, WidgetTestHost, emit}
import bench_harness.{printSection, report, reportCount, timeit}

private let SCENE_PATCH_CHILDREN: Int64 = 96
private let SCENE_PATCH_COMMANDS_PER_CHILD: Int64 = 24
private let SCENE_PATCH_ITERATIONS: Int64 = 600
private let SCENE_PATCH_UI_REGIONS: Int64 = 48
private let SCENE_PATCH_UI_BRANCHES: Int64 = 8
private let SCENE_PATCH_UI_FRAMES: Int64 = 300

private class ScenePatchUiVisits {
    let values = Array<Int64>(SCENE_PATCH_UI_REGIONS, repeat: 0)

    func reset(): Unit {
        for (index in 0..values.size) {
            values[index] = 0
        }
    }

    func total(): Int64 {
        var result: Int64 = 0
        for (value in values) {
            result += value
        }
        result
    }
}

private class ScenePatchUiDriver {
    private var index: Int64 = 0

    func next(): Int64 {
        let result = index
        index = (index + 1) % SCENE_PATCH_UI_REGIONS
        result
    }
}

private class ScenePatchUiProbe <: Widget {
    private let region: Int64
    private let branch: Int64
    private let value: Int64
    private let visits: ScenePatchUiVisits
    private var frame = Rect.zero()

    init(region: Int64, branch: Int64, value: Int64, visits: ScenePatchUiVisits) {
        this.region = region
        this.branch = branch
        this.value = value
        this.visits = visits
        emit(this)
    }

    public func measure(_: UiContext, available: Size): Size {
        Size(available.w, min(available.h, 4.0))
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        visits.values[region] += 1
        for (command in 0..4) {
            ctx
                .renderer
                .fill(Rect(frame.x + Float32(branch * 4 + command), frame.y, 1.0, 1.0),
                    Color.rgb((region * 17 + value) % 255, (branch * 31) % 255, (command * 47) % 255))
        }
    }

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }
}

public func runScenePatchBench(): Unit {
    printSection("层次化 ScenePatch（同场景 A/B）")
    let renderer = Renderer.headless()
    let children = Array<RenderCommandBuffer>(SCENE_PATCH_CHILDREN, {index => recordScenePatchChild(renderer, index)})
    let slots = Array<RenderCommandSlot>(
        SCENE_PATCH_CHILDREN,
        {
            index =>
                let slot = RenderCommandSlot()
                slot.setReplayBounds(scenePatchChildBounds(index))
                slot.replace(children[index])
                slot
        }
    )
    let flat = recordFlatScene(renderer, children)
    let hierarchical = recordHierarchicalScene(renderer, slots)
    reportCount("层次化 ScenePatch", "flat 父命令数", UInt64(flat.stats().commandCount))
    reportCount("层次化 ScenePatch", "hierarchical 父引用数", UInt64(hierarchical.stats().commandCount))

    let flatRebuild = timeit(
        "96 子树 / flat 父列表重建",
        SCENE_PATCH_ITERATIONS,
        {
            =>
                let rebuilt = recordFlatScene(renderer, children)
                replayRequired(rebuilt, renderer)
                rebuilt.stats().commandCount
        }
    )
    let hierarchicalRebuild = timeit(
        "96 子树 / hierarchical 父列表重建",
        SCENE_PATCH_ITERATIONS,
        {
            =>
                let rebuilt = recordHierarchicalScene(renderer, slots)
                replayRequired(rebuilt, renderer)
                rebuilt.stats().commandCount
        }
    )
    let flatReplay = timeit(
        "2304 命令 / flat 稳定重放",
        SCENE_PATCH_ITERATIONS,
        {
            =>
                replayRequired(flat, renderer)
                flat.stats().commandCount
        }
    )
    let hierarchicalReplay = timeit(
        "2304 命令 / hierarchical 稳定重放",
        SCENE_PATCH_ITERATIONS,
        {
            =>
                replayRequired(hierarchical, renderer)
                hierarchical.stats().commandCount
        }
    )
    let hierarchicalDamage = timeit(
        "2304 命令 / hierarchical 单区域 damage",
        SCENE_PATCH_ITERATIONS,
        {
            =>
                replayIntersectingRequired(hierarchical, renderer, Rect(0.0, 0.0, 24.0, 1.0))
                hierarchical.stats().commandCount
        }
    )
    requireScenePatchCommandEvidence(flatRebuild.perIterationNs(), hierarchicalRebuild.perIterationNs(),
        flatReplay.perIterationNs(), hierarchicalReplay.perIterationNs(), hierarchicalDamage.perIterationNs())
    report("micro", "层次化 ScenePatch", flatRebuild)
    report("micro", "层次化 ScenePatch", hierarchicalRebuild)
    report("micro", "层次化 ScenePatch", flatReplay)
    report("micro", "层次化 ScenePatch", hierarchicalReplay)
    report("micro", "层次化 ScenePatch", hierarchicalDamage)
    let damage256 = runSceneDamageScale(renderer, 256, 300)
    let damage1024 = runSceneDamageScale(renderer, 1024, 150)
    requireSceneDamageScale(damage256, damage1024)
    runScenePatchUiBench()
}

private func runScenePatchUiBench(): Unit {
    let rect = Rect(0.0, 0.0, 720.0, 1200.0)
    let incrementalHost = WidgetTestHost()
    let incrementalStates = Array<State<Int64>>(SCENE_PATCH_UI_REGIONS, {_ => State<Int64>(0)})
    let incrementalVisits = ScenePatchUiVisits()
    let incrementalBody: () -> Unit = {=> buildScenePatchUi(incrementalStates, incrementalVisits)}
    for (_ in 0..5) {
        let _ = incrementalHost.frame(rect, body: incrementalBody)
    }
    incrementalVisits.reset()
    let incrementalDriver = ScenePatchUiDriver()
    let incremental = timeit(
        "48 区域 / 单区域 patch",
        SCENE_PATCH_UI_FRAMES,
        {
            =>
                let index = incrementalDriver.next()
                incrementalStates[index].value += 1
                let result = incrementalHost.frame(rect, body: incrementalBody)
                result.metrics.stabilizationPasses + incrementalVisits.total()
        }
    )
    let incrementalDrawVisits = incrementalVisits.total() / SCENE_PATCH_UI_FRAMES

    let fullHost = WidgetTestHost(retainedMode: RetainedTestMode.Full)
    let fullStates = Array<State<Int64>>(SCENE_PATCH_UI_REGIONS, {_ => State<Int64>(0)})
    let fullVisits = ScenePatchUiVisits()
    let fullBody: () -> Unit = {=> buildScenePatchUi(fullStates, fullVisits)}
    let _ = fullHost.frame(rect, body: fullBody)
    fullVisits.reset()
    let fullDriver = ScenePatchUiDriver()
    let full = timeit(
        "48 区域 / 强制全树",
        SCENE_PATCH_UI_FRAMES,
        {
            =>
                let index = fullDriver.next()
                fullStates[index].value += 1
                let result = fullHost.frame(rect, body: fullBody)
                result.metrics.stabilizationPasses + fullVisits.total()
        }
    )
    let fullDrawVisits = fullVisits.total() / SCENE_PATCH_UI_FRAMES
    requireScenePatchUiEvidence(incremental.perIterationNs(), full.perIterationNs(), incrementalDrawVisits,
        fullDrawVisits)
    report("frame", "层次化 ScenePatch", incremental)
    reportCount("层次化 ScenePatch", "单区域 patch widget 绘制访问", UInt64(incrementalDrawVisits))
    report("frame", "层次化 ScenePatch", full)
    reportCount("层次化 ScenePatch", "强制全树 widget 绘制访问", UInt64(fullDrawVisits))
}

private func requireScenePatchCommandEvidence(
    flatRebuild: UInt64,
    hierarchicalRebuild: UInt64,
    flatReplay: UInt64,
    hierarchicalReplay: UInt64,
    hierarchicalDamage: UInt64
): Unit {
    if (hierarchicalRebuild * UInt64(2) > flatRebuild) {
        throw IllegalStateException("Hierarchical ScenePatch parent rebuild did not reach the 2x gate")
    }
    if (hierarchicalReplay > flatReplay + UInt64(5000)) {
        throw IllegalStateException("Hierarchical ScenePatch added more than 5 us to stable replay")
    }
    if (hierarchicalDamage > hierarchicalReplay + UInt64(5000)) {
        throw IllegalStateException("Hierarchical damage culling added more than 5 us to the same full replay")
    }
}

private func runSceneDamageScale(renderer: Renderer, count: Int64, iterations: Int64): UInt64 {
    let children = Array<RenderCommandBuffer>(count, {index => recordScenePatchChild(renderer, index)})
    let slots = Array<RenderCommandSlot>(
        count,
        {
            index =>
                let slot = RenderCommandSlot()
                slot.setReplayBounds(scenePatchChildBounds(index))
                slot.replace(children[index])
                slot
        }
    )
    let scene = recordHierarchicalScene(renderer, slots)
    let full = timeit(
        "${count} 子树 / hierarchical 全重放",
        iterations,
        {
            =>
                replayRequired(scene, renderer)
                scene.stats().commandCount
        }
    )
    let damage = timeit(
        "${count} 子树 / hierarchical 单区域 damage",
        iterations,
        {
            =>
                replayIntersectingRequired(scene, renderer, Rect(0.0, 0.0, 24.0, 1.0))
                scene.stats().commandCount
        }
    )
    report("micro", "层次化 ScenePatch", full)
    report("micro", "层次化 ScenePatch", damage)
    damage.perIterationNs()
}

private func requireSceneDamageScale(damage256: UInt64, damage1024: UInt64): Unit {
    if (damage1024 > damage256 * UInt64(3)) {
        throw IllegalStateException("Hierarchical damage query scaled linearly between 256 and 1024 child slots")
    }
}

private func requireScenePatchUiEvidence(
    incremental: UInt64,
    full: UInt64,
    incrementalDrawVisits: Int64,
    fullDrawVisits: Int64
): Unit {
    if (incremental > full) {
        throw IllegalStateException("Element-owned ScenePatch was slower than the same forced-full Widget tree")
    }
    if (incrementalDrawVisits != SCENE_PATCH_UI_BRANCHES || fullDrawVisits != SCENE_PATCH_UI_REGIONS *
        SCENE_PATCH_UI_BRANCHES) {
        throw IllegalStateException(
            "ScenePatch draw frontier changed: patch=${incrementalDrawVisits}, full=${fullDrawVisits}")
    }
}

private func buildScenePatchUi(states: Array<State<Int64>>, visits: ScenePatchUiVisits): Unit {
    VStack {
        for (region in 0..states.size) {
            Panel(flexible: false) {
                let value = states[region].value
                VStack {
                    for (branch in 0..SCENE_PATCH_UI_BRANCHES) {
                        HStack {ScenePatchUiProbe(region, branch, value, visits)}
                    }
                }.spacing(0.0)
            }.height(Float32(SCENE_PATCH_UI_BRANCHES * 4))
        }
    }.spacing(0.0)
}

private func recordScenePatchChild(renderer: Renderer, child: Int64): RenderCommandBuffer {
    renderer.recordCommands {
        for (command in 0..SCENE_PATCH_COMMANDS_PER_CHILD) {
            renderer.fill(Rect(Float32(command), Float32(child), 1.0, 1.0),
                Color.rgb((child * 17) % 255, (child * 31) % 255, (child * 47) % 255))
        }
    }
}

private func scenePatchChildBounds(child: Int64): Rect {
    Rect(0.0, Float32(child), Float32(SCENE_PATCH_COMMANDS_PER_CHILD), 1.0)
}

private func recordFlatScene(renderer: Renderer, children: Array<RenderCommandBuffer>): RenderCommandBuffer {
    renderer.recordCommands {
        for (child in children) {
            replayRequired(child, renderer)
        }
    }
}

private func recordHierarchicalScene(renderer: Renderer, slots: Array<RenderCommandSlot>): RenderCommandBuffer {
    renderer.recordCommands {
        for (slot in slots) {
            if (!slot.replay(renderer)) {
                throw IllegalStateException("ScenePatch benchmark slot became invalid")
            }
        }
    }
}

private func replayRequired(buffer: RenderCommandBuffer, renderer: Renderer): Unit {
    if (!buffer.replay(renderer)) {
        throw IllegalStateException("ScenePatch benchmark command buffer became invalid")
    }
}

private func replayIntersectingRequired(buffer: RenderCommandBuffer, renderer: Renderer, damage: Rect): Unit {
    if (!buffer.replayIntersecting(renderer, damage)) {
        throw IllegalStateException("ScenePatch benchmark culled command buffer became invalid")
    }
}
