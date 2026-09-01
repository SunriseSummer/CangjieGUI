package cui.core

private class LazyKeyProbe {
    var prefix = "old"
    var visits: Int64 = 0

    func key(index: Int64): String {
        visits += 1
        "${prefix}.${index}"
    }
}

private class DuplicateLazyKeyProbe {
    var visits: Int64 = 0

    func key(index: Int64): String {
        visits += 1
        if (index == 0 || index == 2) {
            "duplicate"
        } else {
            "item.${index}"
        }
    }
}

private class FailingLazyKeyProbe {
    var reject = true
    var visits: Int64 = 0

    func key(index: Int64): String {
        visits += 1
        if (reject && index == 2) {
            throw IllegalStateException("key resolution failed")
        }
        "item.${index}"
    }
}

@Test
func lazyItemAlignmentMapsIndexGeometryAndClampsContentBounds(): Unit {
    @Expect(lazyScrollForItem(200.0, 250.0, 40.0, 1000.0, 100.0, LazyScrollAlignment.Start), Float32(250.0))
    @Expect(lazyScrollForItem(200.0, 250.0, 40.0, 1000.0, 100.0, LazyScrollAlignment.Center), Float32(220.0))
    @Expect(lazyScrollForItem(200.0, 250.0, 40.0, 1000.0, 100.0, LazyScrollAlignment.End), Float32(190.0))
    @Expect(lazyScrollForItem(200.0, 250.0, 40.0, 1000.0, 100.0, LazyScrollAlignment.Nearest), Float32(200.0))
    @Expect(lazyScrollForItem(200.0, 150.0, 40.0, 1000.0, 100.0, LazyScrollAlignment.Nearest), Float32(150.0))
    @Expect(lazyScrollForItem(200.0, 350.0, 40.0, 1000.0, 100.0, LazyScrollAlignment.Nearest), Float32(290.0))
    @Expect(lazyScrollForItem(200.0, 980.0, 40.0, 1000.0, 100.0, LazyScrollAlignment.End), Float32(900.0))
}

@Test
func controllerKeyIndexIsReusedAndInvalidatedByStructuralRevision(): Unit {
    let controller = LazyViewportController()
    let memory = LazyViewportMemory(UInt64(0))
    memory.viewportExtent = 10.0
    let probe = LazyKeyProbe()
    let geometry = LazyItemGeometry(
        5,
        {index => probe.key(index)},
        {index => Float32(index) * 10.0},
        {_ => 10.0},
        50.0
    )

    controller.scrollToKey("old.4", alignment: LazyScrollAlignment.Start)
    let first = lazyResolveControllerScroll(Some(controller), memory, 0.0, geometry)
    @Expect(first, Float32(40.0))
    @Expect(probe.visits, Int64(5))

    controller.scrollToKey("old.1", alignment: LazyScrollAlignment.Start)
    let cached = lazyResolveControllerScroll(Some(controller), memory, first, geometry)
    @Expect(cached, Float32(10.0))
    @Expect(probe.visits, Int64(5))

    probe.prefix = "new"
    memory.structuralRevision = UInt64(1)
    controller.scrollToKey("new.3", alignment: LazyScrollAlignment.Start)
    let rebuilt = lazyResolveControllerScroll(Some(controller), memory, cached, geometry)
    @Expect(rebuilt, Float32(30.0))
    @Expect(probe.visits, Int64(10))
}

@Test
func controllerKeyIndexPreservesFirstDuplicateAndCachesMissingKeys(): Unit {
    let controller = LazyViewportController()
    let memory = LazyViewportMemory(UInt64(0))
    memory.viewportExtent = 10.0
    let probe = DuplicateLazyKeyProbe()
    let geometry = LazyItemGeometry(
        4,
        {index => probe.key(index)},
        {index => Float32(index) * 10.0},
        {_ => 10.0},
        40.0
    )

    controller.scrollToKey("duplicate", alignment: LazyScrollAlignment.Start)
    let duplicate = lazyResolveControllerScroll(Some(controller), memory, 20.0, geometry)
    @Expect(duplicate, Float32(0.0))
    @Expect(controller.lastTargetFound())
    @Expect(probe.visits, Int64(4))

    controller.scrollToKey("missing", alignment: LazyScrollAlignment.Start)
    let missing = lazyResolveControllerScroll(Some(controller), memory, duplicate, geometry)
    @Expect(missing, duplicate)
    @Expect(!controller.lastTargetFound())
    @Expect(probe.visits, Int64(4))
}

@Test
func controllerIndexTargetBypassesKeyIndexAndReportsBounds(): Unit {
    let controller = LazyViewportController()
    let memory = LazyViewportMemory(UInt64(0))
    memory.viewportExtent = 10.0
    let probe = LazyKeyProbe()
    let geometry = LazyItemGeometry(
        5,
        {index => probe.key(index)},
        {index => Float32(index) * 10.0},
        {_ => 10.0},
        50.0
    )

    controller.scrollToIndex(4, alignment: LazyScrollAlignment.Start)
    let found = lazyResolveControllerScroll(Some(controller), memory, 0.0, geometry)
    @Expect(found, Float32(40.0))
    @Expect(controller.lastTargetFound())
    @Expect(probe.visits, Int64(0))

    controller.scrollToIndex(5, alignment: LazyScrollAlignment.Start)
    let missing = lazyResolveControllerScroll(Some(controller), memory, found, geometry)
    @Expect(missing, found)
    @Expect(!controller.lastTargetFound())
    @Expect(probe.visits, Int64(0))
}

@Test
func controllerRejectsNegativeIndexWithoutReplacingItsLastResult(): Unit {
    let controller = LazyViewportController()
    var rejected = false
    try {
        controller.scrollToIndex(-1)
    } catch (error: IllegalArgumentException) {
        rejected = error.message == "Lazy viewport target index must not be negative"
    }
    @Expect(rejected)
    @Expect(controller.lastTargetFound())
}

@Test
func controllerRejectsEmptyKeyWithoutReplacingItsLastResult(): Unit {
    let controller = LazyViewportController()
    var rejected = false
    try {
        controller.scrollToKey("")
    } catch (error: IllegalArgumentException) {
        rejected = error.message == "Lazy viewport target key must not be empty"
    }
    @Expect(rejected)
    @Expect(controller.lastTargetFound())
}

@Test
func boundControllerRejectsBackgroundTargetMutationBeforeChangingPendingRequest(): Unit {
    let scheduler = FrameScheduler()
    let controller = LazyViewportController()
    withFrameScheduler(
        scheduler,
        {
            =>
                let _ = controller.offset
                controller.scrollToKey("item.4", alignment: LazyScrollAlignment.Start)
        }
    )

    let worker = spawn {
        => try {
            controller.scrollToIndex(1, alignment: LazyScrollAlignment.Start)
            false
        } catch (_: IllegalStateException) {
            true
        }
    }
    @Expect(worker.get())

    let memory = LazyViewportMemory(UInt64(0))
    memory.viewportExtent = 10.0
    let geometry = LazyItemGeometry(
        5,
        {index => "item.${index}"},
        {index => Float32(index) * 10.0},
        {_ => 10.0},
        50.0
    )
    let resolved = lazyResolveControllerScroll(Some(controller), memory, 0.0, geometry)
    @Expect(resolved, Float32(40.0))
    @Expect(controller.lastTargetFound())
}

@Test
func controllerJumpCancelsPendingKeyWithoutBuildingItsIndex(): Unit {
    let controller = LazyViewportController()
    let memory = LazyViewportMemory(UInt64(0))
    memory.viewportExtent = 10.0
    let probe = LazyKeyProbe()
    let geometry = LazyItemGeometry(
        5,
        {index => probe.key(index)},
        {index => Float32(index) * 10.0},
        {_ => 10.0},
        50.0
    )

    controller.scrollToKey("old.4", alignment: LazyScrollAlignment.Start)
    controller.jumpTo(20.0)
    let resolved = lazyResolveControllerScroll(Some(controller), memory, controller.offset, geometry)

    @Expect(resolved, Float32(20.0))
    @Expect(controller.lastTargetFound())
    @Expect(probe.visits, Int64(0))
}

@Test
func failedControllerKeyResolutionRetriesTheUncommittedRequest(): Unit {
    let controller = LazyViewportController()
    let memory = LazyViewportMemory(UInt64(0))
    memory.viewportExtent = 10.0
    let probe = FailingLazyKeyProbe()
    let geometry = LazyItemGeometry(
        5,
        {index => probe.key(index)},
        {index => Float32(index) * 10.0},
        {_ => 10.0},
        50.0
    )

    controller.scrollToKey("item.4", alignment: LazyScrollAlignment.Start)
    var rejected = false
    try {
        let _ = lazyResolveControllerScroll(Some(controller), memory, 0.0, geometry)
    } catch (error: IllegalStateException) {
        rejected = error.message == "key resolution failed"
    }
    @Expect(rejected)

    probe.reject = false
    let recovered = lazyResolveControllerScroll(Some(controller), memory, 0.0, geometry)
    @Expect(recovered, Float32(40.0))
    @Expect(controller.lastTargetFound())
}
