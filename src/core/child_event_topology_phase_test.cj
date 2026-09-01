package cui.core

import sdl.Rect

@Test
func deferredEventTopologyPhaseRejectsOutOfOrderOperations(): Unit {
    let topology = ChildEventTopology(1, deferredPublication: true)
    let bounds = Rect(0.0, 0.0, 10.0, 10.0)
    let child = EmptyView()

    @Expect(eventTopologyOperationFails({=> topology.publishStagedLayout()}))
    @Expect(eventTopologyOperationFails({=> topology.noteChildLayout(0, bounds, child)}))
    topology.beginLayout()
    @Expect(!topology.hasStagedLayout())
    topology.noteChildLayout(0, bounds, child)
    topology.commitLayout([child], bounds)
    @Expect(topology.hasStagedLayout())
    @Expect(eventTopologyOperationFails({=> topology.noteChildLayout(0, bounds, child)}))

    topology.discardStagedLayout()
    @Expect(!topology.hasStagedLayout())
    @Expect(eventTopologyOperationFails({=> topology.publishStagedLayout()}))
    topology.close()
}

@Test
func deferredEventTopologyRestartReplacesReadyLayoutBeforePublishing(): Unit {
    let topology = ChildEventTopology(1, deferredPublication: true)
    let child = EmptyView()
    let firstBounds = Rect(0.0, 0.0, 10.0, 10.0)
    let latestBounds = Rect(20.0, 30.0, 40.0, 50.0)

    topology.beginLayout()
    topology.noteChildLayout(0, firstBounds, child)
    topology.commitLayout([child], firstBounds)
    @Expect(topology.hasStagedLayout())

    topology.beginLayout()
    @Expect(!topology.hasStagedLayout())
    topology.noteChildLayout(0, latestBounds, child)
    topology.commitLayout([child], latestBounds)
    topology.publishStagedLayout()

    let snapshot = topology.snapshot()
    @Expect(snapshot.revision, UInt64(1))
    @Expect(sameAutomaticRect(snapshot.containerBounds, latestBounds))
    @Expect(!topology.hasStagedLayout())
    @Expect(eventTopologyOperationFails({=> topology.publishStagedLayout()}))
    topology.close()
}

private func eventTopologyOperationFails(operation: () -> Unit): Bool {
    try {
        operation()
        false
    } catch (_: IllegalStateException) {
        true
    }
}
