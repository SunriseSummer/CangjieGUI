/*
 * Real-renderer incremental update benchmark. The three variants use the same 96-cell dashboard:
 * forced full retained execution, automatic command-buffer replay over the full scene, and the
 * same command buffers clipped to the one changed cell. The window is uncapped and self-closing.
 */
package bench_incremental_dashboard

import cui.{Color, Grid, Rect, RetainedScopeDiagnostics, RetainedSubtree, RetainedTestMode, SdlWindow, Size, State,
    UiContext, UiEvent, Widget, WidgetTestHost, WindowSpec, emit}
import bench_harness.{SampledBenchResult, report, reportBenchmarkEnvironment, reportFrameDistribution, sampleFrames}

private let WIDTH: Int32 = 960
private let HEIGHT: Int32 = 720
private let COLUMNS: Int64 = 8
private let REGIONS: Int64 = 96
private let FRAMES: Int64 = 90
private let WARM_FRAMES: Int64 = 60
private let CELL_HEIGHT: Float32 = 52.0

private class CellDriver {
    private let count: Int64
    private var next: Int64 = 0

    init(count: Int64) {
        this.count = count
    }

    func advance(states: Array<State<Int64>>): Int64 {
        let changed = next
        states[changed].value += 1
        next = (next + 1) % count
        changed
    }
}

private class DashboardCell <: Widget {
    private let index: Int64
    private let value: Int64
    private var frame = Rect.zero()

    init(index: Int64, value: Int64) {
        this.index = index
        this.value = value
        emit(this)
    }

    public func measure(_: UiContext, available: Size): Size {
        Size(available.w, min(CELL_HEIGHT, available.h))
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        let tint = (index * 17 + value * 29) % 90
        ctx.renderer.fill(frame, Color.rgb(28 + tint, 62 + tint / 2, 108 + tint))
        ctx
            .renderer
            .text("节点 ${index}  tick ${value}", frame.x + 7.0, frame.y + 14.0, Color.rgb(244, 247, 252),
                pointSize: 13.0)
    }

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }
}

main(): Int64 {
    let window = SdlWindow(
        WindowSpec("CUI bench: incremental dashboard", WIDTH, HEIGHT, resizable: false, vsync: false, supersample: 1))
    let viewport = Rect(0.0, 0.0, Float32(WIDTH), Float32(HEIGHT))
    try {
        runFullTree(window, viewport)
        runIncremental(window, viewport)
    } finally {
        window.close()
    }
    return 0
}

private func runFullTree(window: SdlWindow, viewport: Rect): Unit {
    let host = WidgetTestHost(renderer: window.renderer, retainedMode: RetainedTestMode.Full)
    let states = Array<State<Int64>>(REGIONS, {_ => State<Int64>(0)})
    let driver = CellDriver(REGIONS)
    let body: () -> Unit = {=> dashboard(states)}
    warm(host, window, viewport, states, driver, body, None)
    reportSample(
        window,
        sampleFrames(
            "96 区域强制全量",
            FRAMES,
            {
                =>
                    let _ = driver.advance(states)
                    let result = host.frame(viewport, body: body)
                    window.renderer.present()
                    Int64(result.metrics.textDraws)
            }
        )
    )
    host.reset()
}

private func runIncremental(window: SdlWindow, viewport: Rect): Unit {
    let host = WidgetTestHost(renderer: window.renderer)
    let states = Array<State<Int64>>(REGIONS, {_ => State<Int64>(0)})
    let driver = CellDriver(REGIONS)
    let body: () -> Unit = {=> dashboard(states)}
    let _ = host.frame(viewport, body: body)
    window.renderer.present()
    let damageRects = retainedBounds(host.retainedDiagnostics().scopes)

    warm(host, window, viewport, states, driver, body, None)
    reportSample(
        window,
        sampleFrames(
            "96 区域命令全场重放",
            FRAMES,
            {
                =>
                    let _ = driver.advance(states)
                    let result = host.frame(viewport, body: body)
                    window.renderer.present()
                    Int64(result.metrics.textDraws)
            }
        )
    )

    warm(host, window, viewport, states, driver, body, Some(damageRects))
    reportSample(
        window,
        sampleFrames(
            "单区域 damage",
            FRAMES,
            {
                =>
                    let changed = driver.advance(states)
                    let result = host.frame(viewport, damage: Some(damageRects[changed]), body: body)
                    window.renderer.present()
                    Int64(result.metrics.textDraws)
            }
        )
    )
    host.reset()
}

private func reportSample(window: SdlWindow, sample: SampledBenchResult): Unit {
    let group = "增量仪表盘（真实渲染）"
    report("display", group, sample.result)
    reportFrameDistribution(group, sample.result.name, sample.distribution)
    reportBenchmarkEnvironment(
        group,
        sample.result.name,
        window.renderer.driverName(),
        window.renderer.supersampleFactor(),
        window.renderer.vsync()
    )
}

private func warm(
    host: WidgetTestHost,
    window: SdlWindow,
    viewport: Rect,
    states: Array<State<Int64>>,
    driver: CellDriver,
    body: () -> Unit,
    damageRects: ?Array<Rect>
): Unit {
    var frame: Int64 = 0
    while (frame < WARM_FRAMES) {
        let changed = driver.advance(states)
        match (damageRects) {
            case Some(rects) => let _ = host.frame(viewport, damage: Some(rects[changed]), body: body)
            case None => let _ = host.frame(viewport, body: body)
        }
        window.renderer.present()
        frame += 1
    }
}

private func dashboard(states: Array<State<Int64>>): Unit {
    Grid(COLUMNS) {
        var index: Int64 = 0
        while (index < states.size) {
            let cell = index
            RetainedSubtree("dashboard.cell.${cell}", cachePaint: true) {
                DashboardCell(cell, states[cell].value)
            }
            index += 1
        }
    }.spacing(4.0)
}

private func retainedBounds(scopes: Array<RetainedScopeDiagnostics>): Array<Rect> {
    let result = Array<Rect>(REGIONS, {_ => Rect.zero()})
    for (scope in scopes) {
        var index: Int64 = 0
        while (index < REGIONS) {
            if (scope.path == "dashboard.cell.${index}") {
                result[index] = scope.bounds
                break
            }
            index += 1
        }
    }
    for (rect in result) {
        if (rect.w <= 0.0 || rect.h <= 0.0) {
            throw IllegalStateException("Missing incremental dashboard damage bounds")
        }
    }
    result
}
