/*
 * Scale probes for the four linear/quadratic paths that are deliberately still simple arrays:
 * one composition scope reading many State values, LazyColumn.scrollToKey, focus registration /
 * traversal, and reverse-z event dispatch. Each timing is paired with an exact visit count so a
 * scheduler fluctuation cannot be mistaken for an algorithmic result.
 */
package bench_micro

import cui.{Axis, Grid, LazyColumn, LazyViewportController, MouseButton, PointerEventScope, Rect, Semantics,
    SemanticsAction, SemanticsNode, SemanticsRole, Size, Spacer, State, UiContext, UiEvent, Widget, WidgetTestHost,
    ZStack, emit, focusableControlIdentity}
import bench_harness.{BenchResult, nowNanos, printSection, report, reportCount, reportFrameDistribution, sampleFrames,
    spanNs, timeit}

private let SCALE_VIEWPORT = Rect(0.0, 0.0, 640.0, 720.0)
private let LAZY_NAVIGATION_KEY_COLD_TRIALS: Int64 = 64
private let LAZY_NAVIGATION_INDEX_COLD_TRIALS: Int64 = 256

private class StateScalePhaseTotals {
    var writeNs: UInt64 = 0
    var buildNs: UInt64 = 0
    var layoutNs: UInt64 = 0

    func addWrite(ns: UInt64): Unit {
        writeNs += ns
    }

    func addFrame(build: UInt64, layout: UInt64): Unit {
        buildNs += build
        layoutNs += layout
    }
}

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

private class StatePhaseReadProbe {
    var reads: Int64 = 0
    var checksum: Int64 = 0

    func record(count: Int64, checksum: Int64): Unit {
        reads += count
        this.checksum = checksum
    }
}

private class StateLayoutReadValue <: Widget {
    private let states: Array<State<Int64>>
    private let probe: StatePhaseReadProbe

    init(states: Array<State<Int64>>, probe: StatePhaseReadProbe) {
        this.states = states
        this.probe = probe
    }

    public func measure(_: UiContext, _: Size): Size {
        Size.zero()
    }

    public func layout(_: UiContext, _: Rect): Unit {
        probe.record(states.size, checksumStateReadValues(states))
    }

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

private func checksumStateReadValues(states: Array<State<Int64>>): Int64 {
    var checksum: Int64 = 0
    for (state in states) {
        checksum += state.value
    }
    checksum
}

private func emitStateReadValue(states: Array<State<Int64>>): Unit {
    StateReadValue(checksumStateReadValues(states))
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
    let phases = StateScalePhaseTotals()
    let result = timeit(
        "${count} State 局部写+作用域重建",
        frames,
        {
            =>
                let writeStart = nowNanos()
                driver.changeOne()
                phases.addWrite(spanNs(writeStart, nowNanos()))
                let frame = host.frame(SCALE_VIEWPORT, body: body)
                phases.addFrame(frame.metrics.buildNs, frame.metrics.layoutNs)
                frame.metrics.stabilizationPasses
        }
    )
    report("frame", "单作用域 State 扩展性", result)
    report(
        "micro",
        "单作用域 State 扩展性",
        BenchResult("${count} State 局部写/失效", frames, phases.writeNs, 0)
    )
    report(
        "micro",
        "单作用域 State 扩展性",
        BenchResult("${count} State 依赖重建 build", frames, phases.buildNs, 0)
    )
    report(
        "micro",
        "单作用域 State 扩展性",
        BenchResult("${count} State 稳定 layout", frames, phases.layoutNs, 0)
    )
    reportCount("单作用域 State 扩展性", "${count} State build 依赖", UInt64(observed))
    report(
        "micro",
        "单作用域 State 扩展性",
        timeit("${count} State 无依赖收集读取", frames, {=> checksumStateReadValues(states)})
    )
}

private func measureSinglePhaseStateReads(count: Int64, frames: Int64, stableNode: Bool): Unit {
    let states = Array<State<Int64>>(count, {index => State<Int64>(index)})
    let driver = StateChangeDriver(states)
    let probe = StatePhaseReadProbe()
    let host = WidgetTestHost()
    let widget = StateLayoutReadValue(states, probe)
    let body: () -> Unit = if (stableNode) {
        {=> emit(widget)}
    } else {
        {=> emit(StateLayoutReadValue(states, probe))}
    }
    let topology = if (stableNode) {
        "稳定节点"
    } else {
        "替换节点"
    }
    let _ = host.frame(SCALE_VIEWPORT, body: body)
    if (maximumAutomaticBuildDependencies(host) != 0) {
        throw IllegalStateException("Phase State scale probe leaked layout reads into build dependencies")
    }
    probe.reads = 0
    let phases = StateScalePhaseTotals()
    let result = timeit(
        "${count} State ${topology} layout 重收集",
        frames,
        {
            =>
                let writeStart = nowNanos()
                driver.changeOne()
                phases.addWrite(spanNs(writeStart, nowNanos()))
                let frame = host.frame(SCALE_VIEWPORT, body: body)
                phases.addFrame(frame.metrics.buildNs, frame.metrics.layoutNs)
                frame.metrics.stabilizationPasses
        }
    )
    if (probe.reads != count * frames) {
        throw IllegalStateException(
            "Phase State scale expected ${count * frames} layout reads, observed ${probe.reads}")
    }
    report("frame", "单阶段 State 扩展性", result)
    report(
        "micro",
        "单阶段 State 扩展性",
        BenchResult("${count} State ${topology} phase 写/失效", frames, phases.writeNs, 0)
    )
    report(
        "micro",
        "单阶段 State 扩展性",
        BenchResult("${count} State ${topology} phase build", frames, phases.buildNs, 0)
    )
    report(
        "micro",
        "单阶段 State 扩展性",
        BenchResult("${count} State ${topology} measure/layout", frames, phases.layoutNs, 0)
    )
    reportCount("单阶段 State 扩展性", "${count} State ${topology} layout 读取", UInt64(probe.reads / frames))
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

    func requestIndex(controller: LazyViewportController): Int64 {
        target = (target + 7919) % count
        controller.scrollToIndex(target)
        target
    }
}

private func measureRandomScrollToKey(count: Int64, frames: Int64): Unit {
    let trials = if (count >= 100000) {
        LAZY_NAVIGATION_KEY_COLD_TRIALS
    } else {
        Int64(1)
    }
    var totalNs: UInt64 = 0
    var totalFrames: Int64 = 0
    var totalReads: Int64 = 0
    var checksum: Int64 = 0
    for (trial in 0..trials) {
        let host = WidgetTestHost()
        let controller = LazyViewportController()
        let probe = LazyKeyProbe()
        let driver = LazyTargetDriver(count)
        let body: () -> Unit = {
            => LazyColumn(count, 24.0, key: {index => probe.key(index)}, id: "scroll.key.${count}.${trial}",
                controller: controller) {
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
        totalNs += result.totalNs
        totalFrames += result.iterations
        totalReads += probe.reads
        checksum += result.checksum
    }
    report(
        "frame",
        "scrollToKey 扩展性",
        BenchResult("${count} 项随机 scrollToKey+帧", totalFrames, totalNs, checksum)
    )
    reportCount("scrollToKey 扩展性", "${count} 项平均 key 访问", UInt64(totalReads / totalFrames))
}

private func measureRandomScrollToIndex(count: Int64, frames: Int64): Unit {
    let trials = if (count >= 100000) {
        LAZY_NAVIGATION_INDEX_COLD_TRIALS
    } else {
        Int64(1)
    }
    var totalNs: UInt64 = 0
    var totalFrames: Int64 = 0
    var totalReads: Int64 = 0
    var checksum: Int64 = 0
    for (trial in 0..trials) {
        let host = WidgetTestHost()
        let controller = LazyViewportController()
        let probe = LazyKeyProbe()
        let driver = LazyTargetDriver(count)
        let body: () -> Unit = {
            => LazyColumn(count, 24.0, key: {index => probe.key(index)}, id: "scroll.index.${count}.${trial}",
                controller: controller) {
                _ => Spacer()
            }
        }
        let _ = host.frame(SCALE_VIEWPORT, body: body)
        probe.reset()
        let result = timeit(
            "${count} 项随机 scrollToIndex+帧",
            frames,
            {
                =>
                    let target = driver.requestIndex(controller)
                    let frame = host.frame(SCALE_VIEWPORT, body: body)
                    if (!controller.lastTargetFound()) {
                        throw IllegalStateException("scrollToIndex scale probe did not find item ${target}")
                    }
                    frame.metrics.stabilizationPasses
            }
        )
        totalNs += result.totalNs
        totalFrames += result.iterations
        totalReads += probe.reads
        checksum += result.checksum
    }
    let averageKeyReads = totalReads / totalFrames
    if (averageKeyReads > 128) {
        throw IllegalStateException(
            "scrollToIndex unexpectedly scanned keys: ${averageKeyReads} average reads for ${count} items")
    }
    report(
        "frame",
        "scrollToIndex 扩展性",
        BenchResult("${count} 项随机 scrollToIndex+帧", totalFrames, totalNs, checksum)
    )
    reportCount("scrollToIndex 扩展性", "${count} 项平均 key 访问", UInt64(averageKeyReads))
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

private class InertFocusProbeWidget <: Widget {
    private let buildRevision: Int64

    init(buildRevision: Int64) {
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
}

private func emitFocusables(count: Int64, revision: State<Int64>): Unit {
    let buildRevision = revision.value
    var index: Int64 = 0
    while (index < count) {
        FocusProbeWidget(index, buildRevision)
        index += 1
    }
}

private func emitInertFocusProbes(count: Int64, revision: State<Int64>): Unit {
    let buildRevision = revision.value
    for (_ in 0..count) {
        InertFocusProbeWidget(buildRevision)
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
    measureStableFocusableFrame(count, max(Int64(30), frames * 5))
}

private func measureStableFocusableFrame(count: Int64, frames: Int64): Unit {
    let revision = State<Int64>(0)
    let focusHost = WidgetTestHost()
    let focusBody: () -> Unit = {=> emitFocusables(count, revision)}
    let inertHost = WidgetTestHost()
    let inertBody: () -> Unit = {=> emitInertFocusProbes(count, revision)}
    for (_ in 0..3) {
        let _ = focusHost.frame(SCALE_VIEWPORT, body: focusBody)
        let _ = inertHost.frame(SCALE_VIEWPORT, body: inertBody)
    }
    let focusRevision = focusHost.focusGraphRevision()
    let inertRevision = inertHost.focusGraphRevision()
    let focusPhases = StableFocusPhaseTotals()
    let inertPhases = StableFocusPhaseTotals()
    let focus = sampleFrames(
        "${count} focusable 稳定帧",
        frames,
        {
            =>
                let result = focusHost.frame(SCALE_VIEWPORT, body: focusBody)
                focusPhases.add(result.metrics.buildNs, result.metrics.layoutNs)
                result.metrics.stabilizationPasses
        }
    )
    let inert = sampleFrames(
        "${count} 空节点稳定帧",
        frames,
        {
            =>
                let result = inertHost.frame(SCALE_VIEWPORT, body: inertBody)
                inertPhases.add(result.metrics.buildNs, result.metrics.layoutNs)
                result.metrics.stabilizationPasses
        }
    )
    report("frame", "焦点扩展性", focus.result)
    report("frame", "焦点扩展性", inert.result)
    reportFrameDistribution("焦点扩展性", focus.result.name, focus.distribution)
    reportFrameDistribution("焦点扩展性", inert.result.name, inert.distribution)
    report("micro", "焦点扩展性", BenchResult("${count} focusable 稳定 build", frames, focusPhases.buildNs, 0))
    report("micro", "焦点扩展性", BenchResult("${count} 空节点稳定 build", frames, inertPhases.buildNs, 0))
    report("micro", "焦点扩展性", BenchResult("${count} focusable 稳定 focus/layout", frames, focusPhases.layoutNs, 0))
    report("micro", "焦点扩展性", BenchResult("${count} 空节点稳定 focus/layout", frames, inertPhases.layoutNs, 0))
    let focusCommits = focusHost.focusGraphRevision() - focusRevision
    let inertCommits = inertHost.focusGraphRevision() - inertRevision
    reportCount("焦点扩展性", "${count} focusable 稳定图提交", focusCommits)
    reportCount("焦点扩展性", "${count} 空节点稳定图提交", inertCommits)
    if (focusCommits != UInt64(0) || inertCommits != UInt64(0)) {
        throw IllegalStateException("Stable focus fragments rebuilt an unchanged committed graph")
    }
}

private class StableFocusPhaseTotals {
    var buildNs: UInt64 = UInt64(0)
    var layoutNs: UInt64 = UInt64(0)

    func add(build: UInt64, layout: UInt64): Unit {
        buildNs += build
        layoutNs += layout
    }
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

private class SparseHitProbeWidget <: Widget {
    private let index: Int64
    private let probe: HitVisitProbe
    private let bounded: Bool
    private var frame = Rect.zero()

    init(index: Int64, probe: HitVisitProbe, bounded!: Bool = true) {
        this.index = index
        this.probe = probe
        this.bounded = bounded
        emit(this)
    }

    public func measure(_: UiContext, _: Size): Size {
        Size(1.0, 1.0)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(_: UiContext): Unit {}

    public func handle(_: UiContext, event: UiEvent): Bool {
        match (event) {
            case UiEvent.MouseDown(MouseButton.Left, x, y) =>
                let target = probe.visit(index)
                frame.contains(x, y) && target
            case _ => false
        }
    }

    public func acceptsStretch(_: Axis): Bool {
        false
    }

    public func pointerEventScope(): PointerEventScope {
        if (bounded) {
            PointerEventScope.LayoutBounds
        } else {
            PointerEventScope.Unbounded
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

private func sparseHitGrid(count: Int64, probe: HitVisitProbe, bounded!: Bool = true): Grid {
    let grid = Grid(100) {
        for (index in 0..count) {
            SparseHitProbeWidget(index, probe, bounded: bounded)
        }
    }
    grid.spacing(0.0)
}

private func emitSparseHitGrid(count: Int64, probe: HitVisitProbe): Unit {
    let _ = sparseHitGrid(count, probe)
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

private func measureSparseHitTest(count: Int64, frames: Int64): UInt64 {
    let host = WidgetTestHost()
    let probe = HitVisitProbe(0)
    let body: () -> Unit = {=> emitSparseHitGrid(count, probe)}
    let _ = host.frame(SCALE_VIEWPORT, body: body)
    probe.reset()
    var eventTotal: UInt64 = 0
    var layoutTotal: UInt64 = 0
    var checksum: Int64 = 0
    for (_ in 0..frames) {
        let result = host.frame(SCALE_VIEWPORT, events: [UiEvent.MouseDown(MouseButton.Left, 0.5, 0.5)], body: body)
        eventTotal += result.metrics.eventNs
        layoutTotal += result.metrics.layoutNs
        checksum += result.metrics.stabilizationPasses
    }
    let result = BenchResult("${count} 稀疏节点最深命中", frames, eventTotal, checksum)
    if (probe.visits != frames) {
        throw IllegalStateException(
            "Sparse hit topology expected one candidate per frame, observed ${probe.visits / frames}")
    }
    if (result.perIterationNs() > UInt64(5000)) {
        throw IllegalStateException("Sparse hit topology exceeded the 5 us indexed gate")
    }
    report("micro", "事件命中扩展性", result)
    reportCount("事件命中扩展性", "${count} 稀疏节点平均访问", UInt64(probe.visits / frames))
    let layout = BenchResult("${count} Element-owned 稳定布局", frames, layoutTotal, checksum)
    report("frame", "事件命中扩展性", layout)
    layout.perIterationNs()
}

private func measureEventTopologyCommit(count: Int64, iterations: Int64, elementOwnedLayout: UInt64): Unit {
    let context = WidgetTestHost().context
    let unbounded = sparseHitGrid(count, HitVisitProbe(0), bounded: false)
    let bounded = sparseHitGrid(count, HitVisitProbe(0))
    for (_ in 0..3) {
        unbounded.layout(context, SCALE_VIEWPORT)
        bounded.layout(context, SCALE_VIEWPORT)
    }
    let legacy = sampleFrames(
        "${count} 无界子节点布局提交",
        iterations,
        {
            =>
                unbounded.layout(context, SCALE_VIEWPORT);
                count
        }
    )
    let indexed = sampleFrames(
        "${count} 有界子节点布局提交",
        iterations,
        {
            =>
                bounded.layout(context, SCALE_VIEWPORT);
                count
        }
    )
    if (indexed.distribution.p50Ns > legacy.distribution.p50Ns + UInt64(50000)) {
        throw IllegalStateException("Stable event topology commit added more than 50 us")
    }
    if (elementOwnedLayout > indexed.distribution.p50Ns + UInt64(50000)) {
        throw IllegalStateException("Element-owned event topology added more than 50 us to stable layout")
    }
    report("frame", "事件命中扩展性", legacy.result)
    report("frame", "事件命中扩展性", indexed.result)
    reportFrameDistribution("事件命中扩展性", legacy.result.name, legacy.distribution)
    reportFrameDistribution("事件命中扩展性", indexed.result.name, indexed.distribution)
}

private class SemanticsScaleProbe {
    var actions: Int64 = 0

    func perform(action: SemanticsAction): Bool {
        match (action) {
            case SemanticsAction.Activate =>
                actions += 1
                true
            case _ => false
        }
    }
}

private class SemanticsScaleWidget <: Widget {
    private let id: String
    private let probe: SemanticsScaleProbe

    init(index: Int64, probe: SemanticsScaleProbe) {
        this.id = "semantics-scale-${index}"
        this.probe = probe
        emit(this)
    }

    public func measure(_: UiContext, available: Size): Size {
        available
    }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        ctx.registerSemantics(
            SemanticsNode(id, Semantics(label: id, role: SemanticsRole.Button), rect,
                actions: [SemanticsAction.Activate]), perform: {action => probe.perform(action)})
    }

    public func draw(_: UiContext): Unit {}

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }
}

private class SparseSemanticsScaleWidget <: Widget {
    private let id: String

    init(index: Int64) {
        id = focusableControlIdentity("sparse-semantics-${index}")
        emit(this)
    }

    public func measure(_: UiContext, _: Size): Size {
        Size(1.0, 1.0)
    }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        ctx.registerSemantics(SemanticsNode(id, Semantics(label: id, role: SemanticsRole.Button), rect))
    }

    public func draw(_: UiContext): Unit {}

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }

    public func acceptsStretch(_: Axis): Bool {
        false
    }

    public func focusableId(): ?String {
        Some(id)
    }
}

private func measureSemanticsScale(count: Int64, iterations: Int64): Unit {
    let host = WidgetTestHost()
    let probe = SemanticsScaleProbe()
    let body: () -> Unit = {
        => ZStack {
            for (index in 0..count) {
                SemanticsScaleWidget(index, probe)
            }
        }
    }
    let initial = host.frame(SCALE_VIEWPORT, body: body)
    report("frame", "语义树扩展性",
        BenchResult("${count} 节点首次语义提交", 1, initial.metrics.semanticsNs, initial.metrics.stabilizationPasses))
    let earliest = timeit("${count} 节点最早动作", iterations, {
        => if (host.context.performSemanticsAction("semantics-scale-0", SemanticsAction.Activate)) {
            1
        } else {
            0
        }
    })
    let latest = timeit("${count} 节点最新动作", iterations, {
        => if (host.context.performSemanticsAction("semantics-scale-${count - 1}", SemanticsAction.Activate)) {
            1
        } else {
            0
        }
    })
    let snapshot = timeit("${count} 节点重复快照", iterations, {=> host.context.semanticsSnapshot().size})
    requireSemanticsLookupScale(earliest.perIterationNs(), latest.perIterationNs(), snapshot.perIterationNs())
    report("micro", "语义树扩展性", earliest)
    report("micro", "语义树扩展性", latest)
    report("micro", "语义树扩展性", snapshot)
    if (probe.actions != iterations * 2) {
        throw IllegalStateException("Semantics scale probe lost action dispatches")
    }
    measureSemanticsStableFrame(count, max(Int64(10), iterations / 10))
    measureSemanticsPointQuery(count, iterations)
}

private func measureSemanticsPointQuery(count: Int64, iterations: Int64): Unit {
    let host = WidgetTestHost()
    let body: () -> Unit = {
        => Grid(100) {
            for (index in 0..count) {
                SparseSemanticsScaleWidget(index)
            }
        }.spacing(0.0)
    }
    let _ = host.frame(SCALE_VIEWPORT, body: body)
    let snapshot = host.context.semanticsTreeSnapshot()
    let linear = timeit("${count} 稀疏语义点线性查询", iterations, {=> linearSemanticNodeAt(snapshot.nodes, 0.5, 0.5)})
    let indexed = timeit("${count} 稀疏语义点索引查询", iterations, {
        => match (snapshot.nodeAt(0.5, 0.5)) {
            case Some(node) => node.id.size
            case None => 0
        }
    })
    if (indexed.perIterationNs() > UInt64(2000)) {
        throw IllegalStateException("Committed semantic point query exceeded the 2 us indexed gate")
    }
    host.context.focus(snapshot.nodes[0].id)
    let focused = timeit("${count} 已聚焦语义查询", iterations, {
        => match (host.context.focusedSemanticsNode()) {
            case Some(node) => node.id.size
            case None => 0
        }
    })
    if (focused.perIterationNs() > UInt64(2000)) {
        throw IllegalStateException("Committed focused semantic lookup exceeded the 2 us indexed gate")
    }
    report("micro", "语义树扩展性", linear)
    report("micro", "语义树扩展性", indexed)
    report("micro", "语义树扩展性", focused)
}

private func linearSemanticNodeAt(nodes: Array<SemanticsNode>, x: Float32, y: Float32): Int64 {
    var index = nodes.size - 1
    while (index >= 0) {
        if (nodes[index].bounds.contains(x, y)) {
            return nodes[index].id.size
        }
        index -= 1
    }
    0
}

private func measureSemanticsStableFrame(count: Int64, frames: Int64): Unit {
    let semanticHost = WidgetTestHost()
    let semanticProbe = SemanticsScaleProbe()
    let semanticBody: () -> Unit = {
        => ZStack {
            for (index in 0..count) {
                SemanticsScaleWidget(index, semanticProbe)
            }
        }
    }
    let silentHost = WidgetTestHost()
    let silentBody: () -> Unit = {
        => ZStack {
            for (_ in 0..count) {
                Spacer()
            }
        }
    }
    let silentInitial = silentHost.frame(SCALE_VIEWPORT, body: silentBody)
    report(
        "frame",
        "语义树扩展性",
        BenchResult("${count} 空节点首次语义提交", 1, silentInitial.metrics.semanticsNs,
            silentInitial.metrics.stabilizationPasses)
    )
    for (_ in 0..3) {
        let _ = semanticHost.frame(SCALE_VIEWPORT, body: semanticBody)
        let _ = silentHost.frame(SCALE_VIEWPORT, body: silentBody)
    }
    let semantic = sampleFrames(
        "${count} 节点稳定语义帧",
        frames,
        {
            =>
                let result = semanticHost.frame(SCALE_VIEWPORT, body: semanticBody)
                result.metrics.stabilizationPasses + result.metrics.frameSubscribers
        }
    )
    let silent = sampleFrames(
        "${count} 节点稳定空节点帧",
        frames,
        {
            =>
                let result = silentHost.frame(SCALE_VIEWPORT, body: silentBody)
                result.metrics.stabilizationPasses + result.metrics.frameSubscribers
        }
    )
    if (semantic.distribution.p50Ns > silent.distribution.p50Ns + UInt64(10000)) {
        throw IllegalStateException("Stable semantic commit p50 added more than 10 us over the same silent tree")
    }
    report("frame", "语义树扩展性", semantic.result)
    report("frame", "语义树扩展性", silent.result)
}

private func requireSemanticsLookupScale(earliest: UInt64, latest: UInt64, snapshot: UInt64): Unit {
    if (earliest > UInt64(2000) || latest > UInt64(2000)) {
        throw IllegalStateException("Committed semantic action lookup exceeded the 2 us indexed gate")
    }
    if (snapshot > UInt64(2000)) {
        throw IllegalStateException("Committed semantic snapshot lookup exceeded the 2 us gate")
    }
}

private func measureEmptySemanticCommit(count: Int64): Unit {
    let host = WidgetTestHost()
    let body: () -> Unit = {
        => ZStack {
            for (_ in 0..count) {
                Spacer()
            }
        }
    }
    let initial = host.frame(SCALE_VIEWPORT, body: body)
    let semanticCount = host.context.semanticsSnapshot().size
    let overlayCount = host.context.overlayCount()
    if (semanticCount != 0) {
        throw IllegalStateException("Empty semantic probe unexpectedly published ${semanticCount} nodes")
    }
    if (overlayCount != 0) {
        throw IllegalStateException("Empty layout probe unexpectedly published ${overlayCount} overlays")
    }
    report(
        "frame",
        "空语义提交",
        BenchResult("${count} 空节点首次语义提交", 1, initial.metrics.semanticsNs, initial.metrics.stabilizationPasses)
    )
    report(
        "frame",
        "空语义提交",
        BenchResult("${count} 空节点首次布局", 1, initial.metrics.layoutNs, initial.metrics.stabilizationPasses)
    )
    reportCount("空语义提交", "${count} 空节点语义节点", UInt64(semanticCount))
    reportCount("空语义提交", "${count} 空节点 overlay", UInt64(overlayCount))
}

/** Runs only cold empty-tree layout commits for sparse semantic and overlay representation experiments. */
public func runEmptySemanticsBench(): Unit {
    printSection("空语义提交")
    measureEmptySemanticCommit(1000)
    measureEmptySemanticCommit(10000)
}

public func runSemanticsScaleBench(): Unit {
    printSection("语义树扩展性")
    measureSemanticsScale(1000, 1000)
    measureSemanticsScale(10000, 200)
}

/** Runs the isolated overlapping and sparse pointer-routing scale curves. */
public func runEventScaleBench(): Unit {
    printSection("事件命中扩展性")
    measureHitTest(1000, 999, "最上层命中", 100)
    measureHitTest(1000, 0, "最深层命中", 100)
    measureHitTest(10000, 9999, "最上层命中", 50)
    measureHitTest(10000, 0, "最深层命中", 50)
    let _ = measureSparseHitTest(1000, 100)
    let elementOwnedLayout = measureSparseHitTest(10000, 50)
    measureEventTopologyCommit(10000, 30, elementOwnedLayout)
    measureEventListenerFocusScale()
}

/** Runs focus registration, traversal, and stable-fragment scale curves. */
public func runFocusScaleBench(): Unit {
    printSection("焦点扩展性")
    measureFocusableScale(1000, 600)
    measureFocusableScale(10000, 128)
    measureAutomaticFocusMetadataQueries()
}

/** Runs scale curves that guard the indexed State, focus and key-navigation paths. */
public func runScalabilityProbeBench(): Unit {
    printSection("规模扩展性探针")
    runStateReadScaleBench()
    runLazyNavigationScaleBench()
    measureFocusableScale(1000, 600)
    measureFocusableScale(10000, 128)
    measureAutomaticFocusMetadataQueries()
    measureHitTest(1000, 999, "最上层命中", 100)
    measureHitTest(1000, 0, "最深层命中", 100)
    measureHitTest(10000, 9999, "最上层命中", 50)
    measureHitTest(10000, 0, "最深层命中", 50)
}

/** Runs the daily scale probes whose heap lifetime is independent from cold lazy navigation. */
public func runDailyScalabilityWithoutLazyBench(): Unit {
    printSection("规模扩展性探针")
    runStateReadScaleBench()
    measureFocusableScale(1000, 600)
    measureFocusableScale(10000, 128)
    measureAutomaticFocusMetadataQueries()
    measureHitTest(1000, 999, "最上层命中", 100)
    measureHitTest(1000, 0, "最深层命中", 100)
    measureHitTest(10000, 9999, "最上层命中", 50)
    measureHitTest(10000, 0, "最深层命中", 50)
}

/** Compares cold stable-key lookup with direct index navigation at 10k/100k items. */
public func runLazyNavigationScaleBench(reverse!: Bool = false): Unit {
    if (reverse) {
        measureRandomScrollToIndex(100000, 12)
        measureRandomScrollToKey(100000, 12)
        measureRandomScrollToIndex(10000, 20)
        measureRandomScrollToKey(10000, 20)
    } else {
        measureRandomScrollToKey(10000, 20)
        measureRandomScrollToIndex(10000, 20)
        measureRandomScrollToKey(100000, 12)
        measureRandomScrollToIndex(100000, 12)
    }
}

/** Runs only the single-scope State dependency width curve for focused collector A/B work. */
public func runStateReadScaleBench(): Unit {
    printSection("单作用域 State 依赖扩展性")
    measureSingleScopeStateReads(1000, 12)
    measureSingleScopeStateReads(10000, 128)
    measureSinglePhaseStateReads(1000, 12, true)
    measureSinglePhaseStateReads(10000, 128, true)
    measureSinglePhaseStateReads(1000, 12, false)
    measureSinglePhaseStateReads(10000, 128, false)
}
