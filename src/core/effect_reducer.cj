package cui.core

private let EFFECT_REDUCER_BALANCE_THRESHOLD: Int64 = 1023

/**
 * A pure reducer whose result contains both the next model and inert effect descriptions. Effect
 * values are interpreted only after an EffectStore commits the model.
 */
public class EffectReducer<Model, Action, Effect> {
    private let update: (Model, Action) -> Transition<Model, Effect>

    public init(update: (Model, Action) -> Transition<Model, Effect>) {
        this.update = update
    }

    /** Computes one complete transition without mutating a store or executing effects. */
    public func reduce(model: Model, action: Action): Transition<Model, Effect> {
        update(model, action)
    }

    /** Runs both reducers in order for the same action and concatenates their effects in that order. */
    public func then(next: EffectReducer<Model, Action, Effect>): EffectReducer<Model, Action, Effect> {
        EffectReducer<Model, Action, Effect>(
            {
                model, action =>
                    let first = reduce(model, action)
                    let second = next.reduce(first.model, action)
                    Transition<Model, Effect>(second.model, effects: first.effects.then(second.effects))
            }
        )
    }

    /** Combines ordered effect reducers while preserving model and effect sequence. */
    public static func concat(values: Array<EffectReducer<Model, Action, Effect>>): EffectReducer<Model, Action, Effect> {
        if (values.size <= EFFECT_REDUCER_BALANCE_THRESHOLD) {
            return linearEffectReducerProduct(values)
        }
        balancedEffectReducerProduct(values, 0, values.size)
    }

    /**
     * Lifts a feature reducer into root state/action/effect spaces. Unmatched root actions are the
     * identity transition with no effects.
     */
    public func pullback<RootModel, RootAction, RootEffect>(
        state!: Lens<RootModel, Model>,
        action!: (RootAction) -> ?Action,
        effect!: (Effect) -> RootEffect
    ): EffectReducer<RootModel, RootAction, RootEffect> {
        EffectReducer<RootModel, RootAction, RootEffect>({
            root, rootAction => match (action(rootAction)) {
                case Some(localAction) =>
                    let local = reduce(state.get(root), localAction)
                    Transition<RootModel, RootEffect>(state.set(root, local.model), effects: local.effects.map(effect))
                case None => Transition<RootModel, RootEffect>(root)
            }
        })
    }

    /** Lifts this reducer through one reusable feature boundary and maps its effects. */
    public func pullback<RootModel, RootAction, RootEffect>(
        path: FeaturePath<RootModel, RootAction, Model, Action>,
        effect!: (Effect) -> RootEffect
    ): EffectReducer<RootModel, RootAction, RootEffect> {
        let state = path.state
        let extractAction = path.action.extractor()
        EffectReducer<RootModel, RootAction, RootEffect>({
            root, rootAction => match (extractAction(rootAction)) {
                case Some(localAction) =>
                    let local = reduce(state.get(root), localAction)
                    Transition<RootModel, RootEffect>(state.set(root, local.model), effects: local.effects.map(effect))
                case None => Transition<RootModel, RootEffect>(root)
            }
        })
    }

    /** Composes an optional child effect reducer before this parent reducer. */
    public func ifPresent<ChildModel, ChildAction, ChildEffect>(
        state!: Lens<Model, ?ChildModel>,
        action!: (Action) -> ?ChildAction,
        child!: EffectReducer<ChildModel, ChildAction, ChildEffect>,
        effect!: (ChildEffect) -> Effect,
        missing!: MissingFeaturePolicy = MissingFeaturePolicy.Reject
    ): EffectReducer<Model, Action, Effect> {
        optionalReducer(child, missing: missing)
            .pullback<Model, Action, Effect>(state: state, action: action, effect: effect)
            .then(this)
    }

    /** Composes an optional child effect reducer through a reusable Action Prism. */
    public func ifPresent<ChildModel, ChildAction, ChildEffect>(
        state!: Lens<Model, ?ChildModel>,
        action!: Prism<Action, ChildAction>,
        child!: EffectReducer<ChildModel, ChildAction, ChildEffect>,
        effect!: (ChildEffect) -> Effect,
        missing!: MissingFeaturePolicy = MissingFeaturePolicy.Reject
    ): EffectReducer<Model, Action, Effect> {
        let extractAction = action.extractor()
        ifPresent<ChildModel, ChildAction, ChildEffect>(
            state: state,
            action: extractAction,
            child: child,
            effect: effect,
            missing: missing
        )
    }

    /** Composes a stable-ID child effect reducer before this parent reducer. */
    public func forEach<ID, ChildModel, ChildAction, ChildEffect>(
        state!: Lens<Model, IdentifiedArray<ID, ChildModel>>,
        action!: (Action) -> ?IdentifiedAction<ID, ChildAction>,
        child!: EffectReducer<ChildModel, ChildAction, ChildEffect>,
        effect!: (ChildEffect) -> Effect,
        missing!: MissingFeaturePolicy = MissingFeaturePolicy.Reject
    ): EffectReducer<Model, Action, Effect> where ID <: Hashable & Equatable<ID> {
        identifiedReducer<ID, ChildModel, ChildAction, ChildEffect>(child, missing: missing)
            .pullback<Model, Action, Effect>(state: state, action: action, effect: effect)
            .then(this)
    }

    /** Composes stable-ID child effect reducers through a reusable Action Prism. */
    public func forEach<ID, ChildModel, ChildAction, ChildEffect>(
        state!: Lens<Model, IdentifiedArray<ID, ChildModel>>,
        action!: Prism<Action, IdentifiedAction<ID, ChildAction>>,
        child!: EffectReducer<ChildModel, ChildAction, ChildEffect>,
        effect!: (ChildEffect) -> Effect,
        missing!: MissingFeaturePolicy = MissingFeaturePolicy.Reject
    ): EffectReducer<Model, Action, Effect> where ID <: Hashable & Equatable<ID> {
        let extractAction = action.extractor()
        forEach<ID, ChildModel, ChildAction, ChildEffect>(
            state: state,
            action: extractAction,
            child: child,
            effect: effect,
            missing: missing
        )
    }

    /**
     * Composes an explicit ordered batch of stable-ID child Actions before the parent reducer. Child
     * effects retain traversal order and the batch produces at most one collection version.
     */
    public func forEachBatch<ID, ChildModel, ChildAction, ChildEffect>(
        state!: Lens<Model, IdentifiedArray<ID, ChildModel>>,
        action!: (Action) -> ?Array<IdentifiedAction<ID, ChildAction>>,
        child!: EffectReducer<ChildModel, ChildAction, ChildEffect>,
        effect!: (ChildEffect) -> Effect,
        missing!: MissingFeaturePolicy = MissingFeaturePolicy.Reject
    ): EffectReducer<Model, Action, Effect> where ID <: Hashable & Equatable<ID> {
        identifiedBatchReducer<ID, ChildModel, ChildAction, ChildEffect>(child, missing: missing)
            .pullback<Model, Action, Effect>(state: state, action: action, effect: effect)
            .then(this)
    }

    /** Composes a stable-ID child Action batch through a reusable Prism. */
    public func forEachBatch<ID, ChildModel, ChildAction, ChildEffect>(
        state!: Lens<Model, IdentifiedArray<ID, ChildModel>>,
        action!: Prism<Action, Array<IdentifiedAction<ID, ChildAction>>>,
        child!: EffectReducer<ChildModel, ChildAction, ChildEffect>,
        effect!: (ChildEffect) -> Effect,
        missing!: MissingFeaturePolicy = MissingFeaturePolicy.Reject
    ): EffectReducer<Model, Action, Effect> where ID <: Hashable & Equatable<ID> {
        let extractAction = action.extractor()
        forEachBatch<ID, ChildModel, ChildAction, ChildEffect>(
            state: state,
            action: extractAction,
            child: child,
            effect: effect,
            missing: missing
        )
    }

    /** Composes one normalized entity effect reducer before this parent reducer. */
    public func forEntity<ID, ChildModel, ChildAction, ChildEffect>(
        state!: Lens<Model, EntityTable<ID, ChildModel>>,
        action!: (Action) -> ?IdentifiedAction<ID, ChildAction>,
        child!: EffectReducer<ChildModel, ChildAction, ChildEffect>,
        effect!: (ChildEffect) -> Effect,
        missing!: MissingFeaturePolicy = MissingFeaturePolicy.Reject
    ): EffectReducer<Model, Action, Effect> where ID <: Hashable & Equatable<ID> {
        entityReducer<ID, ChildModel, ChildAction, ChildEffect>(child, missing: missing)
            .pullback<Model, Action, Effect>(state: state, action: action, effect: effect)
            .then(this)
    }

    /** Composes one normalized entity effect reducer through a reusable Action Prism. */
    public func forEntity<ID, ChildModel, ChildAction, ChildEffect>(
        state!: Lens<Model, EntityTable<ID, ChildModel>>,
        action!: Prism<Action, IdentifiedAction<ID, ChildAction>>,
        child!: EffectReducer<ChildModel, ChildAction, ChildEffect>,
        effect!: (ChildEffect) -> Effect,
        missing!: MissingFeaturePolicy = MissingFeaturePolicy.Reject
    ): EffectReducer<Model, Action, Effect> where ID <: Hashable & Equatable<ID> {
        let extractAction = action.extractor()
        forEntity<ID, ChildModel, ChildAction, ChildEffect>(
            state: state,
            action: extractAction,
            child: child,
            effect: effect,
            missing: missing
        )
    }

    /**
     * Composes an explicit ordered batch of normalized child Actions before the parent reducer.
     * Child effects preserve Action order and the child traversal creates at most one table version.
     */
    public func forEntities<ID, ChildModel, ChildAction, ChildEffect>(
        state!: Lens<Model, EntityTable<ID, ChildModel>>,
        action!: (Action) -> ?Array<IdentifiedAction<ID, ChildAction>>,
        child!: EffectReducer<ChildModel, ChildAction, ChildEffect>,
        effect!: (ChildEffect) -> Effect,
        missing!: MissingFeaturePolicy = MissingFeaturePolicy.Reject
    ): EffectReducer<Model, Action, Effect> where ID <: Hashable & Equatable<ID> {
        entityBatchReducer<ID, ChildModel, ChildAction, ChildEffect>(child, missing: missing)
            .pullback<Model, Action, Effect>(state: state, action: action, effect: effect)
            .then(this)
    }

    /** Composes an entity Action batch through a reusable Prism. */
    public func forEntities<ID, ChildModel, ChildAction, ChildEffect>(
        state!: Lens<Model, EntityTable<ID, ChildModel>>,
        action!: Prism<Action, Array<IdentifiedAction<ID, ChildAction>>>,
        child!: EffectReducer<ChildModel, ChildAction, ChildEffect>,
        effect!: (ChildEffect) -> Effect,
        missing!: MissingFeaturePolicy = MissingFeaturePolicy.Reject
    ): EffectReducer<Model, Action, Effect> where ID <: Hashable & Equatable<ID> {
        let extractAction = action.extractor()
        forEntities<ID, ChildModel, ChildAction, ChildEffect>(
            state: state,
            action: extractAction,
            child: child,
            effect: effect,
            missing: missing
        )
    }
}

private func linearEffectReducerProduct<Model, Action, Effect>(values: Array<EffectReducer<Model, Action, Effect>>): EffectReducer<Model,
    Action, Effect> {
    if (values.isEmpty()) {
        return EffectReducer<Model, Action, Effect>({model, _ => Transition<Model, Effect>(model)})
    }
    var result = values[0]
    for (index in 1..values.size) {
        result = result.then(values[index])
    }
    result
}

private func balancedEffectReducerProduct<Model, Action, Effect>(
    values: Array<EffectReducer<Model, Action, Effect>>,
    start: Int64,
    end: Int64
): EffectReducer<Model, Action, Effect> {
    let size = end - start
    if (size == 1) {
        return values[start]
    }
    let middle = start + size / 2
    balancedEffectReducerProduct(values, start, middle).then(balancedEffectReducerProduct(values, middle, end))
}
