package cui.testing

import sdl.{Key, MouseButton, Rect, Renderer, Size, UiEvent}
import cui.core.{Button, EventListener, EventOutcome, EventPhase, State, Theme, UiContext, Widget, emit}

private class PropagationLeaf <: Widget {
    private let trace: State<String>
    private var frame = Rect.zero()

    init(trace: State<String>) {
        this.trace = trace
    }

    public func measure(_: UiContext, available: Size): Size {
        available
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(_: UiContext): Unit {}

    public func handle(_: UiContext, event: UiEvent): Bool {
        match (event) {
            case UiEvent.MouseDown(MouseButton.Left, x, y) where frame.contains(x, y) =>
                trace.value += "X"
                true
            case _ => false
        }
    }
}

private class FocusMetadataLeaf <: Widget {
    private let ids: Array<String>

    init(ids: Array<String>) {
        this.ids = ids
    }

    public func measure(_: UiContext, available: Size): Size {
        available
    }

    public func layout(_: UiContext, _: Rect): Unit {}

    public func draw(_: UiContext): Unit {}

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }

    public func focusableIds(): Array<String> {
        ids
    }
}

@Test
func nestedEventListenersRunCaptureTargetThenBubble(): Unit {
    let host = WidgetTestHost()
    let trace = State<String>("")

    let _ = host.frame(Rect(0.0, 0.0, 120.0, 40.0), events: [
        UiEvent.MouseDown(MouseButton.Left, 10.0, 10.0)
    ]) {
        EventListener(phase: EventPhase.Capture, onEvent: {_, _ => appendOutcome(trace, "C")}) {
            EventListener(phase: EventPhase.Bubble, onEvent: {_, _ => appendOutcome(trace, "B")}) {
                EventListener(phase: EventPhase.Target, onEvent: {_, _ => appendOutcome(trace, "T")}) {
                    emit(PropagationLeaf(trace))
                }
            }
        }
    }

    @Expect(trace.value, "CTXB")
}

@Test
func captureConsumeStopsTargetAndBubble(): Unit {
    let host = WidgetTestHost()
    let trace = State<String>("")

    let _ = host.frame(Rect(0.0, 0.0, 120.0, 40.0), events: [
        UiEvent.MouseDown(MouseButton.Left, 10.0, 10.0)
    ]) {
        EventListener(phase: EventPhase.Capture, onEvent: {
            _, _ =>
                trace.value += "C"
                EventOutcome.Consume
        }) {
            EventListener(phase: EventPhase.Bubble, onEvent: {_, _ => appendOutcome(trace, "B")}) {
                emit(PropagationLeaf(trace))
            }
        }
    }

    @Expect(trace.value, "C")
}

@Test
func fluentOnEventWrapsTheAlreadyEmittedWidget(): Unit {
    let host = WidgetTestHost()
    let trace = State<String>("")

    let _ = host.frame(Rect(0.0, 0.0, 120.0, 40.0), events: [
        UiEvent.MouseDown(MouseButton.Left, 10.0, 10.0)
    ]) {
        let _ = Button("Target", {=>}).onEvent(
            phase: EventPhase.Bubble,
            handler: {_, _ => appendOutcome(trace, "B")}
        )
    }

    @Expect(trace.value, "B")
}

@Test
func eventListenerTargetsKeyboardFocusAcrossAdaptiveMetadataSizes(): Unit {
    let context = UiContext(Renderer.headless(), Theme.light())
    let smallCalls = State<Int64>(0)
    let largeCalls = State<Int64>(0)
    let small = EventListener(onEvent: {
        _, _ =>
            smallCalls.value += 1
            EventOutcome.Continue
    }) {emit(FocusMetadataLeaf(["small.a", "small.b"]))}
    let largeIds = Array<String>(32, {index => "large.${index}"})
    let large = EventListener(onEvent: {
        _, _ =>
            largeCalls.value += 1
            EventOutcome.Continue
    }) {emit(FocusMetadataLeaf(largeIds))}

    context.focus("small.b")
    let _ = small.handle(context, UiEvent.KeyDown(Key.Enter, false))
    context.focus("large.31")
    let _ = large.handle(context, UiEvent.KeyDown(Key.Enter, false))
    context.focus("missing")
    let _ = large.handle(context, UiEvent.KeyDown(Key.Enter, false))

    @Expect(smallCalls.value, Int64(1))
    @Expect(largeCalls.value, Int64(1))
    @Expect(large.focusableIds(), largeIds)
}

@Test
func eventListenerDoesNotAliasFocusedDuplicateKeyOutsideItsElementSubtree(): Unit {
    let host = WidgetTestHost()
    let listenerCalls = State<Int64>(0)
    let body: () -> Unit = {
        => let _ = Button("Outside", {=>}).key("shared")
        EventListener(onEvent: {
            _, _ =>
                listenerCalls.value += 1
                EventOutcome.Continue
        }) {
            let _ = Button("Inside", {=>}).key("shared")
        }
    }

    let _ = host.frame(Rect(0.0, 0.0, 200.0, 80.0), body: body)
    host.context.focus("shared")
    let _ = host.frame(Rect(0.0, 0.0, 200.0, 80.0), events: [UiEvent.KeyDown(Key.Enter, false)], body: body)

    @Expect(listenerCalls.value, Int64(0))
}

@Test
func eventListenerAcceptsFocusedTargetOwnedByItsElementSubtree(): Unit {
    let host = WidgetTestHost()
    let listenerCalls = State<Int64>(0)
    let body: () -> Unit = {
        => let _ = Button("Outside", {=>}).key("outside")
        EventListener(onEvent: {
            _, _ =>
                listenerCalls.value += 1
                EventOutcome.Continue
        }) {
            let _ = Button("Inside", {=>}).key("inside")
        }
    }

    let _ = host.frame(Rect(0.0, 0.0, 200.0, 80.0), body: body)
    host.context.focus("inside")
    let _ = host.frame(Rect(0.0, 0.0, 200.0, 80.0), events: [UiEvent.KeyDown(Key.Enter, false)], body: body)

    @Expect(listenerCalls.value, Int64(1))
}

@Test
func fluentEventListenerDoesNotAliasFocusedDuplicateKeyOutsideItsEmission(): Unit {
    let host = WidgetTestHost()
    let listenerCalls = State<Int64>(0)
    let body: () -> Unit = {
        => let _ = Button("Outside", {=>}).key("shared")
        let _ = Button("Inside", {=>})
            .key("shared")
            .onEvent(handler: {
                _, _ =>
                    listenerCalls.value += 1
                    EventOutcome.Continue
            })
    }

    let _ = host.frame(Rect(0.0, 0.0, 200.0, 80.0), body: body)
    host.context.focus("shared")
    let _ = host.frame(Rect(0.0, 0.0, 200.0, 80.0), events: [UiEvent.KeyDown(Key.Enter, false)], body: body)

    @Expect(listenerCalls.value, Int64(0))
}

@Test
func fluentEventListenerKeepsDisabledFocusDeclarationTombstoned(): Unit {
    let host = WidgetTestHost()
    let listenerCalls = State<Int64>(0)
    let body: () -> Unit = {
        => let _ = Button("Outside", {=>}).key("shared")
        let _ = Button("Disabled", {=>})
            .key("shared")
            .enabled(false)
            .onEvent(handler: {
                _, _ =>
                    listenerCalls.value += 1
                    EventOutcome.Continue
            })
    }

    let _ = host.frame(Rect(0.0, 0.0, 200.0, 80.0), body: body)
    host.context.focus("shared")
    let _ = host.frame(Rect(0.0, 0.0, 200.0, 80.0), events: [UiEvent.KeyDown(Key.Enter, false)], body: body)

    @Expect(listenerCalls.value, Int64(0))
}

private func appendOutcome(trace: State<String>, value: String): EventOutcome {
    trace.value += value
    EventOutcome.Continue
}
