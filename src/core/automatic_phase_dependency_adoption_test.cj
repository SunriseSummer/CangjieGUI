package cui.core

import sdl.{Rect, Renderer, Size, UiEvent}

private class AutomaticPhaseStateProbe <: Widget {
    private let measureSource: State<Int64>
    private let layoutSource: State<Int64>
    private let paintSource: State<Int64>

    init(measureSource: State<Int64>, layoutSource: State<Int64>, paintSource: State<Int64>) {
        this.measureSource = measureSource
        this.layoutSource = layoutSource
        this.paintSource = paintSource
    }

    public func measure(_: UiContext, available: Size): Size {
        let _ = measureSource.value
        available
    }

    public func layout(_: UiContext, _: Rect): Unit {
        let _ = layoutSource.value
    }

    public func draw(_: UiContext): Unit {
        let _ = paintSource.value
    }

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }
}

private class AutomaticLayoutStateProbe <: Widget {
    private let source: State<Int64>
    var fail = false

    init(source: State<Int64>, fail!: Bool = false) {
        this.source = source
        this.fail = fail
    }

    public func measure(_: UiContext, available: Size): Size {
        available
    }

    public func layout(_: UiContext, _: Rect): Unit {
        let _ = source.value
        if (fail) {
            throw IllegalStateException("replacement layout failed")
        }
    }

    public func draw(_: UiContext): Unit {}

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }
}

private class AutomaticEmptyPhaseProbe <: Widget {
    public func measure(_: UiContext, available: Size): Size {
        available
    }

    public func layout(_: UiContext, _: Rect): Unit {}

    public func draw(_: UiContext): Unit {}

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }
}

@Test
func automaticReplacementKeepsCommittedPhaseFrontiersUntilSuccessfulRecollection(): Unit {
    let measureSource = State<Int64>(1)
    let layoutSource = State<Int64>(2)
    let paintSource = State<Int64>(3)
    let node = AutomaticRenderNode(AutomaticPhaseStateProbe(measureSource, layoutSource, paintSource),
        AutomaticPaintBudget(), {_: Rect => ()})
    let context = UiContext(Renderer.headless(), Theme.light())
    let size = Size(100.0, 40.0)
    let rect = Rect(0.0, 0.0, size.w, size.h)
    let _ = node.measure(context, size)
    node.layout(context, rect)
    node.draw(context)

    @Expect(measureSource.listenerSlotCount(), Int64(1))
    @Expect(layoutSource.listenerSlotCount(), Int64(1))
    @Expect(paintSource.listenerSlotCount(), Int64(1))
    node.update(AutomaticPhaseStateProbe(measureSource, layoutSource, paintSource))
    @Expect(measureSource.listenerSlotCount(), Int64(1))
    @Expect(layoutSource.listenerSlotCount(), Int64(1))
    @Expect(paintSource.listenerSlotCount(), Int64(1))

    let _ = node.measure(context, size)
    node.layout(context, rect)
    node.draw(context)
    @Expect(measureSource.listenerSlotCount(), Int64(1))
    @Expect(layoutSource.listenerSlotCount(), Int64(1))
    @Expect(paintSource.listenerSlotCount(), Int64(1))
    node.close()
    @Expect(measureSource.listenerSlotCount(), Int64(0))
    @Expect(layoutSource.listenerSlotCount(), Int64(0))
    @Expect(paintSource.listenerSlotCount(), Int64(0))
}

@Test
func failedReplacementRecollectionKeepsCommittedFrontierAndLaterSwitchesSources(): Unit {
    let previous = State<Int64>(1)
    let next = State<Int64>(2)
    let node = AutomaticRenderNode(AutomaticLayoutStateProbe(previous), AutomaticPaintBudget(), {_: Rect => ()})
    let context = UiContext(Renderer.headless(), Theme.light())
    let rect = Rect(0.0, 0.0, 100.0, 40.0)
    node.layout(context, rect)
    @Expect(previous.listenerSlotCount(), Int64(1))

    node.update(AutomaticLayoutStateProbe(next, fail: true))
    @Expect(previous.listenerSlotCount(), Int64(1))
    var rejected = false
    try {
        node.layout(context, rect)
    } catch (error: IllegalStateException) {
        rejected = error.message == "replacement layout failed"
    }
    @Expect(rejected)
    @Expect(previous.listenerSlotCount(), Int64(1))
    @Expect(next.listenerSlotCount(), Int64(0))

    node.update(AutomaticLayoutStateProbe(next))
    node.layout(context, rect)
    @Expect(previous.listenerSlotCount(), Int64(0))
    @Expect(next.listenerSlotCount(), Int64(1))
    node.update(AutomaticEmptyPhaseProbe())
    @Expect(next.listenerSlotCount(), Int64(1))
    node.close()
    @Expect(next.listenerSlotCount(), Int64(0))
}
