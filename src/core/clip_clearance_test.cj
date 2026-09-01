package cui.core

import sdl.{Rect, Renderer, Size, UiEvent}

/*
 * Containers that clip children defensively consume each child's explicit PaintOutset so a large
 * custom halo is preserved without widening every unrelated subtree by a fixed global constant.
 * The probe records the clip in effect while it draws; the scroll axis must stay exactly bounded.
 */
private class ClipProbe <: Widget {
    var seen: ?Rect = None
    private let overflow: PaintOutset

    init(overflow!: PaintOutset = PaintOutset()) {
        this.overflow = overflow
    }

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

    public func paintOutset(): PaintOutset {
        overflow
    }
}

private class PaintCullProbe <: Widget {
    let preferredHeight: Float32
    let overflow: PaintOutset
    var layouts: Int64 = 0
    var draws: Int64 = 0
    var seenVisibility: ?Rect = None

    init(height: Float32, overflow!: PaintOutset = PaintOutset()) {
        this.preferredHeight = height
        this.overflow = overflow
    }

    public func measure(_: UiContext, available: Size): Size {
        Size(available.w, preferredHeight)
    }

    public func layout(_: UiContext, _: Rect): Unit {
        layouts += 1
    }

    public func draw(ctx: UiContext): Unit {
        draws += 1
        seenVisibility = ctx.currentSpatialVisibility()
    }

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }

    public func paintOutset(): PaintOutset {
        overflow
    }
}

private func probePaintOutset(): PaintOutset {
    PaintOutset(left: 24.0, top: 12.0, right: 32.0, bottom: 20.0)
}

private func throwingSpatialClipDraw(ctx: UiContext): Unit {
    ctx.drawWithinSpatialClip(exactSpatialClip(Rect(20.0, 20.0, 40.0, 40.0))) {
        => throw IllegalStateException("clip draw failed")
    }
}

@Test
func spatialPaintClipRestoresParentAfterDrawFailure(): Unit {
    let renderer = Renderer.headless()
    let context = UiContext(renderer, Theme.light())
    renderer.pushClip(Rect(10.0, 10.0, 100.0, 100.0))
    var failed = false
    try {
        throwingSpatialClipDraw(context)
    } catch (error: IllegalStateException) {
        failed = error.message == "clip draw failed"
    }
    @Expect(failed)
    let restored = renderer.currentClip().getOrThrow()
    @Expect(restored.x, Float32(10.0))
    @Expect(restored.y, Float32(10.0))
    @Expect(restored.w, Float32(100.0))
    @Expect(restored.h, Float32(100.0))
    @Expect(context.currentSpatialVisibility().isNone())
    renderer.popClip()
}

@Test
func lazyColumnClipLeavesShadowClearanceAcrossOnly(): Unit {
    let ctx = testContext()
    let probe = ClipProbe(overflow: probePaintOutset())
    let column = LazyColumn(1, 60.0, id: "clip.lazycol") {
        _ => emit(probe)
    }
    column.layout(ctx, Rect(0.0, 0.0, 200.0, 300.0))
    column.draw(ctx)
    let clip = probe.seen.getOrThrow()
    // Cross axis widened so a row card's halo survives; scroll axis stays exactly bounded.
    @Expect(clip.x, Float32(-24.0))
    @Expect(clip.right(), Float32(232.0))
    @Expect(clip.y, Float32(0.0))
    @Expect(clip.bottom() <= 300.0)
}

@Test
func scrollViewClipLeavesShadowClearanceAcrossOnly(): Unit {
    let ctx = testContext()
    let probe = ClipProbe(overflow: probePaintOutset())
    let view = ScrollView(key: "clip.scroll") {
        emit(probe)
    }
    view.layout(ctx, Rect(10.0, 20.0, 200.0, 300.0))
    view.draw(ctx)
    let clip = probe.seen.getOrThrow()
    @Expect(clip.x, Float32(-14.0))
    @Expect(clip.right(), Float32(242.0))
    @Expect(clip.y, Float32(20.0))
    @Expect(clip.bottom() <= 320.0)
}

@Test
func lazyRowClipLeavesShadowClearanceAcrossOnly(): Unit {
    let ctx = testContext()
    let probe = ClipProbe(overflow: probePaintOutset())
    let row = LazyRow(1, 80.0, id: "clip.lazyrow") {
        _ => emit(probe)
    }
    row.layout(ctx, Rect(0.0, 0.0, 300.0, 120.0))
    row.draw(ctx)
    let clip = probe.seen.getOrThrow()
    // Horizontal strip: the scroll axis is horizontal, so clearance goes vertically instead.
    @Expect(clip.y, Float32(-12.0))
    @Expect(clip.bottom(), Float32(140.0))
    @Expect(clip.x, Float32(0.0))
    @Expect(clip.right() <= 300.0)
}

@Test
func scrollViewWithoutDeclaredOverflowKeepsExactCrossAxisClip(): Unit {
    let ctx = testContext()
    let probe = ClipProbe()
    let view = ScrollView(key: "clip.exact") {
        emit(probe)
    }
    view.layout(ctx, Rect(10.0, 20.0, 200.0, 300.0))
    view.draw(ctx)
    let clip = probe.seen.getOrThrow()
    @Expect(clip.x, Float32(10.0))
    @Expect(clip.right(), Float32(210.0))
    @Expect(clip.y, Float32(20.0))
    @Expect(clip.bottom(), Float32(320.0))
}

@Test
func scrollViewCullsOnlyChildrenWhoseDeclaredPaintBoundsAreDisjoint(): Unit {
    let ctx = testContext()
    let first = PaintCullProbe(40.0)
    let second = PaintCullProbe(40.0)
    let third = PaintCullProbe(40.0)
    let scroll = State<Float32>(80.0)
    let view = ScrollView(key: "paint.cull") {
        VStack(spacing: vpLength(0.0)) {
            emit(first)
            emit(second)
            emit(third)
        }.flexible(false)
    }.scrollState(scroll)

    view.layout(ctx, Rect(0.0, 0.0, 100.0, 40.0))
    view.draw(ctx)

    @Expect(first.layouts, Int64(1))
    @Expect(second.layouts, Int64(1))
    @Expect(third.layouts, Int64(1))
    @Expect(first.draws, Int64(0))
    @Expect(second.draws, Int64(0))
    @Expect(third.draws, Int64(1))
    @Expect(third.seenVisibility.isSome())

    // The transient bounds are refreshed by the next layout; culling is not a one-shot decision.
    scroll.value = 0.0
    view.layout(ctx, Rect(0.0, 0.0, 100.0, 40.0))
    view.draw(ctx)
    @Expect(first.layouts, Int64(2))
    @Expect(second.layouts, Int64(2))
    @Expect(third.layouts, Int64(2))
    @Expect(first.draws, Int64(1))
    @Expect(second.draws, Int64(0))
    @Expect(third.draws, Int64(1))
}

@Test
func scrollViewPaintCullingIncludesDeclaredOverflow(): Unit {
    let ctx = testContext()
    let halo = PaintCullProbe(40.0, overflow: PaintOutset(bottom: 30.0))
    let visible = PaintCullProbe(40.0)
    let tail = PaintCullProbe(40.0)
    let view = ScrollView(key: "paint.cull.overflow") {
        VStack(spacing: vpLength(0.0)) {
            emit(halo)
            emit(visible)
            emit(tail)
        }.flexible(false)
    }.scrollState(State<Float32>(40.0))

    view.layout(ctx, Rect(0.0, 0.0, 100.0, 40.0))
    view.draw(ctx)

    @Expect(halo.draws, Int64(1))
    @Expect(visible.draws, Int64(1))
    @Expect(tail.draws, Int64(0))
}
