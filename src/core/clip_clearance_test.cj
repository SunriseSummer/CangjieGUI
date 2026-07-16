package cui.core

import sdl.{Rect, Size, UiEvent}

/*
 * Containers that clip children defensively must leave shadow clearance (CUI_SHADOW_CLEARANCE) so a
 * child card's soft halo wraps its rounded corners instead of being sliced into hard-edged bands.
 * The probe records the clip in effect while it draws; the scroll axis must stay exactly bounded.
 */
private class ClipProbe <: Widget {
    var seen: ?Rect = None

    public func measure(_: UiContext, _: Size): Size {
        Size(40.0, 20.0)
    }

    public func layout(_: UiContext, _: Rect): Unit {}

    public func draw(ctx: UiContext): Unit {
        seen = ctx.renderer.currentClip()
    }

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }
}

@Test
func lazyColumnClipLeavesShadowClearanceAcrossOnly(): Unit {
    let ctx = testContext()
    let probe = ClipProbe()
    let column = LazyColumn(1, 60.0, id: "clip.lazycol") {
        _ => emit(probe)
    }
    column.layout(ctx, Rect(0.0, 0.0, 200.0, 300.0))
    column.draw(ctx)
    let clip = probe.seen.getOrThrow()
    // Cross axis widened so a row card's halo survives; scroll axis stays exactly bounded.
    @Expect(clip.x < 0.0)
    @Expect(clip.right() > 200.0)
    @Expect(clip.y, Float32(0.0))
    @Expect(clip.bottom() <= 300.0)
}

@Test
func scrollViewClipLeavesShadowClearanceAcrossOnly(): Unit {
    let ctx = testContext()
    let probe = ClipProbe()
    let view = ScrollView(key: "clip.scroll") {
        emit(probe)
    }
    view.layout(ctx, Rect(10.0, 20.0, 200.0, 300.0))
    view.draw(ctx)
    let clip = probe.seen.getOrThrow()
    @Expect(clip.x < 10.0)
    @Expect(clip.right() > 210.0)
    @Expect(clip.y, Float32(20.0))
    @Expect(clip.bottom() <= 320.0)
}

@Test
func lazyRowClipLeavesShadowClearanceAcrossOnly(): Unit {
    let ctx = testContext()
    let probe = ClipProbe()
    let row = LazyRow(1, 80.0, id: "clip.lazyrow") {
        _ => emit(probe)
    }
    row.layout(ctx, Rect(0.0, 0.0, 300.0, 120.0))
    row.draw(ctx)
    let clip = probe.seen.getOrThrow()
    // Horizontal strip: the scroll axis is horizontal, so clearance goes vertically instead.
    @Expect(clip.y < 0.0)
    @Expect(clip.bottom() > 120.0)
    @Expect(clip.x, Float32(0.0))
    @Expect(clip.right() <= 300.0)
}
