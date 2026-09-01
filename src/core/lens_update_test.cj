package cui.core

private class LensTraversalProbe {
    var reads: Int64 = 0
    var writes: Int64 = 0
    var transforms: Int64 = 0

    func reset(): Unit {
        reads = 0
        writes = 0
        transforms = 0
    }
}

private class LensRootProbe <: Bindable<Int64> {
    private var stored: Int64
    private var bindingRevision: UInt64 = UInt64(0)
    var reads: Int64 = 0
    var writes: Int64 = 0

    init(value: Int64) {
        stored = value
    }

    public mut prop value: Int64 {
        get() {
            reads += 1
            stored
        }
        set(next) {
            writes += 1
            stored = next
            bindingRevision = nextRevision(bindingRevision)
        }
    }

    public prop revision: UInt64 {
        get() {
            bindingRevision
        }
    }

    public func observe(_: (Int64, Int64) -> Unit): StateObservation<Int64> {
        StateObservation<Int64>({=> ()})
    }

    func resetCounts(): Unit {
        reads = 0
        writes = 0
    }
}

private func probedIdentityLens(probe: LensTraversalProbe): Lens<Int64, Int64> {
    Lens<Int64, Int64>(
        get: {
            value =>
                probe.reads += 1
                value
        },
        set: {
            _, value =>
                probe.writes += 1
                value
        }
    )
}

private func deeplyComposedLens(depth: Int64, probe: LensTraversalProbe): Lens<Int64, Int64> {
    var lens = probedIdentityLens(probe)
    for (_ in 1..depth) {
        lens = lens.then(probedIdentityLens(probe))
    }
    lens
}

@Test
func composedLensSetAndUpdateTraverseEachLayerOnce(): Unit {
    let depth: Int64 = 32
    let probe = LensTraversalProbe()
    let lens = deeplyComposedLens(depth, probe)

    @Expect(lens.set(1, 7), Int64(7))
    @Expect(probe.reads, depth - 1)
    @Expect(probe.writes, depth)

    probe.reset()
    @Expect(lens.update(4, {
        value =>
            probe.transforms += 1
            value * 3
    }), Int64(12))
    @Expect(probe.reads, depth)
    @Expect(probe.writes, depth)
    @Expect(probe.transforms, Int64(1))
}

@Test
func composedLensBindingUpdateUsesFusedEndomorphism(): Unit {
    let depth: Int64 = 32
    let probe = LensTraversalProbe()
    let root = LensRootProbe(5)
    let binding = root.project(deeplyComposedLens(depth, probe))
    root.resetCounts()

    binding.update({
        value =>
            probe.transforms += 1
            value + 4
    })

    @Expect(root.reads, Int64(1))
    @Expect(root.writes, Int64(1))
    @Expect(probe.reads, depth)
    @Expect(probe.writes, depth)
    @Expect(probe.transforms, Int64(1))
    @Expect(root.value, Int64(9))
}

@Test
func composedLensBindingFailureWritesNoLayerOrRoot(): Unit {
    let depth: Int64 = 32
    let probe = LensTraversalProbe()
    let root = LensRootProbe(5)
    let binding = root.project(deeplyComposedLens(depth, probe))
    root.resetCounts()
    var didThrow = false

    try {
        binding.update({_ => throw IllegalStateException("expected composed Lens failure")})
    } catch (_: IllegalStateException) {
        didThrow = true
    }

    @Expect(didThrow)
    @Expect(root.reads, Int64(1))
    @Expect(root.writes, Int64(0))
    @Expect(probe.reads, depth)
    @Expect(probe.writes, Int64(0))
    @Expect(root.value, Int64(5))
}

@Test
func reducerPullbackUsesOneComposedLensTraversal(): Unit {
    let depth: Int64 = 32
    let probe = LensTraversalProbe()
    let reducer = Reducer<Int64, Int64>({model, action => model + action})
        .pullback<Int64, Int64>(
            state: deeplyComposedLens(depth, probe),
            action: {action => Some(action)}
        )

    @Expect(reducer.reduce(3, 5), Int64(8))
    @Expect(probe.reads, depth)
    @Expect(probe.writes, depth)
}

@Test
func effectReducerPullbackRemainsLinearAndPreservesEffects(): Unit {
    let depth: Int64 = 32
    let probe = LensTraversalProbe()
    let reducer = EffectReducer<Int64, Int64, Int64>({
        model, action => Transition<Int64, Int64>(model + action, effects: EffectBatch<Int64>(action * 2))
    }).pullback<Int64, Int64, String>(
        state: deeplyComposedLens(depth, probe),
        action: {action => Some(action)},
        effect: {effect => "${effect}"}
    )

    let transition = reducer.reduce(3, 5)
    @Expect(transition.model, Int64(8))
    @Expect(transition.effects.toArray(), ["10"])
    @Expect(probe.reads, depth * 2 - 1)
    @Expect(probe.writes, depth)
}
