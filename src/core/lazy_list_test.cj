package cui.core

import sdl.{Rect, UiEvent}

@Test
func lazyListRowTopsAccumulateHeightsAndSpacing(): Unit {
    let heights: Array<Float32> = [10.0, 20.0, 30.0]
    let tops = lazyListRowTops(3, {i => heights[i]}, 5.0)
    @Expect(tops.size, 4)
    @Expect(tops[0], Float32(0.0))
    @Expect(tops[1], Float32(15.0)) // 10 + spacing
    @Expect(tops[2], Float32(40.0)) // 15 + 20 + spacing
    // Content excludes trailing spacing after the last row: 10+20+30 + 2*5 = 70.
    @Expect(tops[3], Float32(70.0))
}

@Test
func lazyListRowTopsHandlesEmpty(): Unit {
    let tops = lazyListRowTops(0, {_ => 50.0}, 4.0)
    @Expect(tops.size, 1)
    @Expect(tops[0], Float32(0.0))
    let (first, last) = lazyListVisibleRange(tops, 0.0, 200.0, 2)
    @Expect(first > last, true) // empty range
}

@Test
func lazyListVisibleRangeWindowsUniformRows(): Unit {
    let tops = lazyListRowTops(100, {_ => 50.0}, 0.0) // tops[i] = 50*i, content 5000
    // Top of the list: rows 0..4 fit a 200px viewport, widened by 2 of overscan.
    let (first0, last0) = lazyListVisibleRange(tops, 0.0, 200.0, 2)
    @Expect(first0, 0)
    @Expect(last0, 6)
    // Scrolled to row 20: window recentres with overscan both sides.
    let (first1, last1) = lazyListVisibleRange(tops, 1000.0, 200.0, 2)
    @Expect(first1, 18)
    @Expect(last1, 26)
}

@Test
func lazyListVisibleRangeWindowsVariableRows(): Unit {
    let heights: Array<Float32> = [100.0, 50.0, 200.0, 50.0, 100.0]
    let tops = lazyListRowTops(5, {i => heights[i]}, 0.0) // tops = [0,100,150,350,400,500]
    // A 100px viewport at offset 160 sits inside row 2; overscan 1 widens to rows 1..3.
    let (first, last) = lazyListVisibleRange(tops, 160.0, 100.0, 1)
    @Expect(first, 1)
    @Expect(last, 3)
}

@Test
func lazyListMaterializesOnlyAScreenful(): Unit {
    let counter = LazyBuildCounter()
    let list = LazyList(1000, {_ => 50.0}, id: "test.lazylist") {
        _ =>
        counter.bump()
        emit(Spacer())
    }
    @Expect(counter.count > 0, true)
    @Expect(counter.count < 30, true) // ~720/50 + overscan, not 1000
    @Expect(list.isFlexible(), true)
}

@Test
func lazyListLaysRowsAtVariableOffsets(): Unit {
    let ctx = testContext()
    let heights: Array<Float32> = [80.0, 40.0, 120.0, 40.0]
    let probes = Array<LayoutProbe>(4, {_ => LayoutProbe()})
    let list = LazyList(4, {i => heights[i]}, id: "test.lazylist.layout") {
        index => emit(probes[index])
    }
    row_layout(ctx, list) // tall viewport so all four are visible

    // tops = [0, 80, 120, 240]; each row is placed at its cumulative top with its own height.
    @Expect(probes[0].rect.y, Float32(0.0))
    @Expect(probes[0].rect.h, Float32(80.0))
    @Expect(probes[1].rect.y, Float32(80.0))
    @Expect(probes[2].rect.y, Float32(120.0))
    @Expect(probes[2].rect.h, Float32(120.0))
    @Expect(probes[3].rect.y, Float32(240.0))
}

@Test
func lazyListOfVirtualizesOverData(): Unit {
    let counter = LazyBuildCounter()
    let data = Array<Int64>(1000, {i => i})
    let list = LazyList.of(data, {_ => 50.0}, id: "test.lazylist.of") {
        _ =>
        counter.bump()
        emit(Spacer())
    }
    @Expect(counter.count > 0, true)
    @Expect(counter.count < 30, true)
    @Expect(list.isFlexible(), true)
}

@Test
func lazyListWheelScrollsVertically(): Unit {
    let ctx = testContext()
    let scroll = State<Float32>(0.0)
    let list = LazyList(1000, {_ => 50.0}, scroll: scroll, id: "test.lazylist.wheel") {
        _ => emit(Spacer())
    }
    list.layout(ctx, Rect(0.0, 0.0, 300.0, 400.0))
    @Expect(list.handle(ctx, UiEvent.MouseWheel(0.0, -1.0, 150.0, 200.0)))
    @Expect(scroll.value, Float32(72.0)) // one wheel step
}

// Lays out a list in a viewport tall enough to show every one of the (few) test rows.
private func row_layout(ctx: UiContext, list: LazyList): Unit {
    list.layout(ctx, Rect(0.0, 0.0, 300.0, 1000.0))
}
