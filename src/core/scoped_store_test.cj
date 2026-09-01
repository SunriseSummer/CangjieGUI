package cui.core

private class ScopedFeatureModel {
    let count: Int64
    let name: String

    init(count: Int64, name: String) {
        this.count = count
        this.name = name
    }
}

private class ScopedRootModel {
    let feature: ScopedFeatureModel
    let sibling: String

    init(feature: ScopedFeatureModel, sibling: String) {
        this.feature = feature
        this.sibling = sibling
    }
}

private class ScopedFeatureAction {
    let amount: Int64
    let replacement: ?Int64

    init(amount: Int64, replacement!: ?Int64 = None) {
        this.amount = amount
        this.replacement = replacement
    }
}

private class ScopedRootAction {
    let feature: ?ScopedFeatureAction
    let sibling: ?String

    init(feature!: ?ScopedFeatureAction = None, sibling!: ?String = None) {
        this.feature = feature
        this.sibling = sibling
    }
}

private class ScopedStoreProbe {
    var reductions: Int64 = 0
    var notifications: Int64 = 0
    var previous: Int64 = -1
    var current: Int64 = -1
    var selectorCalls: Int64 = 0
    var didThrow = false

    func observe(previous: ScopedFeatureModel, current: ScopedFeatureModel): Unit {
        notifications += 1
        this.previous = previous.count
        this.current = current.count
    }
}

private func scopedFeatureLens(): Lens<ScopedRootModel, ScopedFeatureModel> {
    Lens<ScopedRootModel, ScopedFeatureModel>(
        get: {root => root.feature},
        set: {root, feature => ScopedRootModel(feature, root.sibling)}
    )
}

private func scopedCountLens(): Lens<ScopedFeatureModel, Int64> {
    Lens<ScopedFeatureModel, Int64>(
        get: {feature => feature.count},
        set: {feature, count => ScopedFeatureModel(count, feature.name)}
    )
}

private func scopedReducer(probe: ScopedStoreProbe): Reducer<ScopedRootModel, ScopedRootAction> {
    Reducer<ScopedRootModel, ScopedRootAction>(
        {
            model, action => match (action.feature) {
                case Some(featureAction) =>
                    probe.reductions += 1
                    if (featureAction.amount == 13) {
                        throw IllegalStateException("expected scoped reducer failure")
                    }
                    let count = match (featureAction.replacement) {
                        case Some(value) => value
                        case None => model.feature.count + featureAction.amount
                    }
                    ScopedRootModel(ScopedFeatureModel(count, model.feature.name), model.sibling)
                case None => match (action.sibling) {
                    case Some(value) => ScopedRootModel(model.feature, value)
                    case None => model
                }
            }
        }
    )
}

private func scopedStore(
    probe: ScopedStoreProbe
): ModelStore<ScopedRootModel, ScopedRootAction> {
    ModelStore<ScopedRootModel, ScopedRootAction>(
        ScopedRootModel(ScopedFeatureModel(2, "feature"), "keep"),
        scopedReducer(probe)
    )
}

private func focusFeature(
    store: ModelStore<ScopedRootModel, ScopedRootAction>
): ScopedStore<ScopedFeatureModel, ScopedFeatureAction> {
    store.scope<ScopedFeatureModel, ScopedFeatureAction>(
        state: scopedFeatureLens(),
        action: {action => ScopedRootAction(feature: Some(action))}
    )
}

@Test
func scopedStoreExposesFeatureAndRoutesActionsWithoutCopyingState(): Unit {
    let probe = ScopedStoreProbe()
    let root = scopedStore(probe)
    let feature = focusFeature(root)
    let observation = feature.observe({previous, current => probe.observe(previous, current)})

    feature.dispatch(ScopedFeatureAction(3))

    @Expect(feature.get().count, Int64(5))
    @Expect(root.get().feature.count, Int64(5))
    @Expect(root.get().sibling, "keep")
    @Expect(root.revision, UInt64(1))
    @Expect(probe.reductions, Int64(1))
    @Expect(probe.notifications, Int64(1))
    @Expect(probe.previous, Int64(2))
    @Expect(probe.current, Int64(5))
    observation.close()
}

@Test
func scopedStorePolicySuppressesUnrelatedRootInvalidation(): Unit {
    let probe = ScopedStoreProbe()
    let root = scopedStore(probe)
    let feature = root.scope<ScopedFeatureModel, ScopedFeatureAction>(
        state: scopedFeatureLens(),
        action: {action => ScopedRootAction(feature: Some(action))},
        policy: stateMutationPolicy<ScopedFeatureModel>(
            {previous, current => previous.count == current.count && previous.name == current.name}
        )
    )
    let observation = feature.observe({previous, current => probe.observe(previous, current)})
    let initialRevision = feature.revision

    root.dispatch(ScopedRootAction(sibling: Some("changed")))

    @Expect(feature.revision, initialRevision)
    @Expect(feature.get().count, Int64(2))
    @Expect(root.get().sibling, "changed")
    @Expect(probe.notifications, Int64(0))

    feature.dispatch(ScopedFeatureAction(4))

    @Expect(feature.revision, initialRevision + UInt64(1))
    @Expect(probe.notifications, Int64(1))
    observation.close()
}

@Test
func nestedScopedStoreComposesLensAndActionBoundaries(): Unit {
    let probe = ScopedStoreProbe()
    let root = scopedStore(probe)
    let feature = focusFeature(root)
    let count = feature.scope<Int64, Int64>(
        state: scopedCountLens(),
        action: {amount => ScopedFeatureAction(amount)}
    )
    let composed = scopedFeatureLens().then(scopedCountLens())

    @Expect(count.get(), composed.get(root.get()))
    count.dispatch(5)

    @Expect(count.get(), Int64(7))
    @Expect(root.get().feature.name, "feature")
    @Expect(root.get().sibling, "keep")
    @Expect(probe.reductions, Int64(1))
}

@Test
func scopedDispatchAllCommitsOnceAndFailureCommitsNothing(): Unit {
    let probe = ScopedStoreProbe()
    let root = scopedStore(probe)
    let feature = focusFeature(root)
    let observation = feature.observe({previous, current => probe.observe(previous, current)})

    feature.dispatchAll([])
    feature.dispatchAll([ScopedFeatureAction(1), ScopedFeatureAction(2), ScopedFeatureAction(3)])

    @Expect(root.get().feature.count, Int64(8))
    @Expect(root.revision, UInt64(1))
    @Expect(probe.reductions, Int64(3))
    @Expect(probe.notifications, Int64(1))

    try {
        feature.dispatchAll([ScopedFeatureAction(1), ScopedFeatureAction(13), ScopedFeatureAction(9)])
    } catch (_: IllegalStateException) {
        probe.didThrow = true
    }

    @Expect(probe.didThrow)
    @Expect(root.get().feature.count, Int64(8))
    @Expect(root.revision, UInt64(1))
    @Expect(probe.notifications, Int64(1))
    observation.close()
}

@Test
func deeplyScopedBatchFusesIntoOneRootTransaction(): Unit {
    let root = ModelStore<Int64, Int64>(0, update: {model, action => model + action})
    var current = root.scope<Int64, Int64>(state: {value => value}, action: {action => action})
    for (_ in 0..32) {
        current = current.scope<Int64, Int64>(state: {value => value}, action: {action => action})
    }

    current.dispatchAll([1, 2, 3, 4])

    @Expect(root.get(), Int64(10))
    @Expect(current.get(), Int64(10))
    @Expect(root.revision, UInt64(1))
}

@Test
func nestedScopeFusionStopsAtParentEquivalenceBoundary(): Unit {
    let root = ModelStore<Int64, Int64>(0, update: {model, action => model + action})
    let quotient = root.scope<Int64, Int64>(
        state: {value => value},
        action: {action => action},
        policy: stateMutationPolicy<Int64>({_, _ => true})
    )
    let child = quotient.scope<Int64, Int64>(state: {value => value}, action: {action => action})
    let _ = child.get()

    root.dispatch(7)

    @Expect(root.get(), Int64(7))
    @Expect(quotient.get(), Int64(0))
    @Expect(child.get(), Int64(0))
}

@Test
func scopedSelectorFusionStopsAtParentEquivalenceBoundary(): Unit {
    let root = ModelStore<Int64, Int64>(0, update: {model, action => model + action})
    let quotient = root.scope<Int64, Int64>(
        state: {value => value},
        action: {action => action},
        policy: stateMutationPolicy<Int64>({_, _ => true})
    )
    let selected = quotient.select<Int64>({value => value * 2})
    let initial = selected.value

    root.dispatch(7)

    @Expect(initial, Int64(0))
    @Expect(quotient.get(), Int64(0))
    @Expect(selected.get(), Int64(0))
}

@Test
func scopedPolicyBindingFiltersSiblingActionsAndRoutesWrites(): Unit {
    let probe = ScopedStoreProbe()
    let root = scopedStore(probe)
    let feature = focusFeature(root)
    let count = feature.binding<Int64>(
        get: {model => model.count},
        action: {value => ScopedFeatureAction(0, replacement: Some(value))},
        policy: structuralEqualityPolicy<Int64>()
    )
    let observation = count.observe({_, _ => probe.notifications += 1})
    let initialRevision = count.revision

    root.dispatch(ScopedRootAction(sibling: Some("changed")))
    @Expect(count.revision, initialRevision)
    @Expect(probe.notifications, Int64(0))

    count.update({value => value + 5})
    @Expect(root.get().feature.count, Int64(7))
    @Expect(root.get().sibling, "changed")
    @Expect(count.revision, initialRevision + UInt64(1))
    @Expect(probe.notifications, Int64(1))
    observation.close()
}

@Test
func scopedActionBindingUsesOneFocusedSnapshotAndOneReducerCall(): Unit {
    let probe = ScopedStoreProbe()
    let root = scopedStore(probe)
    let feature = focusFeature(root)
    let count = feature.binding<Int64>(
        get: {
            model =>
                probe.selectorCalls += 1
                model.count
        },
        action: {value => ScopedFeatureAction(0, replacement: Some(value))}
    )
    let callsBefore = probe.selectorCalls

    count.update({value => value * 3})

    @Expect(root.get().feature.count, Int64(6))
    @Expect(root.get().feature.name, "feature")
    @Expect(root.get().sibling, "keep")
    @Expect(probe.selectorCalls - callsBefore, Int64(1))
    @Expect(probe.reductions, Int64(1))
    @Expect(root.revision, UInt64(1))
}
