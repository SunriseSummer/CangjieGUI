package bench_micro

import cui.{Rect, Size, State, UiContext, UiEvent, Widget, WidgetTestHost, emit}
import bench_harness.reportCount

private class FocusMetadataBenchCounter {
    var queries: Int64 = 0
}

private class LegacyFocusMetadataBenchWidget <: Widget {
    private let counter: FocusMetadataBenchCounter

    init(counter: FocusMetadataBenchCounter) {
        this.counter = counter
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
        counter.queries += 1
        []
    }
}

public func measureAutomaticFocusMetadataQueries(): Unit {
    let count: Int64 = 10000
    let host = WidgetTestHost()
    let revision = State<Int64>(0)
    let counter = FocusMetadataBenchCounter()
    let body: () -> Unit = {
        =>
            let _ = revision.value
            for (_ in 0..count) {
                LegacyFocusMetadataBenchWidget(counter)
            }
    }
    let _ = host.frame(Rect(0.0, 0.0, 100.0, 40.0), body: body)
    counter.queries = 0
    revision.value = 1
    let _ = host.frame(Rect(0.0, 0.0, 100.0, 40.0), body: body)
    if (counter.queries != 0) {
        throw IllegalStateException("Automatic records recursively queried legacy focus metadata")
    }
    reportCount("焦点扩展性", "10k automatic legacy focusableIds 查询", UInt64(counter.queries))
}
