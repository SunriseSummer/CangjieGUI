package cui.core

private class StoreTestModel {
    let count: Int64
    let text: String

    init(count: Int64, text: String) {
        this.count = count
        this.text = text
    }
}

private class StoreTestAction {
    let amount: Int64
    let replacement: ?Int64

    init(amount: Int64, replacement!: ?Int64 = None) {
        this.amount = amount
        this.replacement = replacement
    }
}

private class StoreRootModel {
    let feature: StoreTestModel
    let untouched: String

    init(feature: StoreTestModel, untouched: String) {
        this.feature = feature
        this.untouched = untouched
    }
}

private class StoreRootAction {
    let feature: ?StoreTestAction

    init(feature: ?StoreTestAction) {
        this.feature = feature
    }
}

private class ModelStoreProbe {
    var reductions: Int64 = 0
    var notifications: Int64 = 0
    var previous: Int64 = -1
    var current: Int64 = -1
    var selectorCalls: Int64 = 0
    var didThrow = false

    func record(previous: StoreTestModel, current: StoreTestModel): Unit {
        notifications += 1
        this.previous = previous.count
        this.current = current.count
    }
}

private func storeTestReducer(probe: ModelStoreProbe): Reducer<StoreTestModel, StoreTestAction> {
    Reducer<StoreTestModel, StoreTestAction>(
        {
            model, action =>
                probe.reductions += 1
                if (action.amount == 13) {
                    throw IllegalStateException("expected reducer failure")
                }
                let count = match (action.replacement) {
                    case Some(value) => value
                    case None => model.count + action.amount
                }
                StoreTestModel(count, model.text)
        }
    )
}

@Test
func reducerCompositionRunsInDeclaredOrder(): Unit {
    let first = Reducer<StoreTestModel, StoreTestAction>(
        {model, action => StoreTestModel(model.count + action.amount, model.text + "first;")}
    )
    let second = Reducer<StoreTestModel, StoreTestAction>(
        {model, _ => StoreTestModel(model.count * 2, model.text + "second;")}
    )
    let third = Reducer<StoreTestModel, StoreTestAction>(
        {model, _ => StoreTestModel(model.count - 1, model.text + "third;")}
    )

    let result = first.then(second).reduce(StoreTestModel(1, ""), StoreTestAction(2))
    let leftAssociated = first.then(second).then(third).reduce(StoreTestModel(1, ""), StoreTestAction(2))
    let rightAssociated = first.then(second.then(third)).reduce(StoreTestModel(1, ""), StoreTestAction(2))

    @Expect(result.count, Int64(6))
    @Expect(result.text, "first;second;")
    @Expect(leftAssociated.count, rightAssociated.count)
    @Expect(leftAssociated.text, rightAssociated.text)
}

@Test
func reducerPullbackRoutesFeatureActionThroughLens(): Unit {
    let probe = ModelStoreProbe()
    let featureReducer = storeTestReducer(probe)
    let featureLens = Lens<StoreRootModel, StoreTestModel>(
        get: {root => root.feature},
        set: {root, feature => StoreRootModel(feature, root.untouched)}
    )
    let rootReducer = featureReducer.pullback<StoreRootModel, StoreRootAction>(
        state: featureLens,
        action: {action => action.feature}
    )
    let initial = StoreRootModel(StoreTestModel(2, "stable"), "keep")

    let changed = rootReducer.reduce(initial, StoreRootAction(Some(StoreTestAction(3))))
    let ignored = rootReducer.reduce(changed, StoreRootAction(None))

    @Expect(changed.feature.count, Int64(5))
    @Expect(changed.untouched, "keep")
    @Expect(ignored.feature.count, Int64(5))
    @Expect(probe.reductions, Int64(1))
}

@Test
func modelStoreDispatchPublishesOneModelTransition(): Unit {
    let probe = ModelStoreProbe()
    let store = ModelStore<StoreTestModel, StoreTestAction>(StoreTestModel(0, "stable"), storeTestReducer(probe))
    let observation = store.observe({previous, current => probe.record(previous, current)})

    store.dispatch(StoreTestAction(4))

    @Expect(store.get().count, Int64(4))
    @Expect(store.revision, UInt64(1))
    @Expect(probe.reductions, Int64(1))
    @Expect(probe.notifications, Int64(1))
    @Expect(probe.previous, Int64(0))
    @Expect(probe.current, Int64(4))
    observation.close()
}

@Test
func modelStoreDispatchAllFoldsOnceAndEmptySequenceDoesNothing(): Unit {
    let probe = ModelStoreProbe()
    let store = ModelStore<StoreTestModel, StoreTestAction>(StoreTestModel(0, "stable"), storeTestReducer(probe))
    let observation = store.observe({previous, current => probe.record(previous, current)})

    store.dispatchAll([])
    @Expect(store.revision, UInt64(0))
    store.dispatchAll([StoreTestAction(1), StoreTestAction(2), StoreTestAction(3)])

    @Expect(store.get().count, Int64(6))
    @Expect(store.revision, UInt64(1))
    @Expect(probe.reductions, Int64(3))
    @Expect(probe.notifications, Int64(1))
    @Expect(probe.previous, Int64(0))
    @Expect(probe.current, Int64(6))
    observation.close()
}

@Test
func modelStoreDispatchAllReducerFailureCommitsNothing(): Unit {
    let probe = ModelStoreProbe()
    let store = ModelStore<StoreTestModel, StoreTestAction>(StoreTestModel(0, "stable"), storeTestReducer(probe))
    try {
        store.dispatchAll([StoreTestAction(1), StoreTestAction(13), StoreTestAction(2)])
    } catch (_: IllegalStateException) {
        probe.didThrow = true
    }

    @Expect(probe.didThrow)
    @Expect(store.get().count, Int64(0))
    @Expect(store.revision, UInt64(0))
    @Expect(probe.reductions, Int64(2))
}

@Test
func modelStoreSelectorAndActionBindingShareOneModel(): Unit {
    let probe = ModelStoreProbe()
    let store = ModelStore<StoreTestModel, StoreTestAction>(StoreTestModel(2, "keep"), storeTestReducer(probe))
    let doubled = store.select<Int64>({model => model.count * 2})
    let count = store.binding<Int64>(
        get: {
            model =>
                probe.selectorCalls += 1
                model.count
        },
        action: {value => StoreTestAction(0, replacement: Some(value))}
    )

    @Expect(doubled.get(), Int64(4))
    count.value = 5
    let callsBeforeUpdate = probe.selectorCalls
    count.update({value => value + 2})

    @Expect(store.get().count, Int64(7))
    @Expect(store.get().text, "keep")
    @Expect(doubled.get(), Int64(14))
    @Expect(probe.reductions, Int64(2))
    @Expect(probe.selectorCalls - callsBeforeUpdate, Int64(1))
}

@Test
func modelStorePolicyBindingSuppressesEquivalentReadsAndKeepsActionWrites(): Unit {
    let probe = ModelStoreProbe()
    let store = ModelStore<StoreTestModel, StoreTestAction>(StoreTestModel(2, "keep"), storeTestReducer(probe))
    let count = store.binding<Int64>(
        get: {model => model.count},
        action: {value => StoreTestAction(0, replacement: Some(value))},
        policy: structuralEqualityPolicy<Int64>()
    )
    let observation = count.observe({_, _ => probe.notifications += 1})
    let initialRevision = count.revision

    store.dispatch(StoreTestAction(0))
    @Expect(count.revision, initialRevision)
    @Expect(probe.notifications, Int64(0))

    count.value = 7
    @Expect(store.get().count, Int64(7))
    @Expect(store.get().text, "keep")
    @Expect(count.revision, initialRevision + UInt64(1))
    @Expect(probe.notifications, Int64(1))
    observation.close()
}

@Test
func modelStoreMutationPolicySuppressesEquivalentReducedModel(): Unit {
    let probe = ModelStoreProbe()
    let policy = stateMutationPolicy<StoreTestModel>(
        {previous, current => previous.count == current.count && previous.text == current.text}
    )
    let store = ModelStore<StoreTestModel, StoreTestAction>(
        StoreTestModel(3, "same"),
        storeTestReducer(probe),
        policy: policy
    )
    let observation = store.observe({previous, current => probe.record(previous, current)})

    store.dispatch(StoreTestAction(0))

    @Expect(store.revision, UInt64(0))
    @Expect(probe.reductions, Int64(1))
    @Expect(probe.notifications, Int64(0))
    observation.close()
}

@Test
func modelStoreClosureConstructorAndLensOverloadsRemainActionDriven(): Unit {
    let countLens = Lens<StoreTestModel, Int64>(
        get: {model => model.count},
        set: {model, count => StoreTestModel(count, model.text)}
    )
    let store = ModelStore<StoreTestModel, StoreTestAction>(
        StoreTestModel(1, "keep"),
        update: {
            model, action => match (action.replacement) {
                case Some(value) => StoreTestModel(value, model.text)
                case None => StoreTestModel(model.count + action.amount, model.text)
            }
        }
    )
    let selected = store.select<Int64>(countLens)
    let binding = store.binding<Int64>(countLens, action: {value => StoreTestAction(0, replacement: Some(value))})
    let policyBinding = store.binding<Int64>(
        countLens,
        action: {value => StoreTestAction(0, replacement: Some(value))},
        policy: structuralEqualityPolicy<Int64>()
    )

    binding.value = 8

    @Expect(store.get().count, Int64(8))
    @Expect(store.get().text, "keep")
    @Expect(selected.get(), Int64(8))
    @Expect(policyBinding.value, Int64(8))
}

@Test
func modelStorePolicySelectorFiltersUnrelatedModelChanges(): Unit {
    let probe = ModelStoreProbe()
    let store = ModelStore<StoreTestModel, Int64>(
        StoreTestModel(0, "initial"),
        update: {model, count => StoreTestModel(count, "version-${model.text.size}")}
    )
    let selected = store.select<Int64>(
        {
            model =>
                probe.selectorCalls += 1
                model.count
        },
        policy: structuralEqualityPolicy<Int64>()
    )
    let observation = selected.observe({_, _ => probe.notifications += 1})
    let initialRevision = selected.revision

    store.dispatch(0)
    @Expect(selected.revision, initialRevision)
    @Expect(probe.notifications, Int64(0))

    store.dispatch(2)
    @Expect(selected.value, Int64(2))
    @Expect(selected.revision, initialRevision + UInt64(1))
    @Expect(probe.notifications, Int64(1))
    @Expect(probe.selectorCalls, Int64(3))
    observation.close()
}

@Test
func modelStoreLensSelectorAcceptsEquivalencePolicy(): Unit {
    let countLens = Lens<StoreTestModel, Int64>(
        get: {model => model.count},
        set: {model, count => StoreTestModel(count, model.text)}
    )
    let store = ModelStore<StoreTestModel, Int64>(
        StoreTestModel(1, "initial"),
        update: {model, count => StoreTestModel(count, model.text + "!")}
    )
    let selected = store.select<Int64>(countLens, policy: structuralEqualityPolicy<Int64>())
    let probe = ModelStoreProbe()
    let observation = selected.observe({_, _ => probe.notifications += 1})

    store.dispatch(1)
    store.dispatch(4)

    @Expect(selected.value, Int64(4))
    @Expect(probe.notifications, Int64(1))
    observation.close()
}
