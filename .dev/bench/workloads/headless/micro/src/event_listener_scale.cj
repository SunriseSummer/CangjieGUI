package bench_micro

import cui.{EventListener, EventOutcome, Key, Rect, Renderer, Size, Theme, UiContext, UiEvent, Widget, emit}
import bench_harness.{BenchResult, report, reportCount, timeit}

private let EVENT_LISTENER_FOCUS_LOOKUP_GATE_NS: UInt64 = UInt64(2000)

private class ListenerFocusSetProbe <: Widget {
    private let ids: Array<String>

    init(count: Int64) {
        this.ids = Array<String>(count, {index => "listener.focus.${index}"})
        emit(this)
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

public func measureEventListenerFocusScale(): Unit {
    let count: Int64 = 10000
    let listener = EventListener(onEvent: {_, _ => EventOutcome.Continue}) {ListenerFocusSetProbe(count)}
    let context = UiContext(Renderer.headless(), Theme.light())
    let event = UiEvent.KeyDown(Key.Enter, false)

    context.focus("listener.focus.${count - 1}")
    let hit = timeListenerKeyboardTarget("10k focus 最后命中", listener, context, event)
    context.focus("listener.focus.missing")
    let miss = timeListenerKeyboardTarget("10k focus 未命中", listener, context, event)
    report("micro", "EventListener 焦点目标", hit)
    report("micro", "EventListener 焦点目标", miss)
    if (hit.perIterationNs() > EVENT_LISTENER_FOCUS_LOOKUP_GATE_NS || miss.perIterationNs() >
        EVENT_LISTENER_FOCUS_LOOKUP_GATE_NS) {
        throw IllegalStateException("EventListener focus membership exceeded the 2 us indexed gate")
    }
    reportCount("EventListener 焦点目标", "索引 focus id 数", UInt64(count))
}

private func timeListenerKeyboardTarget(
    name: String,
    listener: Widget,
    context: UiContext,
    event: UiEvent
): BenchResult {
    timeit(name, 2000, {
        => if (listener.handle(context, event)) {
            Int64(1)
        } else {
            Int64(0)
        }
    })
}
