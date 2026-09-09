package cui_desktop_lifecycle_test

import cui.{Color, DesktopApp, EffectBatch, EffectCleanup, EffectReducer, EffectStore, Label, MouseButton, Rect,
    SdlWindow, Size, State, Transition, UiAggregateException, UiContext, UiEvent, Widget, WidgetTestHost, WindowSpec,
    emit, mountEffect}

private class FailingOwnedResource <: Resource {
    let failure: Exception
    var closed = false
    init(failure: Exception) { this.failure = failure }
    public func isClosed(): Bool { closed }
    public func close(): Unit { closed = true; throw failure }
}

private class FailedFirstDraw <: Widget {
    let failure: Exception
    init(failure: Exception) { this.failure = failure; emit(this) }
    public func measure(_: UiContext, available: Size): Size { available }
    public func layout(_: UiContext, _: Rect): Unit {}
    public func handle(_: UiContext, _: UiEvent): Bool { false }
    public func draw(ctx: UiContext): Unit {
        if (!onlyWindowHidden()) { throw IllegalStateException("failed first frame became visible") }
        ctx.renderer.fill(Rect(10.0, 10.0, 60.0, 40.0), Color.rgb(30, 70, 110))
        throw failure
    }
}

private class FailingRelease <: Widget {
    let failOnce: State<Bool>
    init(failOnce: State<Bool>) { this.failOnce = failOnce; emit(this) }
    public func measure(_: UiContext, available: Size): Size { available }
    public func layout(_: UiContext, _: Rect): Unit {}
    public func draw(ctx: UiContext): Unit {
        ctx.renderer.fill(Rect(10.0, 10.0, 120.0, 70.0), Color.rgb(30, 70, 110))
    }
    public func handle(ctx: UiContext, event: UiEvent): Bool {
        match (event) {
            case UiEvent.MouseDown(MouseButton.Left, _, _) =>
                ctx.beginDrag("release")
                ctx.press("release")
                true
            case UiEvent.MouseUp(MouseButton.Left, _, _) =>
                if (failOnce.value) { failOnce.value = false; throw IllegalStateException("release handler") }
                true
            case _ => false
        }
    }
}

func verifyFailureRecovery(): Bool {
    for (sampling in [Int32(1), Int32(2)]) {
        if (!verifyFailedShutdown(sampling)) { return false }
        try (window = SdlWindow(WindowSpec("Recovery E2E", 240, 140, supersample: sampling), hidden: true)) {
            if (!onlyWindowHidden()) { return false } // the failed DesktopApp left no native window behind
            if (!verifyNativeInputRecovery(window) || !verifyNativeTransactionRecovery(window) ||
                !verifyNativeEffectRecovery(window)) { return false }
        }
    }
    true
}

private func verifyNativeEffectRecovery(window: SdlWindow): Bool {
    let host = WidgetTestHost(renderer: window.renderer)
    let reducer = EffectReducer<Int64, Int64, String>({model, action =>
        Transition<Int64, String>(model + action, effects: EffectBatch<String>("save"))
    })
    let store = EffectStore<Int64, Int64, String>(0, reducer)
    let calls = State<Int64>(0)
    let view: () -> Unit = {=> Label("Model ${store.get()}") }
    let bounds = Rect(0.0, 0.0, 240.0, 140.0)
    let _ = host.frame(bounds, body: view)
    let observation = store.observe({_, _ => throw IllegalStateException("model observer")})
    var count: Int64 = 0
    try {
        store.dispatch(1, handleEffects: {_ => calls.value += 1; throw IllegalArgumentException("effect handler")})
    } catch (error: UiAggregateException) { count = error.failures.size }
    observation.close()
    if (store.get() != 1 || calls.value != 1 || count != 2) { return false }
    store.dispatch(1, handleEffects: {_ => calls.value += 1})
    let _ = host.frame(bounds, body: view)
    host.reset()
    store.get() == 2 && calls.value == 2
}

private func verifyFailedShutdown(sampling: Int32): Bool {
    let primary = IllegalArgumentException("draw failure")
    let firstFailure = IllegalStateException("first resource")
    let lastFailure = IllegalStateException("last resource")
    let effectFailure = IllegalStateException("effect cleanup")
    let first = FailingOwnedResource(firstFailure)
    let last = FailingOwnedResource(lastFailure)
    let effectAttempted = State<Bool>(false)
    let app = DesktopApp(WindowSpec("Failed shutdown E2E", 240, 140, supersample: sampling))
    app.manage(first)
    app.manage(last)
    var captured: ?UiAggregateException = None
    try {
        app.run {
            mountEffect("effect", {=> EffectCleanup({=> effectAttempted.value = true; throw effectFailure})})
            FailedFirstDraw(primary)
        }
    } catch (error: UiAggregateException) { captured = Some(error) }
    match (captured) {
        case Some(error) =>
            let failures = error.failures
            failures.size == 4 && refEq(failures[0], primary) && refEq(failures[1], lastFailure) &&
                refEq(failures[2], firstFailure) && refEq(failures[3], effectFailure) && first.closed && last.closed &&
                effectAttempted.value && !app.post({=> ()})
        case None => false
    }
}

private func interactionIsClear(ctx: UiContext): Bool {
    !ctx.leftMouseDown && ctx.dragId.isEmpty() && ctx.pressedId.isEmpty()
}

private func verifyNativeInputRecovery(window: SdlWindow): Bool {
    let host = WidgetTestHost(renderer: window.renderer)
    let failRelease = State<Bool>(true)
    let failReset = State<Bool>(true)
    let bounds = Rect(0.0, 0.0, 240.0, 140.0)
    let view: () -> Unit = {=>
        mountEffect("reset", {=> EffectCleanup({=>
            if (failReset.value) { failReset.value = false; throw IllegalStateException("reset cleanup") }
        })})
        FailingRelease(failRelease)
    }
    let press = UiEvent.MouseDown(MouseButton.Left, 20.0, 20.0)
    let release = UiEvent.MouseUp(MouseButton.Left, 20.0, 20.0)
    let _ = host.frame(bounds, events: [press], body: view)
    var handlerFailed = false
    try { let _ = host.frame(bounds, events: [release], body: view) }
    catch (_: IllegalStateException) { handlerFailed = true }
    if (!handlerFailed || !interactionIsClear(host.context)) { return false }
    let _ = host.frame(bounds, events: [press, release], body: view)
    if (!interactionIsClear(host.context)) { return false }
    host.context.leftMouseDown = true
    host.context.beginDrag("stale")
    host.context.press("stale")
    var resetFailed = false
    try { host.reset() } catch (_: IllegalStateException) { resetFailed = true }
    if (!resetFailed || !interactionIsClear(host.context)) { return false }
    let _ = host.frame(bounds, events: [press, release], body: view)
    host.reset()
    interactionIsClear(host.context)
}

private func verifyNativeTransactionRecovery(window: SdlWindow): Bool {
    let host = WidgetTestHost(renderer: window.renderer)
    let value = State<Int64>(0)
    let view: () -> Unit = {=> Label("Value ${value.value}") }
    let bounds = Rect(0.0, 0.0, 240.0, 140.0)
    window.renderer.prepareTextLayout(bounds.w, bounds.h)
    let _ = host.frame(bounds, body: view)
    let first = value.observe({_, _ => throw IllegalStateException("listener one")})
    let last = value.observe({_, _ => throw IllegalStateException("listener two")})
    var count: Int64 = 0
    try { host.batch({=> value.value = 1; throw IllegalArgumentException("action")}) }
    catch (error: UiAggregateException) { count = error.failures.size }
    first.close()
    last.close()
    host.batch({=> value.value = 2})
    let _ = host.frame(bounds, body: view)
    host.reset()
    count == 3 && value.value == 2
}
