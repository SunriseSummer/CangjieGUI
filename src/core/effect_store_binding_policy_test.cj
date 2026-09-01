package cui.core

private class EffectBindingModel {
    let count: Int64
    let sibling: String

    init(count: Int64, sibling: String) {
        this.count = count
        this.sibling = sibling
    }
}

private class EffectBindingAction {
    let replacement: ?Int64
    let effect: String

    init(replacement: ?Int64, effect: String) {
        this.replacement = replacement
        this.effect = effect
    }
}

private class EffectBindingProbe {
    var notifications: Int64 = 0
    var effects = ""

    func interpret(batch: EffectBatch<String>): Unit {
        batch.forEach({effect => effects += "${effect};"})
    }
}

@Test
func effectStorePolicyBindingFiltersReadsWithoutDiscardingEffects(): Unit {
    let probe = EffectBindingProbe()
    let reducer = EffectReducer<EffectBindingModel, EffectBindingAction, String>({model, action =>
        let count = match (action.replacement) {
            case Some(value) => value
            case None => model.count
        }
        Transition<EffectBindingModel, String>(
            EffectBindingModel(count, model.sibling),
            effects: EffectBatch<String>(action.effect)
        )
    })
    let store = EffectStore<EffectBindingModel, EffectBindingAction, String>(
        EffectBindingModel(2, "keep"), reducer)
    let binding = store.binding<Int64>(
        get: {model => model.count},
        action: {value => EffectBindingAction(Some(value), "binding")},
        handleEffects: {effects => probe.interpret(effects)},
        policy: structuralEqualityPolicy<Int64>()
    )
    let countLens = Lens<EffectBindingModel, Int64>(
        get: {model => model.count},
        set: {model, count => EffectBindingModel(count, model.sibling)}
    )
    let lensBinding = store.binding<Int64>(
        countLens,
        action: {value => EffectBindingAction(Some(value), "lens")},
        handleEffects: {effects => probe.interpret(effects)},
        policy: structuralEqualityPolicy<Int64>()
    )
    let observation = binding.observe({_, _ => probe.notifications += 1})
    let initialRevision = binding.revision
    @Expect(lensBinding.value, Int64(2))

    store.dispatch(EffectBindingAction(None, "same"),
        handleEffects: {effects => probe.interpret(effects)})
    @Expect(binding.revision, initialRevision)
    @Expect(probe.notifications, Int64(0))
    @Expect(probe.effects, "same;")

    binding.value = 6
    @Expect(store.get().count, Int64(6))
    @Expect(store.get().sibling, "keep")
    @Expect(binding.revision, initialRevision + UInt64(1))
    @Expect(probe.notifications, Int64(1))
    @Expect(probe.effects, "same;binding;")
    observation.close()
}
