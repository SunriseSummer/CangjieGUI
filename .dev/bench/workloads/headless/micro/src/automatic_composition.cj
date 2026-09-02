/*
 * A/B guard for framework-managed composition. Both sides use ordinary UI code with no retained
 * wrapper or revision. Incremental mode updates one State-backed branch; full mode executes every
 * declarative body, making the ratio a direct guard for automatic dirty-path selection.
 */
package bench_micro

import cui.{Color, EffectCleanup, HStack, Label, Panel, Rect, RetainedSubtree, RetainedTestMode, Size, Spacer, State,
    UiContext, UiEvent, VStack, Widget, WidgetTestHost, emit, lifecycleEffect, mountEffect, rememberState}
import bench_harness.{BenchResult, printSection, report, reportCount, timeit}

private let AUTOMATIC_ROW_COUNT: Int64 = 240
private let AUTOMATIC_FRAME_COUNT: Int64 = 500
private let AUTOMATIC_PAINT_FRAME_COUNT: Int64 = 1000
private let AUTOMATIC_LAYOUT_FRAME_COUNT: Int64 = 1000
private let AUTOMATIC_PAINT_NODE_COUNT: Int64 = 96
private let AUTOMATIC_LAYOUT_NODE_COUNT: Int64 = 24
private let DECLARATION_COUNT: Int64 = 128
private let DECLARATION_FRAME_COUNT: Int64 = 500
private let REMEMBER_SLOT_COUNT: Int64 = 256
private let REMEMBER_FRAME_COUNT: Int64 = 500

private class DeclarationScene {
    let externallyRevisioned: Bool
    let positional: Bool
    var bodyBuilds: Int64 = 0

    init(externallyRevisioned: Bool, positional: Bool) {
        this.externallyRevisioned = externallyRevisioned
        this.positional = positional
    }

    func build(): Unit {
        bodyBuilds += 1
        for (index in 0..DECLARATION_COUNT) {
            if (externallyRevisioned) {
                if (positional) {
                    lifecycleEffect(UInt64(0), {=> EffectCleanup({=> ()})})
                } else {
                    lifecycleEffect("effect-${index}", UInt64(0), {=> EffectCleanup({=> ()})})
                }
            } else {
                if (positional) {
                    mountEffect({=> EffectCleanup({=> ()})})
                } else {
                    mountEffect("effect-${index}", {=> EffectCleanup({=> ()})})
                }
            }
        }
        if (externallyRevisioned) {
            RetainedSubtree("retained", UInt64(0)) {Spacer()}
        } else {
            RetainedSubtree("retained") {Spacer()}
        }
    }
}

private class BuildPhaseTotal {
    var ns: UInt64 = UInt64(0)

    func add(value: UInt64): Unit {
        ns += value
    }
}

private class AutomaticPaintBenchProbe <: Widget {
    private let scene: AutomaticPaintScene
    private var frame = Rect.zero()

    init(scene: AutomaticPaintScene) {
        this.scene = scene
        emit(this)
    }

    public func measure(_: UiContext, available: Size): Size {
        Size(available.w, min(available.h, 6.0))
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        scene.paintVisits += 1
        ctx.renderer.fill(frame, Color.rgb(40, 80, 120))
    }

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }
}

private class AutomaticPaintScene {
    var paintVisits: Int64 = 0

    func build(): Unit {
        VStack {
            for (_ in 0..AUTOMATIC_PAINT_NODE_COUNT) {
                AutomaticPaintBenchProbe(this)
            }
        }.spacing(0.0)
    }
}

private class AutomaticLayoutScene {
    let changing = State<Int64>(0)
    var layoutVisits: Int64 = 0

    func build(): Unit {
        VStack {
            Panel(flexible: false) {
                VStack {
                    for (_ in 0..AUTOMATIC_LAYOUT_NODE_COUNT) {
                        Panel(flexible: false) {AutomaticLayoutBenchProbe(this)}
                    }
                }.spacing(0.0)
            }.height(600.0)
            HStack {Label("changing ${changing.value}")}
        }
    }
}

private class AutomaticLayoutBenchProbe <: Widget {
    private let scene: AutomaticLayoutScene

    init(scene: AutomaticLayoutScene) {
        this.scene = scene
        emit(this)
    }

    public func measure(_: UiContext, available: Size): Size {
        Size(available.w, min(available.h, 12.0))
    }

    public func layout(_: UiContext, _: Rect): Unit {
        scene.layoutVisits += 1
    }

    public func draw(_: UiContext): Unit {}

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }
}

private class AutomaticScene {
    let values = Array<State<Int64>>(AUTOMATIC_ROW_COUNT, {_ => State<Int64>(0)})
    let bodyBuilds = Array<Int64>(AUTOMATIC_ROW_COUNT, {_ => Int64(0)})
    private var nextIndex: Int64 = 0

    func changeNext(): Int64 {
        let index = nextIndex
        values[index].value += 1
        nextIndex = (nextIndex + 1) % values.size
        index
    }

    func build(): Unit {
        VStack {
            var index: Int64 = 0
            while (index < values.size) {
                let row = index
                Panel(flexible: false) {
                    bodyBuilds[row] += 1
                    Label("row ${row}: ${values[row].value}")
                }
                index += 1
            }
        }
    }

    func totalBodyBuilds(): Int64 {
        var total: Int64 = 0
        for (builds in bodyBuilds) {
            total += builds
        }
        total
    }
}

private class RememberSlotScene {
    private let positional: Bool
    var initializations: Int64 = 0
    var checksum: Int64 = 0

    init(positional: Bool) {
        this.positional = positional
    }

    func build(): Unit {
        var total: Int64 = 0
        for (index in 0..REMEMBER_SLOT_COUNT) {
            let state = if (positional) {
                rememberState<Int64> {
                    initializations += 1
                    index
                }
            } else {
                rememberState<Int64>("bench.remember.${index}") {
                    initializations += 1
                    index
                }
            }
            total += state.value
        }
        checksum = total
        Spacer()
    }
}

public func runAutomaticCompositionBench(): Unit {
    printSection("自动组合脏路径（普通 UI 代码 A/B）")
    let rect = Rect(0.0, 0.0, 720.0, 1800.0)

    let incrementalHost = WidgetTestHost()
    let incrementalScene = AutomaticScene()
    let incrementalBody: () -> Unit = {=> incrementalScene.build()}
    let _ = incrementalHost.frame(rect, body: incrementalBody)
    reportAutomaticScopeFacetShape(incrementalHost)
    let incrementalBefore = incrementalScene.totalBodyBuilds()
    let _ = incrementalScene.changeNext()
    let _ = incrementalHost.frame(rect, body: incrementalBody)
    reportCount("自动组合", "单 State 变更执行分支体", UInt64(incrementalScene.totalBodyBuilds() - incrementalBefore))
    let incrementalBuild = BuildPhaseTotal()
    let incrementalResult = timeit(
        "240 分支 / 单分支变更",
        AUTOMATIC_FRAME_COUNT,
        {
            =>
                let changed = incrementalScene.changeNext()
                let result = incrementalHost.frame(rect, body: incrementalBody)
                incrementalBuild.add(result.metrics.buildNs)
                changed + result.metrics.stabilizationPasses
        }
    )
    report("frame", "自动组合", incrementalResult)
    report("micro", "自动组合构建",
        BenchResult("240 分支 / 单分支变更 build", AUTOMATIC_FRAME_COUNT, incrementalBuild.ns, 0))

    let fullHost = WidgetTestHost(retainedMode: RetainedTestMode.Full)
    let fullScene = AutomaticScene()
    let fullBody: () -> Unit = {=> fullScene.build()}
    let _ = fullHost.frame(rect, body: fullBody)
    let fullBefore = fullScene.totalBodyBuilds()
    let _ = fullScene.changeNext()
    let _ = fullHost.frame(rect, body: fullBody)
    reportCount("自动组合", "强制全量执行分支体", UInt64(fullScene.totalBodyBuilds() - fullBefore))
    let fullBuild = BuildPhaseTotal()
    let fullResult = timeit(
        "240 分支 / 强制全重建",
        AUTOMATIC_FRAME_COUNT,
        {
            =>
                let changed = fullScene.changeNext()
                let result = fullHost.frame(rect, body: fullBody)
                fullBuild.add(result.metrics.buildNs)
                changed + result.metrics.stabilizationPasses
        }
    )
    report("frame", "自动组合", fullResult)
    report("micro", "自动组合构建", BenchResult("240 分支 / 强制全重建 build", AUTOMATIC_FRAME_COUNT, fullBuild.ns, 0))

    runRememberSlotBench(rect)
    runAutomaticPaintBench()
    runAutomaticLayoutBench()
}

private func reportAutomaticScopeFacetShape(host: WidgetTestHost): Unit {
    var ownershipOnly: Int64 = 0
    var dependencyOnly: Int64 = 0
    var both: Int64 = 0
    var empty: Int64 = 0
    for (scope in host.retainedDiagnostics().automaticScopes) {
        let hasOwnership = scope.stateCount + scope.effectCount + scope.retainedChildCount + scope.automaticChildCount >
            0
        let hasDependencies = scope.buildDependencyCount > 0
        if (hasOwnership && hasDependencies) {
            both += 1
        } else if (hasOwnership) {
            ownershipOnly += 1
        } else if (hasDependencies) {
            dependencyOnly += 1
        } else {
            empty += 1
        }
    }
    reportCount("自动组合 facet", "仅声明所有权 scope", UInt64(ownershipOnly))
    reportCount("自动组合 facet", "仅构建依赖 scope", UInt64(dependencyOnly))
    reportCount("自动组合 facet", "所有权与依赖并存 scope", UInt64(both))
    reportCount("自动组合 facet", "空 committed scope", UInt64(empty))
    if (dependencyOnly != AUTOMATIC_ROW_COUNT || both != 0) {
        throw IllegalStateException(
            "Expected ${AUTOMATIC_ROW_COUNT} dependency-only row scopes, observed ${dependencyOnly} dependency-only and ${both} combined")
    }
}

private func runRememberSlotBench(rect: Rect): Unit {
    runRememberSlotCase(rect, true, "256 个 keyless 位置槽")
    runRememberSlotCase(rect, false, "256 个显式字符串键")
}

private func runRememberSlotCase(rect: Rect, positional: Bool, name: String): Unit {
    let host = WidgetTestHost(retainedMode: RetainedTestMode.Full)
    let scene = RememberSlotScene(positional)
    let body: () -> Unit = {=> scene.build()}
    let _ = host.frame(rect, body: body)
    let result = timeit(name, REMEMBER_FRAME_COUNT, {
        => host.frame(rect, body: body).metrics.stabilizationPasses + scene.checksum
    })
    if (scene.initializations != REMEMBER_SLOT_COUNT) {
        throw IllegalStateException(
            "${name} initialized ${scene.initializations}/${REMEMBER_SLOT_COUNT} retained states")
    }
    report("frame", "局部状态身份", result)
    reportCount("局部状态身份", "${name}每帧初始化", UInt64(scene.initializations / (REMEMBER_FRAME_COUNT + 1)))
}

public func runDeclarationReplayBench(): Unit {
    printSection("自动组合声明重放（静态 / 外部版本）")
    let rect = Rect(0.0, 0.0, 720.0, 200.0)
    runDeclarationReplayCase(rect, false, false, "静态声明")
    runDeclarationReplayCase(rect, true, false, "外部版本声明")
    runDeclarationReplayCase(rect, false, true, "keyless 静态声明")
    runDeclarationReplayCase(rect, true, true, "keyless 外部版本声明")
}

private func runDeclarationReplayCase(
    rect: Rect,
    externallyRevisioned: Bool,
    positional: Bool,
    name: String
): Unit {
    let host = WidgetTestHost()
    let scene = DeclarationScene(externallyRevisioned, positional)
    let body: () -> Unit = {=> scene.build()}
    let _ = host.frame(rect, body: body)
    let before = scene.bodyBuilds
    report(
        "frame",
        "声明重放",
        timeit(
            "${DECLARATION_COUNT} ${name}",
            DECLARATION_FRAME_COUNT,
            {
                =>
                    let result = host.frame(rect, body: body)
                    result.metrics.stabilizationPasses
            }
        )
    )
    let bodyBuilds = scene.bodyBuilds - before
    let expected = if (externallyRevisioned) {
        DECLARATION_FRAME_COUNT
    } else {
        Int64(0)
    }
    if (bodyBuilds != expected) {
        throw IllegalStateException("${name} expected ${expected} stable body executions, observed ${bodyBuilds}")
    }
    reportCount("声明重放", "${name}每帧组合体执行", UInt64(bodyBuilds) / UInt64(DECLARATION_FRAME_COUNT))
}

private func runAutomaticPaintBench(): Unit {
    printSection("自动显示列表（普通 UI 代码 A/B）")
    let rect = Rect(0.0, 0.0, 720.0, 900.0)
    let automaticHost = WidgetTestHost()
    let automaticScene = AutomaticPaintScene()
    let automaticBody: () -> Unit = {=> automaticScene.build()}
    for (_ in 0..4) {
        let _ = automaticHost.frame(rect, body: automaticBody)
    }
    let automaticBefore = automaticScene.paintVisits
    report(
        "frame",
        "自动显示列表",
        timeit(
            "96 绘制节点 / 自动缓存",
            AUTOMATIC_PAINT_FRAME_COUNT,
            {
                =>
                    let result = automaticHost.frame(rect, body: automaticBody)
                    result.metrics.stabilizationPasses + automaticScene.paintVisits
            }
        )
    )
    reportCount(
        "自动显示列表",
        "自动缓存 widget 绘制访问",
        UInt64((automaticScene.paintVisits - automaticBefore) / AUTOMATIC_PAINT_FRAME_COUNT)
    )
    reportCount("自动显示列表", "缓存命令数", automaticPaintCommandCount(automaticHost))

    let fullHost = WidgetTestHost(retainedMode: RetainedTestMode.Full)
    let fullScene = AutomaticPaintScene()
    let fullBody: () -> Unit = {=> fullScene.build()}
    let _ = fullHost.frame(rect, body: fullBody)
    let fullBefore = fullScene.paintVisits
    report(
        "frame",
        "自动显示列表",
        timeit(
            "96 绘制节点 / 强制直绘",
            AUTOMATIC_PAINT_FRAME_COUNT,
            {
                =>
                    let result = fullHost.frame(rect, body: fullBody)
                    result.metrics.stabilizationPasses + fullScene.paintVisits
            }
        )
    )
    reportCount(
        "自动显示列表",
        "强制直绘 widget 绘制访问",
        UInt64((fullScene.paintVisits - fullBefore) / AUTOMATIC_PAINT_FRAME_COUNT)
    )
}

private func runAutomaticLayoutBench(): Unit {
    printSection("自动渲染边界（复杂兄弟局部更新 A/B）")
    let rect = Rect(0.0, 0.0, 720.0, 900.0)
    let automaticHost = WidgetTestHost()
    let automaticScene = AutomaticLayoutScene()
    let automaticBody: () -> Unit = {=> automaticScene.build()}
    let _ = automaticHost.frame(rect, body: automaticBody)
    automaticScene.changing.value += 1
    let automaticBefore = automaticScene.layoutVisits
    let _ = automaticHost.frame(rect, body: automaticBody)
    reportCount("自动渲染边界", "兄弟变化稳定子树 layout 访问", UInt64(automaticScene.layoutVisits - automaticBefore))
    report(
        "frame",
        "自动渲染边界",
        timeit(
            "24 节点稳定兄弟 / 自动晋升",
            AUTOMATIC_LAYOUT_FRAME_COUNT,
            {
                =>
                    automaticScene.changing.value += 1
                    let result = automaticHost.frame(rect, body: automaticBody)
                    automaticScene.changing.value + result.metrics.stabilizationPasses
            }
        )
    )

    let fullHost = WidgetTestHost(retainedMode: RetainedTestMode.Full)
    let fullScene = AutomaticLayoutScene()
    let fullBody: () -> Unit = {=> fullScene.build()}
    let _ = fullHost.frame(rect, body: fullBody)
    fullScene.changing.value += 1
    let fullBefore = fullScene.layoutVisits
    let _ = fullHost.frame(rect, body: fullBody)
    reportCount("自动渲染边界", "强制全量稳定子树 layout 访问", UInt64(fullScene.layoutVisits - fullBefore))
    report(
        "frame",
        "自动渲染边界",
        timeit(
            "24 节点稳定兄弟 / 强制全量",
            AUTOMATIC_LAYOUT_FRAME_COUNT,
            {
                =>
                    fullScene.changing.value += 1
                    let result = fullHost.frame(rect, body: fullBody)
                    fullScene.changing.value + result.metrics.stabilizationPasses
            }
        )
    )
}

private func automaticPaintCommandCount(host: WidgetTestHost): UInt64 {
    var commands = UInt64(0)
    for (scope in host.retainedDiagnostics().automaticScopes) {
        commands += UInt64(scope.paintCommandCount)
    }
    commands
}
