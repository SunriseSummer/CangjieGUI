package cui.testing

import std.collection.ArrayList
import sdl.{FrameInfo, Key, MouseButton, Rect, Renderer, UiEvent, UiEventRecord}
import sdl.system.PerformanceClock
import cui.core.{FrameSchedule, FrameScheduler, RetainedGraphDiagnostics, StateStore, Theme, UiContext, Widget,
    broadcastEvent, buildRoot, collectRootLayoutStateReads, collectRootPaintStateReads, consumeFullRetainedFrameDamage,
    dispatchEventRecordSequence, dispatchFrameSubscribers, enableAutomaticComposition, frameSubscriberCount,
    retainedGraphDiagnostics, useFullRetainedExecution, useIncrementalRetainedExecution, withFrameScheduler}

private let TEST_MAX_STABILIZATION_PASSES: Int64 = 3

/** Whether WidgetTestHost uses retained caches or forces every retained phase to execute. */
public enum RetainedTestMode {
    | Incremental
    | Full
}

/** Per-phase measurements and probes from one headless framework frame. */
public struct TestFrameMetrics {
    public let buildNs: UInt64
    public let layoutNs: UInt64
    public let eventNs: UInt64
    public let drawNs: UInt64
    public let stabilizationPasses: Int64
    public let textMeasures: UInt64
    public let textComputes: UInt64
    public let textDraws: UInt64
    public let frameSubscribers: Int64
    public let overlayCount: Int64

    public init(
        buildNs: UInt64,
        layoutNs: UInt64,
        eventNs: UInt64,
        drawNs: UInt64,
        stabilizationPasses: Int64,
        textMeasures: UInt64,
        textComputes: UInt64,
        textDraws: UInt64,
        overlayCount: Int64
    ) {
        this(buildNs, layoutNs, eventNs, drawNs, stabilizationPasses, textMeasures, textComputes, textDraws, 0,
            overlayCount)
    }

    public init(
        buildNs: UInt64,
        layoutNs: UInt64,
        eventNs: UInt64,
        drawNs: UInt64,
        stabilizationPasses: Int64,
        textMeasures: UInt64,
        textComputes: UInt64,
        textDraws: UInt64,
        frameSubscribers: Int64,
        overlayCount: Int64
    ) {
        this.buildNs = buildNs
        this.layoutNs = layoutNs
        this.eventNs = eventNs
        this.drawNs = drawNs
        this.stabilizationPasses = stabilizationPasses
        this.textMeasures = textMeasures
        this.textComputes = textComputes
        this.textDraws = textDraws
        this.frameSubscribers = frameSubscribers
        this.overlayCount = overlayCount
    }

    /** Complete CPU-side frame time represented by the measured phases. */
    public func totalNs(): UInt64 {
        buildNs + layoutNs + eventNs + drawNs
    }
}

/** The stable widget tree, metrics, and consumed next-frame plan produced by `WidgetTestHost.frame`. */
public class TestFrameResult {
    public let widget: Widget
    public let metrics: TestFrameMetrics
    public let schedule: FrameSchedule

    public init(widget: Widget, metrics: TestFrameMetrics, schedule: FrameSchedule) {
        this.widget = widget
        this.metrics = metrics
        this.schedule = schedule
    }
}

private class TestLayoutResult {
    let widget: Widget
    let buildNs: UInt64
    let layoutNs: UInt64
    let passes: Int64
    let generation: UInt64

    init(widget: Widget, buildNs: UInt64, layoutNs: UInt64, passes: Int64, generation: UInt64) {
        this.widget = widget
        this.buildNs = buildNs
        this.layoutNs = layoutNs
        this.passes = passes
        this.generation = generation
    }
}

private class TestLayoutAttempt {
    let widget: Widget
    let buildNs: UInt64
    let layoutNs: UInt64
    let startGeneration: UInt64
    let endGeneration: UInt64

    init(widget: Widget, buildNs: UInt64, layoutNs: UInt64, startGeneration: UInt64, endGeneration: UInt64) {
        this.widget = widget
        this.buildNs = buildNs
        this.layoutNs = layoutNs
        this.startGeneration = startGeneration
        this.endGeneration = endGeneration
    }
}

/**
 * Deterministic headless host for unit, integration, and performance tests. It runs the same
 * build/layout/event/rebuild-before-draw transaction and pointer/focus settling as DesktopApp,
 * retains rememberState values between frames, exposes the UiContext for interaction assertions,
 * records per-phase costs, and returns the frame's immediate/deadline schedule.
 */
public class WidgetTestHost {
    public let context: UiContext
    private let stateStore = StateStore()
    private let scheduler = FrameScheduler()
    private var completed: ?TestFrameResult = None

    public init(
        theme!: Theme = Theme.light(),
        displayScale!: Float32 = 1.0,
        fontScale!: Float32 = 1.0,
        retainedMode!: RetainedTestMode = RetainedTestMode.Incremental,
        renderer!: Renderer = Renderer.headless()
    ) {
        this.context = UiContext(renderer, theme)
        this.context.displayScale = max(0.001, displayScale)
        this.context.fontScale = max(0.1, fontScale)
        enableAutomaticComposition(stateStore)
        match (retainedMode) {
            case RetainedTestMode.Incremental => useIncrementalRetainedExecution(stateStore)
            case RetainedTestMode.Full => useFullRetainedExecution(stateStore)
        }
    }

    /**
     * Runs one stable headless frame. Events are delivered in order, followed by a synthesized
     * Frame event; state changes they cause are reflected by a second build/layout before draw.
     */
    public func frame(
        rect: Rect,
        elapsedMs!: UInt64 = UInt64(0),
        deltaMs!: UInt64 = UInt64(0),
        events!: Array<UiEvent> = [],
        damage!: ?Rect = None,
        body!: () -> Unit
    ): TestFrameResult {
        let records = ArrayList<UiEventRecord>(events.size)
        for (event in events) {
            records.add(UiEventRecord(event))
        }
        frameRecords(rect, elapsedMs: elapsedMs, deltaMs: deltaMs, events: records.toArray(), damage: damage, body: body)
    }

    /** Runs a frame with native event-time metadata, including deterministic modifier snapshots. */
    public func frameRecords(
        rect: Rect,
        elapsedMs!: UInt64 = UInt64(0),
        deltaMs!: UInt64 = UInt64(0),
        events!: Array<UiEventRecord> = [],
        damage!: ?Rect = None,
        body!: () -> Unit
    ): TestFrameResult {
        completed = None
        withFrameScheduler(scheduler, {=> runFrame(rect, elapsedMs, deltaMs, events, damage, body)})
        // runFrame assigns completed on every normal return; match keeps that invariant explicit.
        match (completed) {
            case Some(result) => result
            case None => throw IllegalStateException("WidgetTestHost frame completed without a result")
        }
    }

    /** Captures the last committed retained execution graph without running another frame. */
    public func retainedDiagnostics(): RetainedGraphDiagnostics {
        retainedGraphDiagnostics(stateStore)
    }

    /** Clears retained state and shared interaction state before the next test frame. */
    public func reset(): Unit {
        stateStore.clear()
        scheduler.invalidate()
        context.clearFocus()
        context.hoverId = ""
        context.clearDrag()
        context.clearPress()
        context.leftMouseDown = false
        context.shouldClose = false
        context.clearActiveOverlay()
        context.clearTooltip()
        context.clearTextInputAnchor()
        context.clearFrameSchedule()
        completed = None
    }

    /** Coalesces a group of state writes with the same scheduler used by `frame`. */
    public func batch(action: () -> Unit): Unit {
        withFrameScheduler(scheduler, {=> scheduler.transaction(action)})
    }

    private func runFrame(
        rect: Rect,
        elapsedMs: UInt64,
        deltaMs: UInt64,
        events: Array<UiEventRecord>,
        damage: ?Rect,
        body: () -> Unit
    ): Unit {
        context.frame = FrameInfo(elapsedMs, deltaMs)
        context.viewportWidth = rect.w
        context.viewportHeight = rect.h
        context.renderer.resetTextMeasureCount()
        var stable = stableLayout(rect, body)
        let eventNs = dispatchFrameEvents(stable.widget, events)
        if (scheduler.generation != stable.generation) {
            let reflected = stableLayout(rect, body)
            stable = TestLayoutResult(reflected.widget, stable.buildNs + reflected.buildNs,
                stable.layoutNs + reflected.layoutNs, stable.passes + reflected.passes, reflected.generation)
        }
        let drawNs = drawFrame(rect, damage, stable.widget)
        let schedule = context.takeFrameSchedule()
        completed = Some(
            TestFrameResult(stable.widget,
                TestFrameMetrics(stable.buildNs, stable.layoutNs, eventNs, drawNs, stable.passes,
                    context.renderer.textMeasureCount(), context.renderer.textComputeCount(),
                    context.renderer.textDrawCount(), frameSubscriberCount(stateStore), context.overlayCount()),
                schedule))
    }

    private func dispatchFrameEvents(widget: Widget, events: Array<UiEventRecord>): UInt64 {
        let eventStart = now()
        scheduler.transaction(
            {
                =>
                    dispatchEventRecordSequence(events, context, {event => preparePointer(event)}, {
                        event => routeEvent(widget, event)
                    }, {event => completePointer(event)})
                    dispatchFrameSubscribers(stateStore, context, context.frame)
            }
        )
        elapsed(eventStart, now())
    }

    private func drawFrame(rect: Rect, damage: ?Rect, widget: Widget): UInt64 {
        let drawStart = now()
        consumeFullRetainedFrameDamage(stateStore)
        let activeDamage: ?Rect = match (damage) {
            case Some(value) =>
                if (context.renderer.beginSceneDamage(rect.w, rect.h, context.theme.bg, value)) {
                    Some(value)
                } else {
                    None
                }
            case None =>
                context.renderer.beginScene(rect.w, rect.h, context.theme.bg)
                None
        }
        context.setRetainedDamage(activeDamage)
        try {
            context.clearTooltip()
            context.clearTextInputAnchor()
            collectRootPaintStateReads(stateStore, {=> widget.draw(context)})
            context.drawActiveOverlay()
        } finally {
            context.setRetainedDamage(None)
        }
        context.renderer.endScene()
        elapsed(drawStart, now())
    }

    private func stableLayout(rect: Rect, body: () -> Unit): TestLayoutResult {
        var attempt = layoutOnce(rect, body)
        var buildNs = attempt.buildNs
        var layoutNs = attempt.layoutNs
        var passes: Int64 = 1
        while (attempt.startGeneration != attempt.endGeneration && passes < TEST_MAX_STABILIZATION_PASSES) {
            attempt = layoutOnce(rect, body)
            buildNs += attempt.buildNs
            layoutNs += attempt.layoutNs
            passes += 1
        }
        if (attempt.startGeneration != attempt.endGeneration) {
            context.requestFrame()
        }
        TestLayoutResult(attempt.widget, buildNs, layoutNs, passes, attempt.endGeneration)
    }

    private func layoutOnce(rect: Rect, body: () -> Unit): TestLayoutAttempt {
        let startGeneration = scheduler.generation
        context.clearActiveOverlay()
        let buildStart = now()
        let widget = buildRoot(body, stateStore)
        let layoutStart = now()
        context.adoptFocusRing(stateStore.focusRing())
        collectRootLayoutStateReads(stateStore, {=> widget.layout(context, rect)})
        let layoutEnd = now()
        TestLayoutAttempt(widget, elapsed(buildStart, layoutStart), elapsed(layoutStart, layoutEnd), startGeneration,
            scheduler.generation)
    }

    private func routeEvent(widget: Widget, event: UiEvent): Unit {
        match (event) {
            case UiEvent.Quit => context.requestClose()
            case UiEvent.Wake => ()
            case UiEvent.MouseMove(_, _) =>
                context.beginHoverTest()
                if (!context.dispatchOverlay(event)) {
                    broadcastEvent(widget, context, event)
                }
                context.settleHover()
            case UiEvent.MouseDown(MouseButton.Left, x, y) =>
                context.recordPress(x, y)
                if (!context.dispatchOverlay(event)) {
                    context.beginPointerPress()
                    broadcastEvent(widget, context, event)
                    context.settleFocusAfterPress()
                }
            case UiEvent.KeyDown(Key.Tab, _) =>
                if (!context.dispatchOverlay(event)) {
                    if (context.eventModifiers().shift) {
                        context.focusPrevious()
                    } else {
                        context.focusNext()
                    }
                }
            case _ =>
                if (!context.dispatchOverlay(event)) {
                    broadcastEvent(widget, context, event)
                }
        }
    }

    private func preparePointer(event: UiEvent): Unit {
        match (event) {
            case UiEvent.MouseMove(x, y) => rememberMouse(x, y)
            case UiEvent.MouseDown(MouseButton.Left, x, y) =>
                rememberMouse(x, y)
                context.leftMouseDown = true
            case UiEvent.MouseUp(MouseButton.Left, x, y) => rememberMouse(x, y)
            case UiEvent.DropFile(_, x, y) => rememberMouse(x, y)
            case UiEvent.DropText(_, x, y) => rememberMouse(x, y)
            case UiEvent.DropPosition(x, y) => rememberMouse(x, y)
            case _ => ()
        }
    }

    private func completePointer(event: UiEvent): Unit {
        match (event) {
            case UiEvent.MouseUp(MouseButton.Left, _, _) =>
                context.leftMouseDown = false
                context.clearDrag()
                context.clearPress()
            case _ => ()
        }
    }

    private func rememberMouse(x: Float32, y: Float32): Unit {
        context.mouseX = x
        context.mouseY = y
    }
}

private func now(): UInt64 {
    PerformanceClock.ticksNanoseconds()
}

private func elapsed(start: UInt64, end: UInt64): UInt64 {
    if (end == start || end < start) {
        return UInt64(0)
    }
    end - start
}
