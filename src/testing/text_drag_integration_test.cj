package cui.testing

import sdl.{MouseButton, Rect, UiEvent}
import cui.core.State
import cui.text.{TextArea, TextField}

@Test
func stationaryOutsideSelectionScrollsThroughFramesAndStopsOnRelease(): Unit {
    let host = WidgetTestHost()
    let value = State<String>("one\ntwo\nthree\nfour\nfive\nsix\nseven\neight\nnine\nten\neleven\ntwelve")
    let cursor = State<Int64>(0); let anchor = State<Int64>(0); let scroll = State<Float32>(0.0)
    let bounds = Rect(0.0, 0.0, 150.0, 90.0)
    let body: () -> Unit = {=> TextArea(value, key: "drag", cursor: cursor, anchor: anchor, scroll: scroll, editable: false); () }
    try {
        let _ = host.frame(bounds, body: body)
        let _ = host.frame(bounds, events: [UiEvent.MouseDown(MouseButton.Left, 10.0, 10.0),
            UiEvent.MouseMove(50.0, 130.0)], body: body)
        let first = cursor.value
        for (tick in 1..8) { let _ = host.frame(bounds, elapsedMs: UInt64(tick * 32), body: body) }
        @Expect(cursor.value > first)
        @Expect(anchor.value, Int64(0))
        @Expect(scroll.value > 0.0)
        let stopped = host.frame(bounds, elapsedMs: UInt64(256),
            events: [UiEvent.MouseUp(MouseButton.Left, 50.0, 130.0)], body: body)
        @Expect(!stopped.schedule.hasPending())
        @Expect(stopped.metrics.frameSubscribers, Int64(0))
        let last = cursor.value
        let _ = host.frame(bounds, elapsedMs: UInt64(500), body: body)
        @Expect(cursor.value, last)
        @Expect(value.value.contains("twelve"))
    } finally { host.reset() }
}

@Test
func stationaryFieldDragExtendsHorizontallyWithoutChangingText(): Unit {
    let host = WidgetTestHost()
    let value = State<String>("abcdefghijklmnopqrstuvwxyz0123456789abcdefghijklmnopqrstuvwxyz")
    let cursor = State<Int64>(0); let anchor = State<Int64>(0)
    let bounds = Rect(0.0, 0.0, 120.0, 50.0)
    let body: () -> Unit = {=> TextField(value, key: "drag", cursor: cursor, anchor: anchor); () }
    try {
        let _ = host.frame(bounds, body: body)
        let _ = host.frame(bounds, events: [UiEvent.MouseDown(MouseButton.Left, 8.0, 25.0),
            UiEvent.MouseMove(180.0, 25.0)], body: body)
        let first = cursor.value
        for (tick in 1..10) { let _ = host.frame(bounds, elapsedMs: UInt64(tick * 32), body: body) }
        @Expect(cursor.value > first)
        @Expect(anchor.value, Int64(0))
        @Expect(value.value.size, Int64(62))
    } finally { host.reset() }
}
