/*
 * Deterministic complex-UI probes for the remaining coarse-grained costs after phase one/two.
 * Each local-update frame changes exactly one region. The retained variant manually supplies every
 * region revision, so it is a best-case control for what dependency tracking could automate.
 */
package bench_phase3

import cui.{EffectCleanup, FontSizes, Grid, HStack, Label, LengthUnits, Panel, Rect, RetainedSubtree, Size, Spacer,
    State, TestFrameMetrics, UiContext, UiEvent, VStack, Widget, WidgetTestHost, mountEffect, rememberState}
import bench_harness.{nowNanos, spanNs}

private let PRESSURE_RECT = Rect(0.0, 0.0, 960.0, 720.0)
private let PROBE_SIZE: Float32 = 12.0
private let FRAME_DELTA_MS: UInt64 = UInt64(16)
private let REGION_SPACING = 6.vp
private let REGION_HEADING: Float32 = 15.0
private let METRIC_COLUMNS: Int64 = 3
private let METRIC_SPACING = 6.vp
private let REGION_INSET = 8.vp
private let REGION_CONTENT_SPACING = 5.vp
private let METRIC_INSET = 5.vp
private let METRIC_CONTENT_SPACING = 2.vp
private let METRIC_VALUE_SIZE: Float32 = 14.0
private let BASE_THROUGHPUT: Int64 = 1200
private let THROUGHPUT_STEP: Int64 = 7
private let BASE_LATENCY: Int64 = 18
private let LATENCY_VARIANTS: Int64 = 11
private let QUEUE_VARIANTS: Int64 = 17
private let RIGID_LAYOUT = false

private enum LocalVariant {
    | FullTree
    | ManualRetained
    | AutomaticRetained
    | AutomaticCommandBuffer
    | AutomaticDynamicPaint
    | AutomaticDamage
}

private class PhaseCounters {
    var builds: UInt64 = UInt64(0)
    var measures: UInt64 = UInt64(0)
    var layouts: UInt64 = UInt64(0)
    var events: UInt64 = UInt64(0)
    var draws: UInt64 = UInt64(0)

    func reset(): Unit {
        builds = UInt64(0)
        measures = UInt64(0)
        layouts = UInt64(0)
        events = UInt64(0)
        draws = UInt64(0)
    }
}

private class DrawSink {
    var value: Int64 = -1
}

private class PressureProbe <: Widget {
    private let counters: PhaseCounters
    private let captured: Int64
    private let sink: ?DrawSink
    private let dynamicPaint: Bool

    init(counters: PhaseCounters, captured!: Int64 = 0, sink!: ?DrawSink = None, dynamicPaint!: Bool = false) {
        this.counters = counters
        this.captured = captured
        this.sink = sink
        this.dynamicPaint = dynamicPaint
    }

    /** Counts one probe measurement and returns its bounded diagnostic size. */
    public func measure(_: UiContext, available: Size): Size {
        counters.measures += UInt64(1)
        Size(min(available.w, PROBE_SIZE), min(available.h, PROBE_SIZE))
    }

    /** Counts one layout visit made by the current update strategy. */
    public func layout(_: UiContext, _: Rect): Unit {
        counters.layouts += UInt64(1)
    }

    /** Counts one draw visit and exposes the value captured when this probe was built. */
    public func draw(ctx: UiContext): Unit {
        counters.draws += UInt64(1)
        if (dynamicPaint) {
            ctx.requestFrame()
        }
        match (sink) {
            case Some(output) => output.value = captured
            case None => ()
        }
    }

    /** Counts Frame-event fan-out while leaving the event unconsumed. */
    public func handle(_: UiContext, event: UiEvent): Bool {
        match (event) {
            case UiEvent.Frame(_) => counters.events += UInt64(1)
            case _ => ()
        }
        false
    }
}

private class RegionDriver {
    private let count: Int64
    private var nextIndex: Int64 = 0

    init(count: Int64) {
        this.count = count
    }

    func advance(states: Array<State<Int64>>): Int64 {
        let changed = nextIndex
        states[changed].value += 1
        nextIndex = (nextIndex + 1) % count
        changed
    }
}

private class MetricTotals {
    var buildNs: UInt64 = UInt64(0)
    var layoutNs: UInt64 = UInt64(0)
    var eventNs: UInt64 = UInt64(0)
    var drawNs: UInt64 = UInt64(0)

    func add(metrics: TestFrameMetrics): Unit {
        buildNs += metrics.buildNs
        layoutNs += metrics.layoutNs
        eventNs += metrics.eventNs
        drawNs += metrics.drawNs
    }
}

private class PressureRecord {
    let experiment: String
    let scale: Int64
    let variant: String
    let totalNs: UInt64
    let buildNs: UInt64
    let layoutNs: UInt64
    let eventNs: UInt64
    let drawNs: UInt64
    let buildVisits: UInt64
    let layoutVisits: UInt64
    let eventVisits: UInt64
    let drawVisits: UInt64

    init(
        experiment: String,
        scale: Int64,
        variant: String,
        totalNs: UInt64,
        metrics: MetricTotals,
        counters: PhaseCounters,
        frames: Int64
    ) {
        this.experiment = experiment
        this.scale = scale
        this.variant = variant
        this.totalNs = average(totalNs, frames)
        this.buildNs = average(metrics.buildNs, frames)
        this.layoutNs = average(metrics.layoutNs, frames)
        this.eventNs = average(metrics.eventNs, frames)
        this.drawNs = average(metrics.drawNs, frames)
        this.buildVisits = average(counters.builds, frames)
        this.layoutVisits = average(counters.layouts, frames)
        this.eventVisits = average(counters.events, frames)
        this.drawVisits = average(counters.draws, frames)
    }

    func printMachineRecord(): Unit {
        emitLine(
            "@@PHASE3|${experiment}|${scale}|${variant}|${totalNs}|${buildNs}|${layoutNs}|${eventNs}|${drawNs}|" +
                "${buildVisits}|${layoutVisits}|${eventVisits}|${drawVisits}")
    }
}

func runLocalUpdatePressure(regions: Int64, frames: Int64): Unit {
    emitLine("\n== 高频局部更新：${regions} 个复杂区域 ==")
    runLocalVariant(regions, frames, LocalVariant.FullTree).printMachineRecord()
    runLocalVariant(regions, frames, LocalVariant.ManualRetained).printMachineRecord()
    runLocalVariant(regions, frames, LocalVariant.AutomaticRetained).printMachineRecord()
    runLocalVariant(regions, frames, LocalVariant.AutomaticCommandBuffer).printMachineRecord()
    runLocalVariant(regions, frames, LocalVariant.AutomaticDynamicPaint).printMachineRecord()
    runLocalVariant(regions, frames, LocalVariant.AutomaticDamage).printMachineRecord()
}

private func runLocalVariant(regions: Int64, frames: Int64, mode: LocalVariant): PressureRecord {
    let host = WidgetTestHost()
    let states = Array<State<Int64>>(regions, {_ => State<Int64>(0)})
    let counters = PhaseCounters()
    let driver = RegionDriver(regions)
    let body: () -> Unit = {=> buildDashboard(states, counters, mode)}
    validateMetrics(host.frame(PRESSURE_RECT, body: body).metrics)
    let damageRects: Array<Rect> = match (mode) {
        case LocalVariant.AutomaticDamage => damageRectsForRegions(host, regions)
        case _ => []
    }
    counters.reset()

    let totals = MetricTotals()
    let started = nowNanos()
    var frame: Int64 = 0
    while (frame < frames) {
        let changed = driver.advance(states)
        let damage: ?Rect = match (mode) {
            case LocalVariant.AutomaticDamage => Some(damageRects[changed])
            case _ => None
        }
        let result = host.frame(PRESSURE_RECT, elapsedMs: UInt64(frame + 1), deltaMs: FRAME_DELTA_MS, damage: damage,
            body: body)
        totals.add(result.metrics)
        frame += 1
    }
    let elapsed = spanNs(started, nowNanos())
    match (mode) {
        case LocalVariant.AutomaticCommandBuffer => printPaintBufferStats(host, regions, "auto-command")
        case LocalVariant.AutomaticDynamicPaint => printPaintBufferStats(host, regions, "auto-dynamic")
        case LocalVariant.AutomaticDamage => printPaintBufferStats(host, regions, "auto-damage")
        case _ => ()
    }
    let variant = match (mode) {
        case LocalVariant.FullTree => "full-tree"
        case LocalVariant.ManualRetained => "manual-retained"
        case LocalVariant.AutomaticRetained => "auto-retained"
        case LocalVariant.AutomaticCommandBuffer => "auto-command"
        case LocalVariant.AutomaticDynamicPaint => "auto-dynamic"
        case LocalVariant.AutomaticDamage => "auto-damage"
    }
    PressureRecord("local-update", regions, variant, elapsed, totals, counters, frames)
}

private func buildDashboard(states: Array<State<Int64>>, counters: PhaseCounters, mode: LocalVariant): Unit {
    VStack {
        var region: Int64 = 0
        while (region < states.size) {
            let regionIndex = region
            match (mode) {
                case LocalVariant.FullTree => buildDashboardRegion(regionIndex, states[regionIndex].value, counters)
                case LocalVariant.ManualRetained =>
                    let revision = states[regionIndex].revision
                    RetainedSubtree("phase3.region.${regionIndex}", revision) {
                        buildDashboardRegion(regionIndex, states[regionIndex].value, counters)
                    }
                case LocalVariant.AutomaticRetained => RetainedSubtree("phase3.region.${regionIndex}") {
                    buildDashboardRegion(regionIndex, states[regionIndex].value, counters)
                }
                case LocalVariant.AutomaticCommandBuffer => RetainedSubtree("phase3.region.${regionIndex}",
                    cachePaint: true) {
                    buildDashboardRegion(regionIndex, states[regionIndex].value, counters)
                }
                case LocalVariant.AutomaticDynamicPaint => RetainedSubtree("phase3.region.${regionIndex}",
                    cachePaint: true) {
                    buildDashboardRegion(regionIndex, states[regionIndex].value, counters, dynamicPaint: true)
                }
                case LocalVariant.AutomaticDamage => RetainedSubtree("phase3.region.${regionIndex}", cachePaint: true) {
                    buildDashboardRegion(regionIndex, states[regionIndex].value, counters)
                }
            }
            region += 1
        }
    }.spacing(REGION_SPACING).flexible(RIGID_LAYOUT)
}

private func printPaintBufferStats(host: WidgetTestHost, regions: Int64, variant: String): Unit {
    var commands: Int64 = 0
    var estimatedBytes: UInt64 = UInt64(0)
    var recordAttempts: UInt64 = UInt64(0)
    var dynamicBypasses: UInt64 = UInt64(0)
    var bypassFrames: UInt64 = UInt64(0)
    var bypassRemaining: Int64 = 0
    for (scope in host.retainedDiagnostics().scopes) {
        commands += scope.stats.paintCommandCount
        estimatedBytes += scope.stats.paintEstimatedBytes
        recordAttempts += scope.stats.paintRecordAttempts
        dynamicBypasses += scope.stats.paintDynamicBypasses
        bypassFrames += scope.stats.paintBypassFrames
        bypassRemaining += scope.stats.paintBypassRemaining
    }
    emitLine("@@PHASE3_BUFFER|${regions}|${variant}|${commands}|${estimatedBytes}")
    if (variant == "auto-dynamic") {
        emitLine("@@PHASE3_DIAG|dynamic-probes-${regions}|${recordAttempts}|${dynamicBypasses}")
        emitLine("@@PHASE3_DIAG|dynamic-bypass-${regions}|${bypassFrames}|${bypassRemaining}")
    }
}

private func damageRectsForRegions(host: WidgetTestHost, regions: Int64): Array<Rect> {
    let result = Array<Rect>(regions, {_ => Rect.zero()})
    for (scope in host.retainedDiagnostics().scopes) {
        var region: Int64 = 0
        while (region < regions) {
            if (scope.path == "phase3.region.${region}") {
                let bounds = scope.bounds
                result[region] = Rect(bounds.x - 24.0, bounds.y - 24.0, bounds.w + 48.0, bounds.h + 48.0)
                break
            }
            region += 1
        }
    }
    for (rect in result) {
        if (rect.w <= 0.0 || rect.h <= 0.0) {
            throw IllegalStateException("Missing retained damage bounds")
        }
    }
    result
}

private func buildDashboardRegion(
    index: Int64,
    value: Int64,
    counters: PhaseCounters,
    dynamicPaint!: Bool = false
): Unit {
    counters.builds += UInt64(1)
    Panel {
        VStack {
            HStack {
                Label("服务分片 ${index}").fontSize(REGION_HEADING)
                Spacer()
                Label("tick ${value}").muted().fontSize(FontSizes.CAPTION)
            }.flexible(RIGID_LAYOUT)
            Grid(METRIC_COLUMNS) {
                metric("吞吐", "${BASE_THROUGHPUT + index * THROUGHPUT_STEP}")
                metric("延迟", "${BASE_LATENCY + index % LATENCY_VARIANTS} ms")
                metric("队列", "${value % QUEUE_VARIANTS}")
            }.spacing(METRIC_SPACING)
            PressureProbe(counters, captured: value, dynamicPaint: dynamicPaint).height(PROBE_SIZE)
        }.spacing(REGION_CONTENT_SPACING).flexible(RIGID_LAYOUT)
    }.contentPadding(REGION_INSET)
}

private func metric(name: String, value: String): Unit {
    Panel {
        VStack {
            Label(name).muted().fontSize(FontSizes.CAPTION)
            Label(value).fontSize(METRIC_VALUE_SIZE)
        }.spacing(METRIC_CONTENT_SPACING).flexible(RIGID_LAYOUT)
    }.contentPadding(METRIC_INSET)
}

func runRetainedStatePressure(stateCount: Int64, frames: Int64): Unit {
    emitLine("\n== retained 状态生命周期：${stateCount} 个后代状态 ==")
    let host = WidgetTestHost()
    let counters = PhaseCounters()
    let body: () -> Unit = {
        => RetainedSubtree("phase3.state-owner", UInt64(0)) {
            counters.builds += UInt64(1)
            var index: Int64 = 0
            while (index < stateCount) {
                let stateIndex = index
                let remembered = rememberState<Int64>("entry.${stateIndex}") {stateIndex}
                counters.measures += remembered.revision
                index += 1
            }
            PressureProbe(counters).height(PROBE_SIZE)
        }
    }
    validateMetrics(host.frame(PRESSURE_RECT, body: body).metrics)
    counters.reset()

    let totals = MetricTotals()
    let started = nowNanos()
    var frame: Int64 = 0
    while (frame < frames) {
        let result = host.frame(PRESSURE_RECT, elapsedMs: UInt64(frame + 1), deltaMs: FRAME_DELTA_MS, body: body)
        totals.add(result.metrics)
        frame += 1
    }
    PressureRecord("retained-state", stateCount, "cache-hit", spanNs(started, nowNanos()), totals, counters, frames)
        .printMachineRecord()
}

func runRetainedEffectPressure(effectCount: Int64, frames: Int64): Unit {
    emitLine("\n== retained effect 生命周期：${effectCount} 个后代 effect ==")
    let host = WidgetTestHost()
    let counters = PhaseCounters()
    let body: () -> Unit = {
        => RetainedSubtree("phase3.effect-owner", UInt64(0)) {
            counters.builds += UInt64(1)
            var index: Int64 = 0
            while (index < effectCount) {
                let effectIndex = index
                mountEffect("entry.${effectIndex}", {=> EffectCleanup({=> ()})})
                index += 1
            }
            PressureProbe(counters).height(PROBE_SIZE)
        }
    }
    validateMetrics(host.frame(PRESSURE_RECT, body: body).metrics)
    counters.reset()

    let totals = MetricTotals()
    let started = nowNanos()
    var frame: Int64 = 0
    while (frame < frames) {
        let result = host.frame(PRESSURE_RECT, elapsedMs: UInt64(frame + 1), deltaMs: FRAME_DELTA_MS, body: body)
        totals.add(result.metrics)
        frame += 1
    }
    PressureRecord("retained-effect", effectCount, "cache-hit", spanNs(started, nowNanos()), totals, counters, frames)
        .printMachineRecord()
    host.reset()
}

func runManualRevisionProbe(): Unit {
    emitLine("\n== retained 人工 revision 正确性 ==")
    let host = WidgetTestHost()
    let source = State<Int64>(0)
    let sink = DrawSink()
    let counters = PhaseCounters()

    renderCaptured(host, source, sink, counters, UInt64(0))
    source.value = 1
    renderCaptured(host, source, sink, counters, UInt64(0))
    let staleObserved = sink.value == 0
    renderCaptured(host, source, sink, counters, UInt64(1))
    let corrected = sink.value == 1
    emitLine("@@PHASE3_ASSERT|manual-revision|${boolDigit(staleObserved)}|${boolDigit(corrected)}")
}

func runAutomaticDependencyProbe(): Unit {
    emitLine("\n== retained 自动 State 依赖正确性 ==")
    let host = WidgetTestHost()
    let source = State<Int64>(0)
    let sink = DrawSink()
    let counters = PhaseCounters()
    let body: () -> Unit = {
        => RetainedSubtree("phase3.automatic-state") {
            counters.builds += UInt64(1)
            PressureProbe(counters, captured: source.value, sink: Some(sink)).height(PROBE_SIZE)
        }
    }

    validateMetrics(host.frame(PRESSURE_RECT, body: body).metrics)
    source.value = 1
    validateMetrics(host.frame(PRESSURE_RECT, body: body).metrics)
    let updated = sink.value == 1
    validateMetrics(host.frame(PRESSURE_RECT, body: body).metrics)
    let stableHit = counters.builds == UInt64(2)
    emitLine("@@PHASE3_ASSERT|automatic-state|${boolDigit(updated)}|${boolDigit(stableHit)}")
}

private func renderCaptured(
    host: WidgetTestHost,
    source: State<Int64>,
    sink: DrawSink,
    counters: PhaseCounters,
    revision: UInt64
): Unit {
    validateMetrics(host.frame(
        PRESSURE_RECT,
        body: {
            =>
                let captured = source.value
                RetainedSubtree("phase3.manual-revision", revision) {
                    PressureProbe(counters, captured: captured, sink: Some(sink)).height(PROBE_SIZE)
                }
        }
    ).metrics)
}

private func validateMetrics(metrics: TestFrameMetrics): Unit {
    if (metrics.stabilizationPasses <= 0) {
        throw IllegalStateException("phase-three probe produced no stabilization pass")
    }
}

func emitLine(text: String): Unit {
    println(text) // cjcheck-ignore: no-println # benchmark executable machine-record protocol is stdout
}

private func average(total: UInt64, frames: Int64): UInt64 {
    if (frames <= 0) {
        UInt64(0)
    } else {
        total / UInt64(frames)
    }
}

private func boolDigit(value: Bool): Int64 {
    if (value) {
        1
    } else {
        0
    }
}
