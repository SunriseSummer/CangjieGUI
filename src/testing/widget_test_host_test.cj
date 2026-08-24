package cui.testing

import std.collection.ArrayList
import sdl.{Color, EventKeyModifiers, Key, MouseButton, Rect, Size, UiEvent, UiEventMetadata, UiEventRecord}
import cui.core.{Button, EventHandler, FrameHandler, HStack, Label, RetainedSubtree, Spacer, State, UiContext, Widget,
    emit, rememberState}

private class DamageTextProbe <: Widget {
    private let text: String
    private var frame = Rect.zero()

    init(text: String) {
        this.text = text
        emit(this)
    }

    public func measure(_: UiContext, available: Size): Size {
        Size(available.w, min(available.h, 40.0))
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        ctx.renderer.text(text, frame.x, frame.y, Color.rgb(20, 30, 40))
    }

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }
}

private class BuildObservation {
    var calls: Int64 = 0
    var lastValue: Int64 = -1

    func record(value: Int64): Unit {
        calls += 1
        lastValue = value
    }
}

private class PassiveFrameProbe <: Widget {
    private let observation: BuildObservation

    init(observation: BuildObservation) {
        this.observation = observation
        emit(this)
    }

    public func measure(_: UiContext, available: Size): Size {
        available
    }

    public func layout(_: UiContext, _: Rect): Unit {}

    public func draw(_: UiContext): Unit {}

    public func handle(_: UiContext, event: UiEvent): Bool {
        match (event) {
            case UiEvent.Frame(_) => observation.record(1)
            case _ => ()
        }
        false
    }
}

private class RememberedStateCapture {
    var value: ?State<Int64> = None
}

@Test
func widgetTestHostReflectsEventStateBeforeTheSameFrameDraw(): Unit {
    let host = WidgetTestHost()
    let value = State<Int64>(0)
    let observation = BuildObservation()

    let result = host.frame(Rect(0.0, 0.0, 200.0, 80.0), events: [UiEvent.KeyDown(Key.Enter, false)]) {
        observation.record(value.value)
        EventHandler(onEvent: {
            event => match (event) {
                case UiEvent.KeyDown(Key.Enter, _) =>
                    value.value = 1
                    true
                case _ => false
            }
        }) {
            Label("${value.value}")
        }
    }

    @Expect(observation.calls, Int64(2))
    @Expect(observation.lastValue, Int64(1))
    @Expect(result.metrics.stabilizationPasses, Int64(2))
}

@Test
func widgetTestHostRetainsExplicitSubtreesAcrossFrames(): Unit {
    let host = WidgetTestHost()
    let observation = BuildObservation()
    let body: () -> Unit = {
        => let _ = RetainedSubtree("host-retained", UInt64(0)) {
            observation.record(0)
            Label("stable")
        }
    }

    let _ = host.frame(Rect(0.0, 0.0, 200.0, 80.0), body: body)
    let second = host.frame(Rect(0.0, 0.0, 200.0, 80.0), body: body)

    @Expect(observation.calls, Int64(1))
    @Expect(second.metrics.textMeasures, UInt64(1)) // draw still requests cached centering metrics
    @Expect(second.metrics.textComputes, UInt64(0))
}

@Test
func widgetTestHostCanForceFullRetainedExecution(): Unit {
    let incremental = WidgetTestHost()
    let full = WidgetTestHost(retainedMode: RetainedTestMode.Full)
    let incrementalBuilds = BuildObservation()
    let fullBuilds = BuildObservation()
    let incrementalBody: () -> Unit = {
        => RetainedSubtree("mode-probe") {
            incrementalBuilds.record(0)
            Label("same output")
        }
    }
    let fullBody: () -> Unit = {
        => RetainedSubtree("mode-probe") {
            fullBuilds.record(0)
            Label("same output")
        }
    }
    let rect = Rect(0.0, 0.0, 200.0, 80.0)

    let _ = incremental.frame(rect, body: incrementalBody)
    let _ = incremental.frame(rect, body: incrementalBody)
    let _ = full.frame(rect, body: fullBody)
    let _ = full.frame(rect, body: fullBody)

    @Expect(incrementalBuilds.calls, Int64(1))
    @Expect(fullBuilds.calls, Int64(2))
}

@Test
func fullRetainedExecutionPreservesMountedState(): Unit {
    let host = WidgetTestHost(retainedMode: RetainedTestMode.Full)
    let initializations = BuildObservation()
    let captured = RememberedStateCapture()
    let body: () -> Unit = {
        => RetainedSubtree("full-state") {
            let value = rememberState<Int64>("counter") {
                initializations.record(0)
                Int64(0)
            }
            captured.value = Some(value)
            Label("${value.value}")
        }
    }
    let rect = Rect(0.0, 0.0, 200.0, 80.0)

    let _ = host.frame(rect, body: body)
    match (captured.value) {
        case Some(value) => value.value = 7
        case None => @Expect(false)
    }
    let _ = host.frame(rect, body: body)

    @Expect(initializations.calls, Int64(1))
    match (captured.value) {
        case Some(value) => @Expect(value.value, Int64(7))
        case None => @Expect(false)
    }
}

@Test
func widgetTestHostDispatchesFrameOnlyToExplicitSubscribers(): Unit {
    let host = WidgetTestHost()
    let passive = BuildObservation()
    let subscribed = BuildObservation()

    let result = host.frame(Rect(0.0, 0.0, 200.0, 80.0)) {
        PassiveFrameProbe(passive)
        FrameHandler(onFrame: {_ => subscribed.record(1)}) {Spacer()}
    }

    @Expect(passive.calls, Int64(0))
    @Expect(subscribed.calls, Int64(1))
    @Expect(result.metrics.frameSubscribers, Int64(1))
}

@Test
func retainedFrameSubscriptionsReplayInParentBeforeChildOrder(): Unit {
    let host = WidgetTestHost()
    let builds = BuildObservation()
    let order = ArrayList<String>()
    let body: () -> Unit = {
        => RetainedSubtree("subscribed-retained") {
            builds.record(0)
            FrameHandler(onFrame: {_ => order.add("parent")}) {
                FrameHandler(onFrame: {_ => order.add("child")}) {Spacer()}
            }
        }
    }

    let _ = host.frame(Rect(0.0, 0.0, 200.0, 80.0), body: body)
    order.clear()
    let _ = host.frame(Rect(0.0, 0.0, 200.0, 80.0), body: body)

    @Expect(builds.calls, Int64(1))
    @Expect(order.toArray(), ["parent", "child"])
}

@Test
func widgetTestHostCapsPerpetualBuildInvalidation(): Unit {
    let host = WidgetTestHost()
    let unstable = State<Int64>(0)
    let result = host.frame(Rect(0.0, 0.0, 100.0, 40.0)) {
        unstable.value += 1
        Label("${unstable.value}")
    }

    @Expect(result.metrics.stabilizationPasses, Int64(3))
    @Expect(unstable.value, Int64(3))
    @Expect(result.schedule.immediate)
}

@Test
func widgetTestHostSettlesHoverLikeDesktopApp(): Unit {
    let host = WidgetTestHost()
    let _ = host.frame(Rect(0.0, 0.0, 120.0, 40.0), events: [UiEvent.MouseMove(10.0, 10.0)]) {
        Button("Hover", {=> ()}).key("hover-target")
    }

    @Expect(host.context.isHovered("hover-target"))
    @Expect(host.context.mouseX, 10.0)
    @Expect(host.context.mouseY, 10.0)
}

@Test
func widgetTestHostUsesDeferredEventModifierSnapshot(): Unit {
    let host = WidgetTestHost()
    let rect = Rect(0.0, 0.0, 200.0, 50.0)
    let body: () -> Unit = {
        => HStack {
            Button("First", {=> ()}).key("first")
            Button("Second", {=> ()}).key("second")
        }
    }
    let _ = host.frame(rect, body: body)
    host.context.focus("first", viaKeyboard: true)
    let shiftedTab = UiEventRecord(UiEvent.KeyDown(Key.Tab, false),
        UiEventMetadata(modifiers: EventKeyModifiers(raw: UInt16(0x0001))))
    let _ = host.frameRecords(rect, events: [shiftedTab], body: body)

    @Expect(host.context.focusId, "second")
}

@Test
func contextEventHandlerUsesItsOwnDeferredModifierSnapshot(): Unit {
    let host = WidgetTestHost()
    let shortcuts = State<Int64>(0)
    let pressed = UiEventRecord(UiEvent.KeyDown(Key.Letter(UInt8(83)), false),
        UiEventMetadata(modifiers: EventKeyModifiers(raw: UInt16(0x0040))))
    let released = UiEventRecord(UiEvent.KeyUp(Key.Letter(UInt8(83))), UiEventMetadata())

    let _ = host.frameRecords(Rect(0.0, 0.0, 200.0, 50.0), events: [pressed, released]) {
        EventHandler(onEvent: {
            ctx, event => match (event) {
                case UiEvent.KeyDown(Key.Letter(code), _) =>
                    if (code == UInt8(83) && ctx.eventModifiers().command) {
                        shortcuts.value += 1
                        true
                    } else {
                        false
                    }
                case _ => false
            }
        }) {
            Spacer()
        }
    }

    @Expect(shortcuts.value, Int64(1))
}

@Test
func widgetTestHostClearsFocusAfterUnclaimedPointerPress(): Unit {
    let host = WidgetTestHost()
    host.context.focus("previous")
    let _ = host.frame(Rect(0.0, 0.0, 120.0, 40.0), events: [UiEvent.MouseDown(MouseButton.Left, 10.0, 10.0)]) {
        Spacer()
    }

    @Expect(host.context.focusId, "")
    @Expect(host.context.leftMouseDown)
}

@Test
func widgetTestHostResetClearsInteractionAndFrameRequests(): Unit {
    let host = WidgetTestHost()
    host.context.focus("focused")
    host.context.requestClose()
    host.context.requestFrame()

    host.reset()
    let result = host.frame(Rect(0.0, 0.0, 120.0, 40.0)) {Spacer()}

    @Expect(host.context.focusId, "")
    @Expect(!host.context.shouldClose)
    @Expect(!result.schedule.hasPending())
}

@Test
func widgetTestHostDamageCullsNonIntersectingRetainedCommandBuffers(): Unit {
    let host = WidgetTestHost()
    let left = State<Int64>(0)
    let body: () -> Unit = {
        => HStack {
            RetainedSubtree("left", cachePaint: true) {
                DamageTextProbe("left ${left.value}")
            }
            RetainedSubtree("right", cachePaint: true) {
                DamageTextProbe("right")
            }
        }
    }
    let viewport = Rect(0.0, 0.0, 200.0, 80.0)
    let first = host.frame(viewport, body: body)
    @Expect(first.metrics.textDraws, UInt64(2))
    let leftBounds = retainedScopeAt(host.retainedDiagnostics().scopes, "left").bounds
    @Expect(leftBounds.w > 0.0)

    left.value = 1
    let damaged = host.frame(viewport, damage: Some(leftBounds), body: body)
    @Expect(damaged.metrics.textDraws, UInt64(1))

    let full = host.frame(viewport, body: body)
    @Expect(full.metrics.textDraws, UInt64(2))
}
