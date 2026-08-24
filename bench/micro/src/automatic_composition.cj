/*
 * A/B guard for framework-managed composition. Both sides use ordinary UI code with no retained
 * wrapper or revision. Incremental mode updates one State-backed branch; full mode executes every
 * declarative body, making the ratio a direct guard for automatic dirty-path selection.
 */
package bench_micro

import cui.{Color, HStack, Label, Panel, Rect, RetainedTestMode, Size, State, UiContext, UiEvent, VStack, Widget,
    WidgetTestHost, emit}
import bench_harness.{printSection, report, reportCount, timeit}

private let AUTOMATIC_ROW_COUNT: Int64 = 240
private let AUTOMATIC_FRAME_COUNT: Int64 = 100
private let AUTOMATIC_PAINT_FRAME_COUNT: Int64 = 1000
private let AUTOMATIC_LAYOUT_FRAME_COUNT: Int64 = 1000
private let AUTOMATIC_PAINT_NODE_COUNT: Int64 = 96
private let AUTOMATIC_LAYOUT_NODE_COUNT: Int64 = 24

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

public func runAutomaticCompositionBench(): Unit {
    printSection("自动组合脏路径（普通 UI 代码 A/B）")
    let rect = Rect(0.0, 0.0, 720.0, 1800.0)

    let incrementalHost = WidgetTestHost()
    let incrementalScene = AutomaticScene()
    let incrementalBody: () -> Unit = {=> incrementalScene.build()}
    let _ = incrementalHost.frame(rect, body: incrementalBody)
    let incrementalBefore = incrementalScene.totalBodyBuilds()
    let _ = incrementalScene.changeNext()
    let _ = incrementalHost.frame(rect, body: incrementalBody)
    reportCount("自动组合", "单 State 变更执行分支体", UInt64(incrementalScene.totalBodyBuilds() - incrementalBefore))
    report(
        "frame",
        "自动组合",
        timeit(
            "240 分支 / 单分支变更",
            AUTOMATIC_FRAME_COUNT,
            {
                =>
                    let changed = incrementalScene.changeNext()
                    let result = incrementalHost.frame(rect, body: incrementalBody)
                    changed + result.metrics.stabilizationPasses
            }
        )
    )

    let fullHost = WidgetTestHost(retainedMode: RetainedTestMode.Full)
    let fullScene = AutomaticScene()
    let fullBody: () -> Unit = {=> fullScene.build()}
    let _ = fullHost.frame(rect, body: fullBody)
    let fullBefore = fullScene.totalBodyBuilds()
    let _ = fullScene.changeNext()
    let _ = fullHost.frame(rect, body: fullBody)
    reportCount("自动组合", "强制全量执行分支体", UInt64(fullScene.totalBodyBuilds() - fullBefore))
    report(
        "frame",
        "自动组合",
        timeit(
            "240 分支 / 强制全重建",
            AUTOMATIC_FRAME_COUNT,
            {
                =>
                    let changed = fullScene.changeNext()
                    let result = fullHost.frame(rect, body: fullBody)
                    changed + result.metrics.stabilizationPasses
            }
        )
    )

    runAutomaticPaintBench()
    runAutomaticLayoutBench()
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
