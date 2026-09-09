package cui.core

import sdl.{MouseButton, Rect, Size, UiEvent}

@Test
func nestedScrollViewGivesTheInnerViewportFirstWheelChoice(): Unit {
    let ctx = testContext()
    let innerOffset = State<Float32>(0.0)
    let outerOffset = State<Float32>(0.0)
    let outer = ScrollView(key: "quality.outer") {
        VStack {
            ScrollView(key: "quality.inner") {
                emit(SizedLayoutProbe(Size(100.0, 300.0)))
            }.scrollState(innerOffset).height(60.vp)
            emit(SizedLayoutProbe(Size(100.0, 300.0)))
        }.spacing(0.0).hug()
    }.scrollState(outerOffset)
    let bounds = Rect(0.0, 0.0, 120.0, 120.0)
    outer.layout(ctx, bounds)
    @Expect(outer.handle(ctx, UiEvent.MouseWheel(0.0, -1.0, 20.0, 20.0)))
    @Expect(innerOffset.value, Float32(72.0))
    @Expect(outerOffset.value, Float32(0.0))
    innerOffset.value = 240.0
    outer.layout(ctx, bounds)
    @Expect(outer.handle(ctx, UiEvent.MouseWheel(0.0, -1.0, 20.0, 20.0)))
    @Expect(innerOffset.value, Float32(240.0))
    @Expect(outerOffset.value, Float32(72.0))
}

@Test
func scrollViewBubblesUnchangedAndHorizontalWheelEvents(): Unit {
    let ctx = testContext()
    let offset = State<Float32>(0.0)
    let view = ScrollView(key: "quality.edge") {
        emit(SizedLayoutProbe(Size(100.0, 300.0)))
    }.scrollState(offset)
    view.layout(ctx, Rect(0.0, 0.0, 120.0, 100.0))
    @Expect(!view.handle(ctx, UiEvent.MouseWheel(0.0, 1.0, 20.0, 20.0)))
    @Expect(!view.handle(ctx, UiEvent.MouseWheel(1.0, 0.0, 20.0, 20.0)))
    @Expect(!view.handle(ctx, UiEvent.MouseWheel(0.0, Float32.NaN, 20.0, 20.0)))
    @Expect(!view.handle(ctx, UiEvent.MouseDown(MouseButton.Right, 115.0, 80.0)))
    @Expect(offset.value, Float32(0.0))
}

@Test
func scrollThumbStaysInsideTinyTracksInBothDirections(): Unit {
    let frame = Rect(0.0, 0.0, 10.0, 10.0)
    let vertical = scrollThumbRect(frame, 290.0, 300.0, 10.0).getOrThrow()
    let horizontal = scrollThumbRectH(frame, 290.0, 300.0, 10.0).getOrThrow()
    @Expect(vertical.bottom() <= frame.bottom())
    @Expect(horizontal.right() <= frame.right())
}
