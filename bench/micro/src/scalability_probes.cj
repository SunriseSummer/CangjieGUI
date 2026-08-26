/*
 * Scale probes for the four linear/quadratic paths that are deliberately still simple arrays:
 * one composition scope reading many State values, LazyColumn.scrollToKey, focus registration /
 * traversal, and reverse-z event dispatch. Each timing is paired with an exact visit count so a
 * scheduler fluctuation cannot be mistaken for an algorithmic result.
 */
package bench_micro

import cui.{LazyColumn, LazyViewportController, MouseButton, Rect, Size, Spacer, State, UiContext, UiEvent, Widget,
    WidgetTestHost, ZStack, emit, focusableControlIdentity}
import bench_harness.{BenchResult, printSection, report, reportCount, timeit}

private let SCALE_VIEWPORT = Rect(0.0, 0.0, 640.0, 720.0)

private class StateReadValue <: Widget {
    private let checksum: Int64

    init(checksum: Int64) {
        this.checksum = checksum
        emit(this)
    }

    public func measure(_: UiContext, _: Size): Size {
        Size(Float32(checksum % 2), 0.0)
    }

    public func layout(_: UiContext, _: Rect): Unit {}

    public func draw(_: UiContext): Unit {}

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }
}

private class StateChangeDriver {
    private let states: Array<State<Int64>>
    private var index: Int64 = 0

    init(states: Array<State<Int64>>) {
        this.states = states
    }

    func changeOne(): Unit {
        let state = states[index]
        state.value += 1
        index = (index + 7919) % states.size
    }
}

private func emitStateReadValue(states: Array<State<Int64>>): Unit {
    var checksum: Int64 = 0
    for (state in states) {
        checksum += state.value
    }
    StateReadValue(checksum)
}

private func maximumAutomaticBuildDependencies(host: WidgetTestHost): Int64 {
    var result: Int64 = 0
    for (scope in host.retainedDiagnostics().automaticScopes) {
        result = max(result, scope.buildDependencyCount)
    }
    result
}

private func measureSingleScopeStateReads(count: Int64, frames: Int64): Unit {
    let states = Array<State<Int64>>(count, {index => State<Int64>(index)})
    let driver = StateChangeDriver(states)
    let host = WidgetTestHost()
    let body: () -> Unit = {=> emitStateReadValue(states)}
    let _ = host.frame(SCALE_VIEWPORT, body: body)
    let observed = maximumAutomaticBuildDependencies(host)
    if (observed != count) {
        throw IllegalStateException("State scale probe expected ${count} dependencies, observed ${observed}")
    }
    let result = timeit(
        "${count} State 局部写+作用域重建",
        frames,
        {
            =>
                driver.changeOne()
                host.frame(SCALE_VIEWPORT, body: body).metrics.stabilizationPasses
        }
    )
    report("frame", "单作用域 State 扩展性", result)
    reportCount("单作用域 State 扩展性", "${count} State build 依赖", UInt64(observed))
}

private class LazyKeyProbe {
    var reads: Int64 = 0

    func key(index: Int64): String {
        reads += 1
        "item.${index}"
    }

    func reset(): Unit {
        reads = 0
    }
}

private class LazyTargetDriver {
    private let count: Int64
    private var target: Int64

    init(count: Int64) {
        this.count = count
        this.target = count / 3
    }

    func request(controller: LazyViewportController): Int64 {
        target = (target + 7919) % count
        controller.scrollToKey("item.${target}")
        target
    }
}

private func measureRandomScrollToKey(count: Int64, frames: Int64): Unit {
    let host = WidgetTestHost()
    let controller = LazyViewportController()
    let probe = LazyKeyProbe()
    let driver = LazyTargetDriver(count)
    let body: () -> Unit = {
        => LazyColumn(count, 24.0, key: {index => probe.key(index)}, id: "scroll.key.${count}", controller: controller) {
            _ => Spacer()
        }
    }
    let _ = host.frame(SCALE_VIEWPORT, body: body)
    probe.reset()
    let result = timeit(
        "${count} 项随机 scrollToKey+帧",
        frames,
        {
            =>
                let target = driver.request(controller)
                let frame = host.frame(SCALE_VIEWPORT, body: body)
                if (!controller.lastTargetFound()) {
                    throw IllegalStateException("scrollToKey scale probe did not find item.${target}")
                }
                frame.metrics.stabilizationPasses
        }
    )
    report("frame", "scrollToKey 扩展性", result)
    reportCount("scrollToKey 扩展性", "${count} 项平均 key 访问", UInt64(probe.reads / frames))
}

private class FocusProbeWidget <: Widget {
    private let id: String
    private let buildRevision: Int64

    init(index: Int64, buildRevision: Int64) {
        this.id = focusableControlIdentity("scale.focus.${index}")
        this.buildRevision = buildRevision
        emit(this)
    }

    public func measure(_: UiContext, _: Size): Size {
        Size(Float32(buildRevision % 2), 0.0)
    }

    public func layout(_: UiContext, _: Rect): Unit {}

    public func draw(_: UiContext): Unit {}

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }

    public func focusableId(): ?String {
        Some(id)
    }
}

private func emitFocusables(count: Int64, revision: State<Int64>): Unit {
    let buildRevision = revision.value
    var index: Int64 = 0
    while (index < count) {
        FocusProbeWidget(index, buildRevision)
        index += 1
    }
}

private func measureFocusableScale(count: Int64, frames: Int64): Unit {
    let host = WidgetTestHost()
    let revision = State<Int64>(0)
    let body: () -> Unit = {=> emitFocusables(count, revision)}
    let _ = host.frame(SCALE_VIEWPORT, body: body)
    var buildTotal: UInt64 = 0
    var checksum: Int64 = 0
    var frame: Int64 = 0
    while (frame < frames) {
        revision.value += 1
        let result = host.frame(SCALE_VIEWPORT, body: body)
        buildTotal += result.metrics.buildNs
        checksum += result.metrics.stabilizationPasses
        frame += 1
    }
    report("frame", "焦点扩展性", BenchResult("${count} focusable 注册重建", frames, buildTotal, checksum))
    report(
        "micro",
        "焦点扩展性",
        timeit(
            "${count} focusable focusNext",
            count,
            {
                =>
                    host.context.focusNext()
                    host.context.focusId.size
            }
        )
    )
}

private class HitVisitProbe {
    let target: Int64
    var visits: Int64 = 0

    init(target: Int64) {
        this.target = target
    }

    func visit(index: Int64): Bool {
        visits += 1
        index == target
    }

    func reset(): Unit {
        visits = 0
    }
}

private class HitProbeWidget <: Widget {
    private let index: Int64
    private let probe: HitVisitProbe

    init(index: Int64, probe: HitVisitProbe) {
        this.index = index
        this.probe = probe
        emit(this)
    }

    public func measure(_: UiContext, available: Size): Size {
        available
    }

    public func layout(_: UiContext, _: Rect): Unit {}

    public func draw(_: UiContext): Unit {}

    public func handle(_: UiContext, event: UiEvent): Bool {
        match (event) {
            case UiEvent.MouseDown(MouseButton.Left, _, _) => probe.visit(index)
            case _ => false
        }
    }
}

private func emitHitTree(count: Int64, probe: HitVisitProbe): Unit {
    ZStack {
        var index: Int64 = 0
        while (index < count) {
            HitProbeWidget(index, probe)
            index += 1
        }
    }
}

private func measureHitTest(count: Int64, target: Int64, name: String, frames: Int64): Unit {
    let host = WidgetTestHost()
    let probe = HitVisitProbe(target)
    let body: () -> Unit = {=> emitHitTree(count, probe)}
    let _ = host.frame(SCALE_VIEWPORT, body: body)
    probe.reset()
    var eventTotal: UInt64 = 0
    var checksum: Int64 = 0
    var frame: Int64 = 0
    while (frame < frames) {
        let result = host.frame(SCALE_VIEWPORT, events: [UiEvent.MouseDown(MouseButton.Left, 1.0, 1.0)], body: body)
        eventTotal += result.metrics.eventNs
        checksum += result.metrics.stabilizationPasses
        frame += 1
    }
    let expectedVisits = if (target == count - 1) {
        frames
    } else {
        count * frames
    }
    if (probe.visits != expectedVisits) {
        throw IllegalStateException("Hit-test scale probe expected ${expectedVisits} visits, observed ${probe.visits}")
    }
    report("micro", "事件命中扩展性", BenchResult("${count} 节点 ${name}", frames, eventTotal, checksum))
    reportCount("事件命中扩展性", "${count} 节点 ${name} 平均访问", UInt64(probe.visits / frames))
}

/** Runs scale curves that guard the indexed State, focus and key-navigation paths. */
public func runScalabilityProbeBench(): Unit {
    printSection("规模扩展性探针")
    measureSingleScopeStateReads(1000, 12)
    measureSingleScopeStateReads(10000, 4)
    measureRandomScrollToKey(10000, 20)
    measureRandomScrollToKey(100000, 12)
    measureFocusableScale(1000, 6)
    measureFocusableScale(10000, 2)
    measureHitTest(1000, 999, "最上层命中", 100)
    measureHitTest(1000, 0, "最深层命中", 100)
    measureHitTest(10000, 9999, "最上层命中", 50)
    measureHitTest(10000, 0, "最深层命中", 50)
}
