package cui.core

import sdl.{Rect, UiEvent}

private class HeightReadCounter {
    var count: Int64 = 0

    func height(_: Int64): Float32 {
        count += 1
        50.0
    }
}

@Test
func lazyListRowTopsAccumulateHeightsAndSpacing(): Unit {
    let heights: Array<Float32> = [10.0, 20.0, 30.0]
    let extents = LazyExtentIndex()
    extents.reset(3, {i => heights[i]}, 5.0)
    @Expect(extents.topOf(0), Float32(0.0))
    @Expect(extents.topOf(1), Float32(15.0)) // 10 + spacing
    @Expect(extents.topOf(2), Float32(40.0)) // 15 + 20 + spacing
    // Content excludes trailing spacing after the last row: 10+20+30 + 2*5 = 70.
    @Expect(extents.contentExtent(), Float32(70.0))
}

@Test
func lazyListRowTopsHandlesEmpty(): Unit {
    let extents = LazyExtentIndex()
    extents.reset(0, {_ => 50.0}, 4.0)
    @Expect(extents.contentExtent(), Float32(0.0))
    let (first, last) = extents.visibleRange(0.0, 200.0, LazyOverscanInsets(100.0, 100.0))
    @Expect(first > last, true) // empty range
}

@Test
func lazyListVisibleRangeWindowsUniformRows(): Unit {
    let extents = LazyExtentIndex()
    extents.reset(100, {_ => 50.0}, 0.0)
    // Top of the list: rows 0..4 fit a 200px viewport, widened by 100px of overscan.
    let overscan = LazyOverscanInsets(100.0, 100.0)
    let (first0, last0) = extents.visibleRange(0.0, 200.0, overscan)
    @Expect(first0, 0)
    @Expect(last0, 6)
    // Scrolled to row 20: window recentres with overscan both sides.
    let (first1, last1) = extents.visibleRange(1000.0, 200.0, overscan)
    @Expect(first1, 18)
    @Expect(last1, 26)
}

@Test
func lazyListVisibleRangeWindowsVariableRows(): Unit {
    let heights: Array<Float32> = [100.0, 50.0, 200.0, 50.0, 100.0]
    let extents = LazyExtentIndex()
    extents.reset(5, {i => heights[i]}, 0.0)
    // A 100px viewport at offset 160 sits inside row 2; pixel overscan widens to rows 1..3.
    let (first, last) = extents.visibleRange(160.0, 100.0, LazyOverscanInsets(60.0, 90.0))
    @Expect(first, 1)
    @Expect(last, 3)
}

@Test
func lazyListExtentsPointUpdateAdjustsFenwickPrefixes(): Unit {
    let model = LazyListExtents([10.0, 20.0, 30.0], spacing: 5.0)
    let before = model.currentIndex()
    @Expect(before.topOf(1), Float32(15.0))
    @Expect(before.topOf(2), Float32(40.0))
    @Expect(before.contentExtent(), Float32(70.0))

    @Expect(model.update(0, 30.0))
    @Expect(!model.update(0, 30.0))
    let after = model.currentIndex()
    @Expect(after.topOf(1), Float32(35.0))
    @Expect(after.topOf(2), Float32(60.0))
    @Expect(after.contentExtent(), Float32(90.0))
    @Expect(after.rowAt(59.0), Int64(1))
    @Expect(after.rowAt(60.0), Int64(2))
}

@Test
func lazyListRevisionSkipsFullHeightRescanUntilContentChanges(): Unit {
    let store = StateStore()
    let counter = HeightReadCounter()
    let revision = State<UInt64>(1)
    let body: () -> Unit = {
        => LazyList(1000, {index => counter.height(index)}, revision: Some(revision.value), id: "cached.extents") {
            _ => emit(Spacer())
        }
    }
    let _ = buildRoot(body, store)
    @Expect(counter.count, Int64(1000))
    let _ = buildRoot(body, store)
    @Expect(counter.count, Int64(1000))
    revision.value += UInt64(1)
    let _ = buildRoot(body, store)
    @Expect(counter.count, Int64(2000))
}

@Test
func lazyListMutableExtentUpdateKeepsTopStableKeyAnchored(): Unit {
    let store = StateStore()
    let controller = LazyViewportController()
    let model = LazyListExtents([40.0, 40.0, 40.0, 40.0, 40.0, 40.0])
    let body: () -> Unit = {
        => LazyList(model, key: {index => "row.${index}"}, id: "mutable.extents", controller: controller) {
            _ => emit(Spacer())
        }
    }
    let first = buildRoot(body, store)
    first.layout(testContext(), Rect(0.0, 0.0, 200.0, 80.0))
    controller.scrollToKey("row.3", alignment: LazyScrollAlignment.Start)
    let revealed = buildRoot(body, store)
    revealed.layout(testContext(), Rect(0.0, 0.0, 200.0, 80.0))
    @Expect(controller.offset, Float32(120.0))

    @Expect(model.update(0, 60.0))
    let resized = buildRoot(body, store)
    resized.layout(testContext(), Rect(0.0, 0.0, 200.0, 80.0))
    @Expect(controller.offset, Float32(140.0))
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
    rowLayout(ctx, list) // tall viewport so all four are visible

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
private func rowLayout(ctx: UiContext, list: LazyList): Unit {
    list.layout(ctx, Rect(0.0, 0.0, 300.0, 1000.0))
}
