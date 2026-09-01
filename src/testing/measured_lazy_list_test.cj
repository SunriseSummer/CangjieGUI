package cui.testing

import sdl.{Rect, Size, UiEvent}
import cui.core.{LazyList, LazyScrollAlignment, LazyViewportController, State, UiContext, Widget, emit}

private class HostMeasuredRow <: Widget {
    private let preferredHeight: () -> Float32
    var frame = Rect.zero()

    init(preferredHeight: () -> Float32) {
        this.preferredHeight = preferredHeight
    }

    public func measure(_: UiContext, available: Size): Size {
        Size(available.w, preferredHeight())
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(_: UiContext): Unit {}

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }
}

@Test
func measuredLazyListSettlesOneBatchedExtentCorrectionPerFrame(): Unit {
    let host = WidgetTestHost()
    let firstHeight = State<Float32>(80.0)
    let rows = Array<HostMeasuredRow>(32, {
        index => if (index == 0) {
            HostMeasuredRow({=> firstHeight.value})
        } else {
            HostMeasuredRow({=> 40.0})
        }
    })
    let body: () -> Unit = {
        => LazyList.measured(1000, estimatedHeight: 50.0, id: "host.measured") {
            index => emit(rows[index])
        }
    }
    let viewport = Rect(0.0, 0.0, 300.0, 180.0)

    let first = host.frame(viewport, body: body)
    @Expect(first.metrics.stabilizationPasses, Int64(2))
    @Expect(rows[1].frame.y, Float32(80.0))

    firstHeight.value = 120.0
    let resized = host.frame(viewport, body: body)
    @Expect(resized.metrics.stabilizationPasses, Int64(2))
    @Expect(rows[1].frame.y, Float32(120.0))
}

@Test
func measuredLazyListKeepsTopKeyAnchoredWhenPrecedingRowRemeasures(): Unit {
    let host = WidgetTestHost()
    let controller = LazyViewportController()
    let heights: Array<State<Float32>> = [State<Float32>(30.0), State<Float32>(50.0), State<Float32>(70.0),
        State<Float32>(40.0), State<Float32>(40.0), State<Float32>(40.0)]
    let rows = Array<HostMeasuredRow>(heights.size, {
        index => HostMeasuredRow({=> heights[index].value})
    })
    let body: () -> Unit = {
        => LazyList.measured(heights.size, estimatedHeight: 40.0, key: {index => "row.${index}"},
            id: "host.measured.anchor", controller: controller) {
            index => emit(rows[index])
        }
    }
    let viewport = Rect(0.0, 0.0, 300.0, 100.0)
    let _ = host.frame(viewport, body: body)

    controller.scrollToKey("row.3", alignment: LazyScrollAlignment.Start)
    let _ = host.frame(viewport, body: body)
    @Expect(controller.offset, Float32(150.0))
    @Expect(rows[3].frame.y, Float32(0.0))

    heights[1].value = 90.0
    let resized = host.frame(viewport, body: body)
    @Expect(resized.metrics.stabilizationPasses, Int64(2))
    @Expect(controller.offset, Float32(190.0))
    @Expect(rows[3].frame.y, Float32(0.0))
}

@Test
func measuredLazyListConvergesWhenRowsIntroduceTheScrollbarGutter(): Unit {
    let host = WidgetTestHost()
    let rows = Array<HostMeasuredRow>(3, {_ => HostMeasuredRow({=> 60.0})})
    let result = host.frame(Rect(0.0, 0.0, 300.0, 100.0)) {
        LazyList.measured(3, estimatedHeight: 20.0, id: "host.measured.gutter") {
            index => emit(rows[index])
        }
    }

    // Pass 1 discovers overflow, pass 2 remeasures at the gutter width, pass 3 proves stability.
    @Expect(result.metrics.stabilizationPasses, Int64(3))
    @Expect(rows[0].frame.w, Float32(290.0))
    @Expect(!result.schedule.immediate)
}

@Test
func measuredLazyListDoesNotPublishAPartialBatchWhenRowMeasureThrows(): Unit {
    let host = WidgetTestHost()
    let fail = State<Bool>(true)
    let rows: Array<HostMeasuredRow> = [
        HostMeasuredRow({=> if (fail.value) {80.0} else {50.0}}),
        HostMeasuredRow({
            => if (fail.value) {
                throw IllegalStateException("row measure failed")
            } else {
                50.0
            }
        }),
        HostMeasuredRow({=> 50.0})
    ]
    let body: () -> Unit = {
        => LazyList.measured(rows.size, estimatedHeight: 50.0, id: "host.measured.failure") {
            index => emit(rows[index])
        }
    }
    var threw = false
    try {
        let _ = host.frame(Rect(0.0, 0.0, 300.0, 180.0), body: body)
    } catch (error: IllegalStateException) {
        threw = error.message == "row measure failed"
    }
    @Expect(threw)

    // Every recovered row now equals the untouched estimate. A partial row-0 commit would require
    // a second stabilization pass to undo 80 -> 50; one pass proves the failed batch stayed private.
    fail.value = false
    let recovered = host.frame(Rect(0.0, 0.0, 300.0, 180.0), body: body)
    @Expect(recovered.metrics.stabilizationPasses, Int64(1))
}

@Test
func measuredLazyListObservableDataAnchorsInsertWithoutManualRevision(): Unit {
    let host = WidgetTestHost()
    let controller = LazyViewportController()
    let data = State<Array<String>>(["k0", "k1", "k2", "k3", "k4", "k5", "k6", "k7", "k8", "k9"])
    let body: () -> Unit = {
        => LazyList.measured<String>(data, estimatedHeight: 20.0, key: {value => value},
            id: "host.measured.observable", controller: controller) {
            _ => emit(HostMeasuredRow({=> 20.0}))
        }
    }
    let viewport = Rect(0.0, 0.0, 200.0, 80.0)
    let _ = host.frame(viewport, body: body)

    controller.scrollToKey("k5", alignment: LazyScrollAlignment.Start)
    let _ = host.frame(viewport, body: body)
    @Expect(controller.offset, Float32(100.0))

    data.value = ["x", "y", "k0", "k1", "k2", "k3", "k4", "k5", "k6", "k7", "k8", "k9"]
    let inserted = host.frame(viewport, body: body)
    @Expect(inserted.metrics.stabilizationPasses, Int64(2))
    @Expect(controller.offset, Float32(140.0))
}

@Test
func measuredLazyListObservableInsertPreservesLearnedPrefixByStableKey(): Unit {
    let host = WidgetTestHost()
    let controller = LazyViewportController()
    let data = State<Array<String>>(["k0", "k1", "k2", "k3", "k4", "k5", "k6", "k7", "k8", "k9"])
    let body: () -> Unit = {
        => LazyList.measured<String>(data, estimatedHeight: 20.0, key: {value => value},
            id: "host.measured.observable.extents", controller: controller, overscan: 0.0) {
            value => emit(HostMeasuredRow({=> observableRowHeight(value)}))
        }
    }
    let viewport = Rect(0.0, 0.0, 200.0, 80.0)
    let _ = host.frame(viewport, body: body)

    controller.scrollToKey("k3", alignment: LazyScrollAlignment.Start)
    let _ = host.frame(viewport, body: body)
    @Expect(controller.offset, Float32(120.0))

    data.value = ["x", "y", "k0", "k1", "k2", "k3", "k4", "k5", "k6", "k7", "k8", "k9"]
    let _ = host.frame(viewport, body: body)
    // x/y use the 20px estimate; k0..k2 retain their learned 30/40/50px extents by key.
    @Expect(controller.offset, Float32(160.0))
}

private func observableRowHeight(value: String): Float32 {
    if (value == "k0") {
        return 30.0
    }
    if (value == "k1") {
        return 40.0
    }
    if (value == "k2") {
        return 50.0
    }
    if (value == "k3") {
        return 60.0
    }
    20.0
}
