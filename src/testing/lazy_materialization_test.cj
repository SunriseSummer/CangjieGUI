package cui.testing

import sdl.{Rect, Size, UiEvent}
import cui.core.{LazyColumn, LazyList, LazyRow, State, UiContext, Widget, emit}

private class LazyMaterializationObservation {
    var containerBuilds: Int64 = 0
    var itemZeroY: Float32 = 0.0
    var itemZeroX: Float32 = 0.0
    var rejectMaterialization = false

    func recordContainerBuild(): Unit {
        containerBuilds += 1
    }
}

private class LazyMaterializationProbe <: Widget {
    private let index: Int64
    private let observation: LazyMaterializationObservation

    init(index: Int64, observation: LazyMaterializationObservation) {
        this.index = index
        this.observation = observation
        emit(this)
    }

    public func measure(_: UiContext, available: Size): Size {
        available
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        if (index == 0) {
            observation.itemZeroY = rect.y
            observation.itemZeroX = rect.x
        }
    }

    public func draw(_: UiContext): Unit {}

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }
}

@Test
func lazyColumnTreatsScrollAsLayoutUntilMaterializationBoundary(): Unit {
    let host = WidgetTestHost()
    let scroll = State<Float32>(0.0)
    let observation = LazyMaterializationObservation()
    let body: () -> Unit = {
        =>
            observation.recordContainerBuild()
            LazyColumn(1000, 330.0, scroll: scroll, id: "phase-split") {
                index => LazyMaterializationProbe(index, observation)
            }
    }
    let rect = Rect(0.0, 0.0, 1120.0, 720.0)

    let first = host.frame(rect, body: body)
    @Expect(first.metrics.stabilizationPasses, Int64(1))
    @Expect(observation.containerBuilds, Int64(1))
    @Expect(observation.itemZeroY, Float32(0.0))

    scroll.value = 24.0
    let inside24 = host.frame(rect, body: body)
    @Expect(inside24.metrics.stabilizationPasses, Int64(1))
    @Expect(observation.containerBuilds, Int64(1))
    @Expect(observation.itemZeroY, Float32(-24.0))

    scroll.value = 48.0
    let inside48 = host.frame(rect, body: body)
    @Expect(inside48.metrics.stabilizationPasses, Int64(1))
    @Expect(observation.containerBuilds, Int64(1))
    @Expect(observation.itemZeroY, Float32(-48.0))

    scroll.value = 72.0
    let boundary = host.frame(rect, body: body)
    @Expect(boundary.metrics.stabilizationPasses, Int64(2))
    @Expect(observation.containerBuilds, Int64(2))
    @Expect(observation.itemZeroY, Float32(-72.0))
}

@Test
func lazyRowTreatsScrollAsLayoutUntilMaterializationBoundary(): Unit {
    let host = WidgetTestHost()
    let scroll = State<Float32>(0.0)
    let observation = LazyMaterializationObservation()
    let body: () -> Unit = {
        =>
            observation.recordContainerBuild()
            LazyRow(1000, 330.0, scroll: scroll, id: "row-phase-split") {
                index => LazyMaterializationProbe(index, observation)
            }
    }
    let rect = Rect(0.0, 0.0, 720.0, 200.0)

    let first = host.frame(rect, body: body)
    @Expect(first.metrics.stabilizationPasses, Int64(1))
    @Expect(observation.containerBuilds, Int64(1))
    @Expect(observation.itemZeroX, Float32(0.0))

    scroll.value = 48.0
    let inside = host.frame(rect, body: body)
    @Expect(inside.metrics.stabilizationPasses, Int64(1))
    @Expect(observation.containerBuilds, Int64(1))
    @Expect(observation.itemZeroX, Float32(-48.0))

    scroll.value = 72.0
    let boundary = host.frame(rect, body: body)
    @Expect(boundary.metrics.stabilizationPasses, Int64(2))
    @Expect(observation.containerBuilds, Int64(2))
    @Expect(observation.itemZeroX, Float32(-72.0))
}

@Test
func versionedLazyListTreatsScrollAsLayoutUntilMaterializationBoundary(): Unit {
    let host = WidgetTestHost()
    let scroll = State<Float32>(0.0)
    let observation = LazyMaterializationObservation()
    let body: () -> Unit = {
        =>
            observation.recordContainerBuild()
            LazyList(1000, {_ => 330.0}, scroll: scroll, revision: Some(UInt64(1)), id: "list-phase-split") {
                index => LazyMaterializationProbe(index, observation)
            }
    }
    let rect = Rect(0.0, 0.0, 1120.0, 720.0)

    let first = host.frame(rect, body: body)
    @Expect(first.metrics.stabilizationPasses, Int64(1))
    @Expect(observation.containerBuilds, Int64(1))

    scroll.value = 48.0
    let inside = host.frame(rect, body: body)
    @Expect(inside.metrics.stabilizationPasses, Int64(1))
    @Expect(observation.containerBuilds, Int64(1))
    @Expect(observation.itemZeroY, Float32(-48.0))

    scroll.value = 72.0
    let boundary = host.frame(rect, body: body)
    @Expect(boundary.metrics.stabilizationPasses, Int64(2))
    @Expect(observation.containerBuilds, Int64(2))
    @Expect(observation.itemZeroY, Float32(-72.0))
}

@Test
func unversionedLazyListKeepsOpaqueHeightRebuildCompatibility(): Unit {
    let host = WidgetTestHost()
    let scroll = State<Float32>(0.0)
    let observation = LazyMaterializationObservation()
    let body: () -> Unit = {
        =>
            observation.recordContainerBuild()
            LazyList(1000, {_ => 330.0}, scroll: scroll, id: "list-unversioned") {
                index => LazyMaterializationProbe(index, observation)
            }
    }
    let rect = Rect(0.0, 0.0, 1120.0, 720.0)
    let _ = host.frame(rect, body: body)
    scroll.value = 24.0
    let _ = host.frame(rect, body: body)

    @Expect(observation.containerBuilds, Int64(2))
    @Expect(observation.itemZeroY, Float32(-24.0))
}

@Test
func failedLazyMaterializationRemainsDirtyAndRecoversAtomically(): Unit {
    let host = WidgetTestHost()
    let scroll = State<Float32>(0.0)
    let observation = LazyMaterializationObservation()
    let body: () -> Unit = {
        =>
            observation.recordContainerBuild()
            if (observation.rejectMaterialization) {
                throw IllegalStateException("materialization rejected")
            }
            LazyColumn(1000, 330.0, scroll: scroll, id: "phase-split-failure") {
                index => LazyMaterializationProbe(index, observation)
            }
    }
    let rect = Rect(0.0, 0.0, 1120.0, 720.0)
    let _ = host.frame(rect, body: body)

    scroll.value = 72.0
    observation.rejectMaterialization = true
    var rejected = false
    try {
        let _ = host.frame(rect, body: body)
    } catch (error: IllegalStateException) {
        rejected = error.message == "materialization rejected"
    }
    @Expect(rejected)
    @Expect(observation.containerBuilds, Int64(2))

    observation.rejectMaterialization = false
    let recovered = host.frame(rect, body: body)
    @Expect(recovered.metrics.stabilizationPasses, Int64(1))
    @Expect(observation.containerBuilds, Int64(3))
    @Expect(observation.itemZeroY, Float32(-72.0))
}
