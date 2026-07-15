package cui.core

// A reference-type counter so a build closure can tally invocations (captured vars are read-only).
class LazyBuildCounter {
    var count: Int64 = 0

    func bump(): Unit {
        count += 1
    }
}

// Records which row indices a build closure was asked to materialize.
class LazyBuiltIndices {
    var low: Int64 = Int64.Max
    var high: Int64 = Int64.Min
    var count: Int64 = 0

    func add(index: Int64): Unit {
        count += 1
        if (index < low) {
            low = index
        }
        if (index > high) {
            high = index
        }
    }
}

@Test
func lazyContentHeightSumsRowsAndGaps(): Unit {
    @Expect(lazyContentHeight(0, 100.0, 10.0), 0.0)
    @Expect(lazyContentHeight(1, 100.0, 10.0), 100.0)
    @Expect(lazyContentHeight(3, 100.0, 10.0), 320.0) // 3*110 - trailing 10
}

@Test
func lazyVisibleRangeWindowsAroundScrollWithOverscan(): Unit {
    // Top of a long list: rows 0..(500/100) widened by 2 of overscan, floored at 0.
    let (first0, last0) = lazyVisibleRange(0.0, 500.0, 100.0, 0.0, 1000, 2)
    @Expect(first0, 0)
    @Expect(last0, 7)
    // Scrolled to row 100: window recentres, overscan on both sides.
    let (first1, last1) = lazyVisibleRange(10000.0, 500.0, 100.0, 0.0, 1000, 2)
    @Expect(first1, 98)
    @Expect(last1, 107)
}

@Test
func lazyVisibleRangeClampsToBounds(): Unit {
    // Scrolled past the end, `last` clamps to the final index rather than running off.
    let (_, last) = lazyVisibleRange(99900.0, 500.0, 100.0, 0.0, 1000, 2)
    @Expect(last, 999)
    // Empty list yields an empty range (first > last), so nothing is built.
    let (firstEmpty, lastEmpty) = lazyVisibleRange(0.0, 500.0, 100.0, 0.0, 0, 2)
    @Expect(firstEmpty > lastEmpty, true)
}

@Test
func lazyColumnMaterializesOnlyAScreenful(): Unit {
    let counter = LazyBuildCounter()
    // A thousand rows, but only the default-viewport window (720px / 100px + overscan) is built.
    let column = LazyColumn(1000, 100.0, id: "test.lazy") {
        _ =>
        counter.bump()
        emit(Spacer())
    }
    @Expect(counter.count > 0, true)
    @Expect(counter.count < 20, true)
    // Reference the widget so its construction is not optimised away.
    @Expect(column.isFlexible(), true)
}

@Test
func lazyColumnBuildsWindowAroundExternalScroll(): Unit {
    let built = LazyBuiltIndices()
    // Scroll near row 500 (500 * 100 px). The materialized window should centre there, not at 0.
    let scroll = State<Float32>(50000.0)
    let column = LazyColumn(1000, 100.0, scroll: scroll, id: "test.lazy.scroll") {
        index =>
        built.add(index)
        emit(Spacer())
    }
    @Expect(built.low >= 490, true)
    @Expect(built.low <= 500, true)
    @Expect(built.high >= 505, true)
    @Expect(built.high < 520, true)
    @Expect(column.isFlexible(), true)
}

// The data-driven `LazyColumn.of` must virtualize (build only a screenful) AND hand the row builder
// the DATA elements at the visible indices — not the raw indices — so a list over `Array<T>` needs no
// manual count or data[i] lookup.
@Test
func lazyColumnOfBuildsRowsFromData(): Unit {
    // data[i] == i * 10, so a built value reveals which index it came from.
    let data = Array<Int64>(1000, {i => i * 10})
    let built = LazyBuiltIndices()
    let scroll = State<Float32>(50000.0) // near row 500
    let column = LazyColumn.of<Int64>(data, 100.0, scroll: scroll, key: {v => "v${v}"}, id: "test.of") {
        value =>
        built.add(value)
        emit(Spacer())
    }
    // Only a screenful materialized, not all 1000.
    @Expect(built.count > 0, true)
    @Expect(built.count < 20, true)
    // The builder received data VALUES near row 500 (value == index*10 ~ 4980..5090), proving the
    // index->data mapping, not raw indices (~498..509).
    @Expect(built.low >= 4900, true)
    @Expect(built.high <= 5200, true)
    @Expect(column.isFlexible(), true)
}

// LazyGrid windows by row (data / columns), so a large collection builds only the cells of the
// visible rows, and each built cell is the data element at its grid position.
@Test
func lazyGridBuildsVisibleCellsFromData(): Unit {
    let data = Array<Int64>(1000, {i => i}) // cell value == data index
    let built = LazyBuiltIndices()
    let scroll = State<Float32>(10000.0) // near row 100 of 250 (1000 items / 4 columns)
    let grid = LazyGrid<Int64>(data, 4, 100.0, scroll: scroll, id: "test.grid") {
        value =>
        built.add(value)
        emit(Spacer())
    }
    // Only a screenful of rows' cells built, not all 1000.
    @Expect(built.count > 0, true)
    @Expect(built.count < 60, true)
    // Visible rows ~98..109 × 4 columns → data indices ~392..439.
    @Expect(built.low >= 350, true)
    @Expect(built.high <= 480, true)
    @Expect(grid.isFlexible(), true) // LazyGrid returns the underlying LazyColumn
}
