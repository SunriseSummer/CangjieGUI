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
