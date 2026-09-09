package cui.core

import std.collection.ArrayList
import sdl.{MouseButton, Rect, Size, UiEvent, UiEventRecord}

@Test
func failedPointerRoutingStillCompletesTheRelease(): Unit {
    let ctx = testContext()
    let completed = State<Bool>(false)
    var failed = false
    try {
        dispatchEventRecord(UiEventRecord(UiEvent.MouseUp(MouseButton.Left, 10.0, 10.0)), ctx,
            {_ => ()}, {_ => throw IllegalStateException("handler failed")}, {_ => completed.value = true})
    } catch (_: IllegalStateException) { failed = true }
    @Expect(failed)
    @Expect(completed.value)
}

@Test
func effectCleanupKeepsAllFailuresAndCanRetryAfterClear(): Unit {
    let store = StateStore()
    let log = ArrayList<String>()
    let _ = buildRoot({=>
        mountEffect("first", {=> EffectProbe("first", log, failures: 1)})
        mountEffect("second", {=> EffectProbe("second", log, failures: 1)})
        Spacer()
    }, store)
    var message = ""
    try { store.clear() } catch (error: Exception) { message = error.message }
    @Expect(message.contains("cleanup:first") && message.contains("cleanup:second"))
    store.clear()
    @Expect(retainedGraphDiagnostics(store).failedEffectCleanupCount, Int64(0))
}

@Test
func stateNotificationKeepsAllFailuresAndRemainsReusable(): Unit {
    let value = State<Int64>(0)
    let first = value.observe({_, _ => throw IllegalStateException("first-listener")})
    let last = value.observe({_, _ => throw IllegalArgumentException("last-listener")})
    var message = ""
    try { value.value = 1 } catch (error: Exception) { message = error.message }
    @Expect(message.contains("first-listener") && message.contains("last-listener"))
    first.close()
    last.close()
    value.value = 2
    @Expect(value.value, Int64(2))
}

@Test
func nonFiniteEnvironmentScalesRestoreUsableDefaults(): Unit {
    let ctx = testContext()
    ctx.displayScale = Float32.NaN
    ctx.fontScale = Float32.Inf
    @Expect(ctx.displayScale, Float32(1.0))
    @Expect(ctx.fontScale, Float32(1.0))
}

@Test
func nonFiniteExternalScrollOffsetRecoversBeforeChildLayout(): Unit {
    let ctx = testContext()
    let offset = State<Float32>(Float32.NaN)
    let probe = SizedLayoutProbe(Size(100.0, 400.0))
    let view = ScrollView(key: "non-finite-offset") { emit(probe) }.scrollState(offset)
    view.layout(ctx, Rect(0.0, 0.0, 120.0, 100.0))
    @Expect(offset.value, Float32(0.0))
    @Expect(probe.rect.y, Float32(0.0))
    offset.value = Float32.Inf
    view.layout(ctx, Rect(0.0, 0.0, 120.0, 100.0))
    @Expect(offset.value, Float32(300.0))
}

