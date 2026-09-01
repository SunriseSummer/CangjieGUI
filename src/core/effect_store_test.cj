package cui.core

private class EffectTestModel {
    let count: Int64
    let text: String

    init(count: Int64, text: String) {
        this.count = count
        this.text = text
    }
}

private class EffectTestAction {
    let amount: Int64
    let effects: Array<String>
    let replacement: ?Int64

    init(amount: Int64, effects!: Array<String> = [], replacement!: ?Int64 = None) {
        this.amount = amount
        this.effects = effects
        this.replacement = replacement
    }
}

private class EffectRootModel {
    let feature: EffectTestModel
    let untouched: String

    init(feature: EffectTestModel, untouched: String) {
        this.feature = feature
        this.untouched = untouched
    }
}

private class EffectRootAction {
    let feature: ?EffectTestAction

    init(feature: ?EffectTestAction) {
        this.feature = feature
    }
}

private class EffectStoreProbe {
    var reductions: Int64 = 0
    var notifications: Int64 = 0
    var effects: String = ""
    var transforms: Int64 = 0
    var didThrow = false
    var failEffect = ""
    var failureMessage = ""
    var handlerCalls: Int64 = 0

    func observe(_: EffectTestModel, _: EffectTestModel): Unit {
        notifications += 1
        effects += "state;"
    }

    func interpret(batch: EffectBatch<String>): Unit {
        handlerCalls += 1
        batch.forEach({effect =>
            effects += "${effect};"
            if (effect == failEffect) {
                throw IllegalStateException("expected effect interpreter failure")
            }
        })
    }
}

@Test
func connectedEffectStoreFacadeCommitsThenHandsOffEffects(): Unit {
    let probe = EffectStoreProbe()
    let store = EffectStore<EffectTestModel, EffectTestAction, String>(
        EffectTestModel(0, "stable"), effectTestReducer(probe))
    let connected = store.connect(handleEffects: {effects => probe.interpret(effects)})
    let observation = connected.observe({previous, current => probe.observe(previous, current)})

    connected.dispatch(EffectTestAction(2, effects: ["save", "analytics"]))

    @Expect(connected.get().count, Int64(2))
    @Expect(store.get().count, Int64(2))
    @Expect(store.revision, UInt64(1))
    @Expect(probe.effects, "state;save;analytics;")
    @Expect(probe.handlerCalls, Int64(1))
    observation.close()
}

@Test
func connectedEffectStoreScopesStateAndActionsWithoutEffectLeakage(): Unit {
    let probe = EffectStoreProbe()
    let feature = effectTestReducer(probe)
    let featureLens = Lens<EffectRootModel, EffectTestModel>(
        get: {root => root.feature},
        set: {root, local => EffectRootModel(local, root.untouched)}
    )
    let rootReducer = feature.pullback<EffectRootModel, EffectRootAction, String>(
        state: featureLens,
        action: {action => action.feature},
        effect: {effect => "root-${effect}"}
    )
    let root = EffectStore<EffectRootModel, EffectRootAction, String>(
        EffectRootModel(EffectTestModel(1, "stable"), "keep"),
        rootReducer
    )
    let local = root.connect(handleEffects: {effects => probe.interpret(effects)})
        .scope<EffectTestModel, EffectTestAction>(
            state: featureLens,
            action: {action => EffectRootAction(Some(action))}
        )

    local.dispatch(EffectTestAction(3, effects: ["save"]))

    @Expect(local.get().count, Int64(4))
    @Expect(root.get().feature.count, Int64(4))
    @Expect(root.get().untouched, "keep")
    @Expect(probe.effects, "root-save;")
}

@Test
func connectedEffectStoreBatchFusesAndEmptyBatchDoesNotInvokeHandler(): Unit {
    let probe = EffectStoreProbe()
    let store = EffectStore<EffectTestModel, EffectTestAction, String>(
        EffectTestModel(0, "stable"), effectTestReducer(probe))
    let connected = store.connect(handleEffects: {effects => probe.interpret(effects)})
    let observation = connected.observe({previous, current => probe.observe(previous, current)})

    connected.dispatchAll([])
    connected.dispatchAll([
        EffectTestAction(1, effects: ["a"]),
        EffectTestAction(2),
        EffectTestAction(3, effects: ["b", "c"])
    ])

    @Expect(store.get().count, Int64(6))
    @Expect(store.revision, UInt64(1))
    @Expect(probe.reductions, Int64(3))
    @Expect(probe.notifications, Int64(1))
    @Expect(probe.handlerCalls, Int64(1))
    @Expect(probe.effects, "state;a;b;c;")
    observation.close()
}

@Test
func connectedEffectStoreBatchFailureCommitsAndHandlesNothing(): Unit {
    let probe = EffectStoreProbe()
    let store = EffectStore<EffectTestModel, EffectTestAction, String>(
        EffectTestModel(0, "stable"), effectTestReducer(probe))
    let connected = store.connect(handleEffects: {effects => probe.interpret(effects)})

    try {
        connected.dispatchAll([
            EffectTestAction(1, effects: ["never"]),
            EffectTestAction(13),
            EffectTestAction(2)
        ])
    } catch (_: IllegalStateException) {
        probe.didThrow = true
    }

    @Expect(probe.didThrow)
    @Expect(store.get().count, Int64(0))
    @Expect(store.revision, UInt64(0))
    @Expect(probe.handlerCalls, Int64(0))
    @Expect(probe.effects, "")
}

@Test
func connectedEffectStorePostCommitFailureStillHandsOffOnce(): Unit {
    let probe = EffectStoreProbe()
    let store = EffectStore<EffectTestModel, EffectTestAction, String>(
        EffectTestModel(0, "stable"), effectTestReducer(probe))
    let connected = store.connect(handleEffects: {effects => probe.interpret(effects)})
    let observation = connected.observe({_, _ => throw IllegalStateException("expected connected observer failure")})

    try {
        connected.dispatch(EffectTestAction(1, effects: ["after-commit"]))
    } catch (_: IllegalStateException) {
        probe.didThrow = true
    }

    @Expect(probe.didThrow)
    @Expect(store.get().count, Int64(1))
    @Expect(store.revision, UInt64(1))
    @Expect(probe.handlerCalls, Int64(1))
    @Expect(probe.effects, "after-commit;")
    observation.close()
}

@Test
func connectedEffectStoreBindingUsesCapturedInterpreterOnce(): Unit {
    let probe = EffectStoreProbe()
    let store = EffectStore<EffectTestModel, EffectTestAction, String>(
        EffectTestModel(2, "keep"), effectTestReducer(probe))
    let connected = store.connect(handleEffects: {effects => probe.interpret(effects)})
    let binding = connected.binding<Int64>(
        get: {model => model.count},
        action: {value => EffectTestAction(0, effects: ["binding"], replacement: Some(value))}
    )

    binding.update({value => value + 3})

    @Expect(store.get().count, Int64(5))
    @Expect(store.get().text, "keep")
    @Expect(probe.reductions, Int64(1))
    @Expect(probe.handlerCalls, Int64(1))
    @Expect(probe.effects, "binding;")
}

private func effectTestReducer(probe: EffectStoreProbe): EffectReducer<EffectTestModel, EffectTestAction, String> {
    EffectReducer<EffectTestModel, EffectTestAction, String>({
        model, action =>
            probe.reductions += 1
            if (action.amount == 13) {
                throw IllegalStateException("expected effect reducer failure")
            }
            let count = match (action.replacement) {
                case Some(value) => value
                case None => model.count + action.amount
            }
            Transition<EffectTestModel, String>(
                EffectTestModel(count, model.text),
                effects: EffectBatch<String>(action.effects)
            )
    })
}

@Test
func effectBatchIsAnOrderedPersistentMonoid(): Unit {
    let source = ["a", "b"]
    let first = EffectBatch<String>(source)
    source[0] = "mutated"
    let second = EffectBatch<String>("c")
    let third = EffectBatch<String>("d")

    let left = first.then(second).then(third).toArray()
    let right = first.then(second.then(third)).toArray()

    @Expect(left.size, Int64(4))
    @Expect(left[0], "a")
    @Expect(left[3], "d")
    @Expect(right[0], left[0])
    @Expect(right[1], left[1])
    @Expect(right[2], left[2])
    @Expect(right[3], left[3])
    @Expect(EffectBatch<String>().then(first).toArray()[0], "a")
    @Expect(first.then(EffectBatch<String>()).toArray()[1], "b")
}

@Test
func effectBatchDeepConcatenationFlattensIteratively(): Unit {
    var batch = EffectBatch<Int64>()
    for (value in 0..4096) {
        batch = batch.then(EffectBatch<Int64>(value))
    }
    let values = batch.map<String>({value => "${value}"}).toArray()

    @Expect(values.size, Int64(4096))
    @Expect(values[0], "0")
    @Expect(values[4095], "4095")
}

@Test
func effectReducerCompositionThreadsModelAndEffectsAssociatively(): Unit {
    let first = EffectReducer<EffectTestModel, EffectTestAction, String>({
        model, action => Transition<EffectTestModel, String>(
            EffectTestModel(model.count + action.amount, model.text), effect: "first")
    })
    let second = EffectReducer<EffectTestModel, EffectTestAction, String>({
        model, _ => Transition<EffectTestModel, String>(EffectTestModel(model.count * 2, model.text), effect: "second")
    })
    let third = EffectReducer<EffectTestModel, EffectTestAction, String>({
        model, _ => Transition<EffectTestModel, String>(EffectTestModel(model.count - 1, model.text), effect: "third")
    })

    let left = first.then(second).then(third).reduce(EffectTestModel(1, ""), EffectTestAction(2))
    let right = first.then(second.then(third)).reduce(EffectTestModel(1, ""), EffectTestAction(2))
    let leftEffects = left.effects.toArray()
    let rightEffects = right.effects.toArray()

    @Expect(left.model.count, Int64(5))
    @Expect(right.model.count, left.model.count)
    @Expect(leftEffects[0], "first")
    @Expect(leftEffects[1], "second")
    @Expect(leftEffects[2], "third")
    @Expect(rightEffects[0], leftEffects[0])
    @Expect(rightEffects[1], leftEffects[1])
    @Expect(rightEffects[2], leftEffects[2])
}

@Test
func effectReducerPullbackMapsStateActionAndEffects(): Unit {
    let probe = EffectStoreProbe()
    let feature = effectTestReducer(probe)
    let lens = Lens<EffectRootModel, EffectTestModel>(
        get: {root => root.feature},
        set: {root, local => EffectRootModel(local, root.untouched)}
    )
    let root = feature.pullback<EffectRootModel, EffectRootAction, String>(
        state: lens,
        action: {action => action.feature},
        effect: {effect => "root-${effect}"}
    )
    let initial = EffectRootModel(EffectTestModel(1, "stable"), "keep")

    let changed = root.reduce(initial, EffectRootAction(Some(EffectTestAction(2, effects: ["save"]))))
    let ignored = root.reduce(changed.model, EffectRootAction(None))

    @Expect(changed.model.feature.count, Int64(3))
    @Expect(changed.model.untouched, "keep")
    @Expect(changed.effects.toArray()[0], "root-save")
    @Expect(ignored.model.feature.count, Int64(3))
    @Expect(ignored.effects.isEmpty())
}

@Test
func effectStoreReturnsInertEffectsAfterModelCommit(): Unit {
    let probe = EffectStoreProbe()
    let store = EffectStore<EffectTestModel, EffectTestAction, String>(
        EffectTestModel(0, "stable"), effectTestReducer(probe))
    let observation = store.observe({previous, current => probe.observe(previous, current)})

    let effects = store.dispatch(EffectTestAction(2, effects: ["save", "analytics"]))

    @Expect(store.get().count, Int64(2))
    @Expect(store.revision, UInt64(1))
    @Expect(probe.effects, "state;")
    probe.interpret(effects)
    @Expect(probe.effects, "state;save;analytics;")
    observation.close()
}

@Test
func effectStoreDispatchAllCommitsOnceAndPreservesEffectOrder(): Unit {
    let probe = EffectStoreProbe()
    let store = EffectStore<EffectTestModel, EffectTestAction, String>(
        EffectTestModel(0, "stable"), effectTestReducer(probe))
    let observation = store.observe({previous, current => probe.observe(previous, current)})

    @Expect(store.dispatchAll([]).isEmpty())
    store.dispatchAll([
        EffectTestAction(1, effects: ["a", "b"]),
        EffectTestAction(2),
        EffectTestAction(3, effects: ["c"])
    ], handleEffects: {effects => probe.interpret(effects)})

    @Expect(store.get().count, Int64(6))
    @Expect(store.revision, UInt64(1))
    @Expect(probe.reductions, Int64(3))
    @Expect(probe.notifications, Int64(1))
    @Expect(probe.effects, "state;a;b;c;")
    observation.close()
}

@Test
func effectStoreBatchReducerFailureCommitsAndHandlesNothing(): Unit {
    let probe = EffectStoreProbe()
    let store = EffectStore<EffectTestModel, EffectTestAction, String>(
        EffectTestModel(0, "stable"), effectTestReducer(probe))

    try {
        store.dispatchAll([
            EffectTestAction(1, effects: ["never"]),
            EffectTestAction(13),
            EffectTestAction(2)
        ], handleEffects: {effects => probe.interpret(effects)})
    } catch (_: IllegalStateException) {
        probe.didThrow = true
    }

    @Expect(probe.didThrow)
    @Expect(store.get().count, Int64(0))
    @Expect(store.revision, UInt64(0))
    @Expect(probe.reductions, Int64(2))
    @Expect(probe.effects, "")
}

@Test
func effectStoreHandlerFailureKeepsCommittedModel(): Unit {
    let probe = EffectStoreProbe()
    probe.failEffect = "fail"
    let store = EffectStore<EffectTestModel, EffectTestAction, String>(
        EffectTestModel(0, "stable"), effectTestReducer(probe))

    try {
        store.dispatch(EffectTestAction(1, effects: ["fail", "not-run"]),
            handleEffects: {effects => probe.interpret(effects)})
    } catch (_: IllegalStateException) {
        probe.didThrow = true
    }

    @Expect(probe.didThrow)
    @Expect(store.get().count, Int64(1))
    @Expect(store.revision, UInt64(1))
    @Expect(probe.effects, "fail;")
}

@Test
func effectStorePostCommitObserverFailureStillHandsOffEffects(): Unit {
    let probe = EffectStoreProbe()
    let store = EffectStore<EffectTestModel, EffectTestAction, String>(
        EffectTestModel(0, "stable"), effectTestReducer(probe))
    let observation = store.observe({_, _ => throw IllegalStateException("expected observer failure")})

    try {
        store.dispatch(EffectTestAction(1, effects: ["after-commit"]),
            handleEffects: {effects => probe.interpret(effects)})
    } catch (_: IllegalStateException) {
        probe.didThrow = true
    }

    @Expect(probe.didThrow)
    @Expect(store.get().count, Int64(1))
    @Expect(probe.effects, "after-commit;")
    observation.close()
}

@Test
func effectStorePreservesCommitFailureWhenHandoffAlsoFails(): Unit {
    let probe = EffectStoreProbe()
    probe.failEffect = "also-fail"
    let store = EffectStore<EffectTestModel, EffectTestAction, String>(
        EffectTestModel(0, "stable"), effectTestReducer(probe))
    let observation = store.observe({_, _ => throw IllegalStateException("primary observer failure")})

    try {
        store.dispatch(EffectTestAction(1, effects: ["also-fail"]),
            handleEffects: {effects => probe.interpret(effects)})
    } catch (error: IllegalStateException) {
        probe.failureMessage = error.message
    }

    @Expect(store.get().count, Int64(1))
    @Expect(probe.effects, "also-fail;")
    @Expect(probe.failureMessage, "primary observer failure")
    observation.close()
}

@Test
func effectStorePreCommitPolicyFailureRunsNoEffects(): Unit {
    let probe = EffectStoreProbe()
    let policy = stateMutationPolicy<EffectTestModel>({_, _ => throw IllegalStateException("expected policy failure")})
    let store = EffectStore<EffectTestModel, EffectTestAction, String>(
        EffectTestModel(0, "stable"), effectTestReducer(probe), policy: policy)

    try {
        store.dispatch(EffectTestAction(1, effects: ["never"]),
            handleEffects: {effects => probe.interpret(effects)})
    } catch (_: IllegalStateException) {
        probe.didThrow = true
    }

    @Expect(probe.didThrow)
    @Expect(store.get().count, Int64(0))
    @Expect(store.revision, UInt64(0))
    @Expect(probe.effects, "")
}

@Test
func effectStoreBindingRequiresAndUsesExplicitEffectHandoff(): Unit {
    let probe = EffectStoreProbe()
    let store = EffectStore<EffectTestModel, EffectTestAction, String>(
        EffectTestModel(2, "keep"), effectTestReducer(probe))
    let binding = store.binding<Int64>(
        get: {model => model.count},
        action: {value => EffectTestAction(0, effects: ["binding"], replacement: Some(value))},
        handleEffects: {effects => probe.interpret(effects)}
    )

    binding.update({
        value =>
            probe.transforms += 1
            value + 3
    })

    @Expect(store.get().count, Int64(5))
    @Expect(store.get().text, "keep")
    @Expect(probe.transforms, Int64(1))
    @Expect(probe.reductions, Int64(1))
    @Expect(probe.effects, "binding;")
}

@Test
func ordinaryReducerCanLiftWithoutEffects(): Unit {
    let reducer = Reducer<Int64, Int64>({model, action => model + action})
    let transition = reducer.withEffects<String>().reduce(2, 3)

    @Expect(transition.model, Int64(5))
    @Expect(transition.effects.isEmpty())
}
