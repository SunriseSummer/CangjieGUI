package cui.core

import sdl.{Rect, UiEvent}

@Test
func lazyRowMaterializesOnlyAScreenful(): Unit {
    let counter = LazyBuildCounter()
    // A thousand columns, but only the default-viewport window (720px / 100px + overscan) is built.
    let row = LazyRow(1000, 100.0, id: "test.lazyrow") {
        _ =>
        counter.bump()
        emit(Spacer())
    }
    @Expect(counter.count > 0, true)
    @Expect(counter.count < 20, true)
    @Expect(row.isFlexible(), true)
}

@Test
func lazyRowBuildsWindowAroundExternalScroll(): Unit {
    let built = LazyBuiltIndices()
    // Scroll near column 500 (500 * 100 px). The materialized window should centre there, not at 0.
    let scroll = State<Float32>(50000.0)
    let row = LazyRow(1000, 100.0, scroll: scroll, id: "test.lazyrow.scroll") {
        index =>
        built.add(index)
        emit(Spacer())
    }
    @Expect(built.low >= 490, true)
    @Expect(built.low <= 500, true)
    @Expect(built.high >= 505, true)
    @Expect(built.high < 520, true)
}

@Test
func lazyRowOfVirtualizesOverData(): Unit {
    let counter = LazyBuildCounter()
    let data = Array<Int64>(1000, {i => i})
    let row = LazyRow.of(data, 100.0, id: "test.lazyrow.of") {
        _ =>
        counter.bump()
        emit(Spacer())
    }
    @Expect(counter.count > 0, true)
    @Expect(counter.count < 20, true) // windowed, not all 1000 built
    @Expect(row.isFlexible(), true)
}

@Test
func lazyRowLaysColumnsLeftToRight(): Unit {
    let ctx = testContext()
    let probes = Array<LayoutProbe>(5, {_ => LayoutProbe()})
    let row = LazyRow(5, 100.0, spacing: 10.0, id: "test.lazyrow.layout") {
        index => emit(probes[index])
    }
    row.layout(ctx, Rect(0.0, 0.0, 500.0, 200.0))

    // Columns stride by width + spacing: col 0 at x=0, col 1 at x=110, col 2 at x=220.
    @Expect(probes[0].rect.x, Float32(0.0))
    @Expect(probes[0].rect.w, Float32(100.0))
    @Expect(probes[1].rect.x, Float32(110.0))
    @Expect(probes[2].rect.x, Float32(220.0))
    // Content (540) overflows the 500 viewport, so the bottom bar lane is reserved from item height.
    @Expect(probes[0].rect.h < Float32(200.0))
}

@Test
func lazyRowWheelScrollsHorizontally(): Unit {
    let ctx = testContext()
    let scroll = State<Float32>(0.0)
    let row = LazyRow(100, 100.0, scroll: scroll, id: "test.lazyrow.wheel") {
        _ => emit(Spacer())
    }
    row.layout(ctx, Rect(0.0, 0.0, 500.0, 200.0))

    // Wheel toward the user (scroll down) advances the strip by one wheel step (72px).
    @Expect(row.handle(ctx, UiEvent.MouseWheel(0.0, -1.0, 250.0, 100.0)))
    @Expect(scroll.value, Float32(72.0))
}

@Test
func lazyRowHorizontalWheelPansTheStrip(): Unit {
    let ctx = testContext()
    let scroll = State<Float32>(0.0)
    let row = LazyRow(100, 100.0, scroll: scroll, id: "test.lazyrow.hwheel") {
        _ => emit(Spacer())
    }
    row.layout(ctx, Rect(0.0, 0.0, 500.0, 200.0))

    // A horizontal delta (trackpad pan / tilt wheel, wheel.x positive to the right) pans right
    // directly, taking precedence over the vertical remap.
    @Expect(row.handle(ctx, UiEvent.MouseWheel(1.0, 0.0, 250.0, 100.0)))
    @Expect(scroll.value, Float32(72.0))
    // Panning back left returns to the start (clamped at 0).
    @Expect(row.handle(ctx, UiEvent.MouseWheel(-1.0, 0.0, 250.0, 100.0)))
    @Expect(scroll.value, Float32(0.0))
}

@Test
func horizontalScrollThumbGeometryMapsBothWays(): Unit {
    let frame = Rect(0.0, 0.0, 100.0, 40.0)
    // Content that fits shows no bar.
    @Expect(scrollThumbRectH(frame, 0.0, 80.0, 100.0).isNone())
    // Overflowing content yields a thumb; the offset round-trips through the thumb's left edge.
    @Expect(scrollThumbRectH(frame, 0.0, 300.0, 100.0).isSome())
    let track = scrollBarTrackRectH(frame)
    let thumbW = scrollThumbWidth(track, 300.0, 100.0)
    let thumbLeft = scrollThumbLeft(track, thumbW, 100.0, 300.0, 100.0)
    @Expect(scrollOffsetForThumbLeft(thumbLeft, track, thumbW, 300.0, 100.0), Float32(100.0))
}

@Test
func horizontalScrollBarDragUpdatesOffset(): Unit {
    let ctx = testContext()
    ctx.leftMouseDown = true
    let bar = HScrollBar("row.bar")
    let offset = State<Float32>(0.0)
    let frame = Rect(0.0, 0.0, 200.0, 60.0)
    // Grab the thumb at its left edge, then drag it to the track's far right → maximum offset.
    let thumb = scrollThumbRectH(frame, 0.0, 800.0, 200.0).getOrThrow()
    @Expect(bar.press(ctx, frame, offset, 800.0, 200.0, thumb.x + 1.0, thumb.y + 1.0))
    let _ = bar.drag(ctx, frame, offset, 800.0, 200.0, 1000.0)
    @Expect(offset.value, Float32(600.0)) // content 800 - viewport 200
}
