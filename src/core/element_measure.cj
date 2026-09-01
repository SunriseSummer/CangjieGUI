package cui.core

import sdl.{Rect, Size}

/* Immutable measure memo committed for one generational Scene node. */
struct ElementMeasureSnapshot {
    let available: Size
    let result: Size
    let environmentGeneration: UInt64

    init(available: Size, result: Size, environmentGeneration: UInt64) {
        this.available = available
        this.result = result
        this.environmentGeneration = environmentGeneration
    }
}

/* Immutable geometry committed for one generational Scene node. */
struct ElementSceneSpaceSnapshot {
    let id: SceneNodeId
    let revision: UInt64
    let layoutCommitted: Bool
    let layoutBounds: Rect
    let visibleBounds: Rect
    let paintBounds: Rect
    let measurement: ?ElementMeasureSnapshot
    let eventTopology: ?ElementEventTopologySnapshot

    init(
        id: SceneNodeId,
        revision: UInt64,
        layoutCommitted: Bool,
        layoutBounds: Rect,
        visibleBounds: Rect,
        paintBounds: Rect,
        measurement: ?ElementMeasureSnapshot,
        eventTopology: ?ElementEventTopologySnapshot
    ) {
        this.id = id
        this.revision = revision
        this.layoutCommitted = layoutCommitted
        this.layoutBounds = layoutBounds
        this.visibleBounds = visibleBounds
        this.paintBounds = paintBounds
        this.measurement = measurement
        this.eventTopology = eventTopology
    }
}

extend ElementSceneSpace {
    func measureMatches(available: Size, environment: UiEnvironmentKey): Bool {
        ensureAlive("inspect measured size")
        match (measureCommit) {
            case Some(value) => sameAutomaticSize(value.available, available) && value.environmentGeneration == environment
                .generation
            case None => false
        }
    }

    /** Returns the committed measurement, or throws `IllegalStateException` while invalid. */
    func measuredSize(): Size {
        ensureAlive("read measured size")
        match (measureCommit) {
            case Some(value) => value.result
            case None => throw IllegalStateException("Cannot read an invalid Element measurement")
        }
    }

    func publishMeasure(available: Size, environment: UiEnvironmentKey, result: Size): Unit {
        ensureAlive("publish measured size")
        measureCommit = Some(ElementMeasureSnapshot(available, result, environment.generation))
        invalidateLayoutState()
        revision = nextRevision(revision)
        noteOwnerChange()
    }

    func invalidateMeasure(): Unit {
        ensureAlive("invalidate measured size")
        let hadMeasure = measureCommit.isSome()
        let invalidatedLayout = layoutIsCurrent()
        invalidateLayoutState()
        if (!hadMeasure && !invalidatedLayout) {
            return
        }
        measureCommit = None
        revision = nextRevision(revision)
        noteOwnerChange()
    }

    func hasMeasure(): Bool {
        ensureAlive("inspect measurement validity")
        measureCommit.isSome()
    }
}
