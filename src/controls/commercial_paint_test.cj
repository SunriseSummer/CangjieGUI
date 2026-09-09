package cui.controls

import sdl.{Rect, Renderer, Size}
import cui.core.{FrameScheduler, State, StateStore, Theme, UiContext, buildRoot, withFrameScheduler}

@Test
func commercialTablePaintDoesNotInvalidateAnIdleFrame(): Unit {
    let scheduler = FrameScheduler()
    withFrameScheduler(scheduler, {=>
        let ctx = UiContext(Renderer.headless(), Theme.light())
        let store = StateStore()
        let selected = State<Int64>(0)
        let widget = buildRoot({=> Table([TableColumn("Name", 150.0)], [["alpha"], ["beta"]], selected)}, store)
        let _ = widget.measure(ctx, Size(240.0, 150.0))
        widget.layout(ctx, Rect(0.0, 0.0, 240.0, 150.0))
        widget.draw(ctx)
        let before = scheduler.generation
        for (_ in 0..5) { widget.draw(ctx) }
        @Expect(scheduler.generation, before)
        store.clear()
    })
}

@Test
func commercialTableRestoresClipWhenCustomCellThrows(): Unit {
    let renderer = Renderer.headless()
    let ctx = UiContext(renderer, Theme.light())
    let table = Table([TableColumn("Name", 150.0, cell: {_, _, _, _ => throw IllegalStateException("cell failed")})],
        [["alpha"]], State<Int64>(0))
    table.layout(ctx, Rect(0.0, 0.0, 240.0, 150.0))
    let outer = Rect(2.0, 2.0, 200.0, 100.0)
    renderer.pushClip(outer)
    var failed = false
    try { table.draw(ctx) } catch (_: IllegalStateException) { failed = true }
    @Expect(failed)
    @Expect(renderer.currentClip().getOrThrow().y, outer.y)
    @Expect(renderer.currentClip().getOrThrow().h, outer.h)
    renderer.popClip()
    @Expect(renderer.currentClip().isNone())
}
