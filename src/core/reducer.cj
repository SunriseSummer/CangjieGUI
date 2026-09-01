package cui.core

private let REDUCER_BALANCE_THRESHOLD: Int64 = 1023

/**
 * A pure interpretation of `Action` as a model endomorphism. Reducers should depend only on their
 * arguments and return a new model; external effects publish later actions through the UI thread.
 */
public class Reducer<Model, Action> {
    private let update: (Model, Action) -> Model

    public init(update: (Model, Action) -> Model) {
        this.update = update
    }

    /** Applies one action to one model snapshot. */
    public func reduce(model: Model, action: Action): Model {
        update(model, action)
    }

    /** Runs this reducer and then `next` for the same action. */
    public func then(next: Reducer<Model, Action>): Reducer<Model, Action> {
        Reducer<Model, Action>({model, action => next.reduce(reduce(model, action), action)})
    }

    /** Combines an ordered runtime collection, balancing wide products without reordering them. */
    public static func concat(values: Array<Reducer<Model, Action>>): Reducer<Model, Action> {
        if (values.size <= REDUCER_BALANCE_THRESHOLD) {
            return linearReducerProduct(values)
        }
        balancedReducerProduct(values, 0, values.size)
    }

    /**
     * Lifts this feature reducer into a root model through a lawful Lens and an optional action
     * projection. A root action that does not contain a feature action leaves the root unchanged.
     */
    public func pullback<RootModel, RootAction>(
        state!: Lens<RootModel, Model>,
        action!: (RootAction) -> ?Action
    ): Reducer<RootModel, RootAction> {
        Reducer<RootModel, RootAction>({
            root, rootAction => match (action(rootAction)) {
                case Some(localAction) => state.update(root, {model => reduce(model, localAction)})
                case None => root
            }
        })
    }

    /** Lifts this reducer through one reusable state/Action feature boundary. */
    public func pullback<RootModel, RootAction>(path: FeaturePath<RootModel, RootAction, Model, Action>): Reducer<RootModel,
        RootAction> {
        let state = path.state
        let extractAction = path.action.extractor()
        Reducer<RootModel, RootAction>({
            root, rootAction => match (extractAction(rootAction)) {
                case Some(localAction) => state.update(root, {model => reduce(model, localAction)})
                case None => root
            }
        })
    }

    /**
     * Composes an optional child reducer before this parent reducer, preserving the child's final
     * chance to react before the parent can dismiss its state.
     */
    public func ifPresent<ChildModel, ChildAction>(
        state!: Lens<Model, ?ChildModel>,
        action!: (Action) -> ?ChildAction,
        child!: Reducer<ChildModel, ChildAction>,
        missing!: MissingFeaturePolicy = MissingFeaturePolicy.Reject
    ): Reducer<Model, Action> {
        optionalReducer(child, missing: missing).pullback<Model, Action>(state: state, action: action).then(this)
    }

    /** Composes an optional child through a reusable Action Prism. */
    public func ifPresent<ChildModel, ChildAction>(
        state!: Lens<Model, ?ChildModel>,
        action!: Prism<Action, ChildAction>,
        child!: Reducer<ChildModel, ChildAction>,
        missing!: MissingFeaturePolicy = MissingFeaturePolicy.Reject
    ): Reducer<Model, Action> {
        let extractAction = action.extractor()
        ifPresent<ChildModel, ChildAction>(
            state: state,
            action: extractAction,
            child: child,
            missing: missing
        )
    }

    /**
     * Composes a stable-ID child reducer before this parent reducer, so removal by the parent cannot
     * starve the targeted child of the same Action.
     */
    public func forEach<ID, ChildModel, ChildAction>(
        state!: Lens<Model, IdentifiedArray<ID, ChildModel>>,
        action!: (Action) -> ?IdentifiedAction<ID, ChildAction>,
        child!: Reducer<ChildModel, ChildAction>,
        missing!: MissingFeaturePolicy = MissingFeaturePolicy.Reject
    ): Reducer<Model, Action> where ID <: Hashable & Equatable<ID> {
        identifiedReducer<ID, ChildModel, ChildAction>(child, missing: missing)
            .pullback<Model, Action>(state: state, action: action)
            .then(this)
    }

    /** Composes stable-ID children through a reusable Action Prism. */
    public func forEach<ID, ChildModel, ChildAction>(
        state!: Lens<Model, IdentifiedArray<ID, ChildModel>>,
        action!: Prism<Action, IdentifiedAction<ID, ChildAction>>,
        child!: Reducer<ChildModel, ChildAction>,
        missing!: MissingFeaturePolicy = MissingFeaturePolicy.Reject
    ): Reducer<Model, Action> where ID <: Hashable & Equatable<ID> {
        let extractAction = action.extractor()
        forEach<ID, ChildModel, ChildAction>(
            state: state,
            action: extractAction,
            child: child,
            missing: missing
        )
    }

    /**
     * Composes an explicit ordered batch of stable-ID child Actions before the parent reducer. The
     * child traversal produces at most one IdentifiedArray version.
     */
    public func forEachBatch<ID, ChildModel, ChildAction>(
        state!: Lens<Model, IdentifiedArray<ID, ChildModel>>,
        action!: (Action) -> ?Array<IdentifiedAction<ID, ChildAction>>,
        child!: Reducer<ChildModel, ChildAction>,
        missing!: MissingFeaturePolicy = MissingFeaturePolicy.Reject
    ): Reducer<Model, Action> where ID <: Hashable & Equatable<ID> {
        identifiedBatchReducer<ID, ChildModel, ChildAction>(child, missing: missing)
            .pullback<Model, Action>(state: state, action: action)
            .then(this)
    }

    /** Composes a stable-ID child Action batch through a reusable Prism. */
    public func forEachBatch<ID, ChildModel, ChildAction>(
        state!: Lens<Model, IdentifiedArray<ID, ChildModel>>,
        action!: Prism<Action, Array<IdentifiedAction<ID, ChildAction>>>,
        child!: Reducer<ChildModel, ChildAction>,
        missing!: MissingFeaturePolicy = MissingFeaturePolicy.Reject
    ): Reducer<Model, Action> where ID <: Hashable & Equatable<ID> {
        let extractAction = action.extractor()
        forEachBatch<ID, ChildModel, ChildAction>(
            state: state,
            action: extractAction,
            child: child,
            missing: missing
        )
    }

    /** Composes one normalized entity reducer before this parent reducer. */
    public func forEntity<ID, ChildModel, ChildAction>(
        state!: Lens<Model, EntityTable<ID, ChildModel>>,
        action!: (Action) -> ?IdentifiedAction<ID, ChildAction>,
        child!: Reducer<ChildModel, ChildAction>,
        missing!: MissingFeaturePolicy = MissingFeaturePolicy.Reject
    ): Reducer<Model, Action> where ID <: Hashable & Equatable<ID> {
        entityReducer<ID, ChildModel, ChildAction>(child, missing: missing)
            .pullback<Model, Action>(state: state, action: action)
            .then(this)
    }

    /** Composes one normalized entity reducer through a reusable Action Prism. */
    public func forEntity<ID, ChildModel, ChildAction>(
        state!: Lens<Model, EntityTable<ID, ChildModel>>,
        action!: Prism<Action, IdentifiedAction<ID, ChildAction>>,
        child!: Reducer<ChildModel, ChildAction>,
        missing!: MissingFeaturePolicy = MissingFeaturePolicy.Reject
    ): Reducer<Model, Action> where ID <: Hashable & Equatable<ID> {
        let extractAction = action.extractor()
        forEntity<ID, ChildModel, ChildAction>(
            state: state,
            action: extractAction,
            child: child,
            missing: missing
        )
    }

    /**
     * Composes an explicit ordered batch of normalized child Actions before the parent reducer.
     * The child traversal produces at most one EntityTable version.
     */
    public func forEntities<ID, ChildModel, ChildAction>(
        state!: Lens<Model, EntityTable<ID, ChildModel>>,
        action!: (Action) -> ?Array<IdentifiedAction<ID, ChildAction>>,
        child!: Reducer<ChildModel, ChildAction>,
        missing!: MissingFeaturePolicy = MissingFeaturePolicy.Reject
    ): Reducer<Model, Action> where ID <: Hashable & Equatable<ID> {
        entityBatchReducer<ID, ChildModel, ChildAction>(child, missing: missing)
            .pullback<Model, Action>(state: state, action: action)
            .then(this)
    }

    /** Composes an entity Action batch through a reusable Prism. */
    public func forEntities<ID, ChildModel, ChildAction>(
        state!: Lens<Model, EntityTable<ID, ChildModel>>,
        action!: Prism<Action, Array<IdentifiedAction<ID, ChildAction>>>,
        child!: Reducer<ChildModel, ChildAction>,
        missing!: MissingFeaturePolicy = MissingFeaturePolicy.Reject
    ): Reducer<Model, Action> where ID <: Hashable & Equatable<ID> {
        let extractAction = action.extractor()
        forEntities<ID, ChildModel, ChildAction>(
            state: state,
            action: extractAction,
            child: child,
            missing: missing
        )
    }

    /** Lifts this pure state-only reducer into an EffectReducer that emits no effects. */
    public func withEffects<Effect>(): EffectReducer<Model, Action, Effect> {
        EffectReducer<Model, Action, Effect>({model, action => Transition<Model, Effect>(reduce(model, action))})
    }
}

private func linearReducerProduct<Model, Action>(values: Array<Reducer<Model, Action>>): Reducer<Model, Action> {
    if (values.isEmpty()) {
        return Reducer<Model, Action>({model, _ => model})
    }
    var result = values[0]
    for (index in 1..values.size) {
        result = result.then(values[index])
    }
    result
}

private func balancedReducerProduct<Model, Action>(
    values: Array<Reducer<Model, Action>>,
    start: Int64,
    end: Int64
): Reducer<Model, Action> {
    let size = end - start
    if (size == 1) {
        return values[start]
    }
    let middle = start + size / 2
    balancedReducerProduct(values, start, middle).then(balancedReducerProduct(values, middle, end))
}
