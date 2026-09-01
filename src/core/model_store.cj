package cui.core

/* Mutable transactional accumulator used by scoped action producers. */
private class ModelActionFold<Model, Action> {
    private let reduceModel: (Model, Action) -> Model
    var model: Model
    var count: Int64 = 0

    init(initial: Model, reduceModel: (Model, Action) -> Model) {
        model = initial
        this.reduceModel = reduceModel
    }

    func accept(action: Action): Unit {
        model = reduceModel(model, action)
        count += 1
    }
}

/**
 * A typed, unidirectional application model. Views observe/select the model and dispatch Actions;
 * only the pure Reducer can construct the next model, while local UI state remains in rememberState.
 */
public class ModelStore<Model, Action> <: Observable<Model> {
    private let storage: State<Model>
    private let reduceModel: (Model, Action) -> Model

    /** Creates a store from a first-class Reducer. */
    public init(initial: Model, reducer: Reducer<Model, Action>) {
        storage = State<Model>(initial)
        reduceModel = {model, action => reducer.reduce(model, action)}
    }

    /** Creates a reducer-backed store with an explicit observational-equivalence policy. */
    public init(
        initial: Model,
        reducer: Reducer<Model, Action>,
        policy!: StateMutationPolicy<Model>
    ) {
        storage = State<Model>(initial, policy: policy)
        reduceModel = {model, action => reducer.reduce(model, action)}
    }

    /** Creates a store directly from one pure update closure. */
    public init(initial: Model, update!: (Model, Action) -> Model) {
        storage = State<Model>(initial)
        reduceModel = update
    }

    /** Creates a closure-backed store with an explicit observational-equivalence policy. */
    public init(
        initial: Model,
        update!: (Model, Action) -> Model,
        policy!: StateMutationPolicy<Model>
    ) {
        storage = State<Model>(initial, policy: policy)
        reduceModel = update
    }

    /** Reads the latest complete model. */
    public func get(): Model {
        storage.value
    }

    /** Revision of the underlying single State. */
    public prop revision: UInt64 {
        get() {
            storage.revision
        }
    }

    /** Observes committed model transitions. */
    public func observe(callback: (Model, Model) -> Unit): StateObservation<Model> {
        storage.observe(callback)
    }

    /** Reduces and commits one action from the latest model snapshot. */
    public func dispatch(action: Action): Unit {
        let current = storage.value
        storage.value = reduceModel(current, action)
    }

    /**
     * Folds an ordered action sequence over one model snapshot and commits once. An empty sequence
     * performs no write; if any reducer call throws, no intermediate model is committed.
     */
    public func dispatchAll(actions: Array<Action>): Unit {
        if (actions.isEmpty()) {
            return
        }
        var next = storage.value
        for (action in actions) {
            next = reduceModel(next, action)
        }
        storage.value = next
    }

    /*
     * Consumes a Church-encoded action sequence without materializing intermediate arrays. The
     * accumulator is isolated until the producer and every reducer call complete successfully.
     */
    private func dispatchProduced(produce: ((Action) -> Unit) -> Unit): Unit {
        let fold = ModelActionFold<Model, Action>(storage.value, reduceModel)
        produce({action => fold.accept(action)})
        if (fold.count > 0) {
            storage.value = fold.model
        }
    }

    /** Builds a cached read-only selector from the complete model. */
    public func select<Value>(selector: (Model) -> Value): DerivedState<Value> {
        storage.map(selector)
    }

    /** Builds a selector whose equal projected results do not invalidate downstream scopes. */
    public func select<Value>(
        selector: (Model) -> Value,
        policy!: StateMutationPolicy<Value>
    ): DerivedState<Value> {
        storage.map(selector, policy: policy)
    }

    /** Builds a cached read-only selector through an existing Lens. */
    public func select<Value>(lens: Lens<Model, Value>): DerivedState<Value> {
        storage.map({model => lens.get(model)})
    }

    /** Builds an equality-filtered selector through an existing Lens. */
    public func select<Value>(
        lens: Lens<Model, Value>,
        policy!: StateMutationPolicy<Value>
    ): DerivedState<Value> {
        storage.map({model => lens.get(model)}, policy: policy)
    }

    /** Focuses this store on one feature model and lifts feature Actions into the root domain. */
    public func scope<LocalModel, LocalAction>(
        state!: (Model) -> LocalModel,
        action!: (LocalAction) -> Action
    ): ScopedStore<LocalModel, LocalAction> {
        makeScope<LocalModel, LocalAction>(FusedScopedModelProjection<Model, LocalModel>(storage, state), action)
    }

    /** Focuses this store and filters root changes that are equivalent in the feature domain. */
    public func scope<LocalModel, LocalAction>(
        state!: (Model) -> LocalModel,
        action!: (LocalAction) -> Action,
        policy!: StateMutationPolicy<LocalModel>
    ): ScopedStore<LocalModel, LocalAction> {
        makeScope<LocalModel, LocalAction>(
            FusedScopedModelProjection<Model, LocalModel>(storage, state, policy),
            action
        )
    }

    /** Focuses this store through a reusable Lens. */
    public func scope<LocalModel, LocalAction>(
        state!: Lens<Model, LocalModel>,
        action!: (LocalAction) -> Action
    ): ScopedStore<LocalModel, LocalAction> {
        makeScope<LocalModel, LocalAction>(
            FusedScopedModelProjection<Model, LocalModel>(storage, {model => state.get(model)}),
            action
        )
    }

    /** Focuses this store through a Lens and feature observational-equivalence policy. */
    public func scope<LocalModel, LocalAction>(
        state!: Lens<Model, LocalModel>,
        action!: (LocalAction) -> Action,
        policy!: StateMutationPolicy<LocalModel>
    ): ScopedStore<LocalModel, LocalAction> {
        makeScope<LocalModel, LocalAction>(
            FusedScopedModelProjection<Model, LocalModel>(
                storage,
                {model => state.get(model)},
                policy
            ),
            action
        )
    }

    /** Focuses this store through the same feature boundary used by a pulled-back reducer. */
    public func scope<LocalModel, LocalAction>(path: FeaturePath<Model, Action, LocalModel, LocalAction>): ScopedStore<LocalModel,
        LocalAction> {
        scope<LocalModel, LocalAction>(state: path.state, action: path.action.embedder())
    }

    /** Focuses through a feature boundary and filters equivalent child states. */
    public func scope<LocalModel, LocalAction>(
        path: FeaturePath<Model, Action, LocalModel, LocalAction>,
        policy!: StateMutationPolicy<LocalModel>
    ): ScopedStore<LocalModel, LocalAction> {
        let state = path.state
        makeScope<LocalModel, LocalAction>(
            FusedScopedModelProjection<Model, LocalModel>(
                storage,
                {model => state.get(model)},
                policy
            ),
            path.action.embedder()
        )
    }

    /**
     * Builds a control Binding whose writes become Actions. Reads/observations remain projections of
     * the single model, and Binding.update lifts into one root snapshot and reducer invocation.
     */
    public func binding<Value>(
        get!: (Model) -> Value,
        action!: (Value) -> Action
    ): Binding<Value> {
        projectedBinding<Model, Value>(
            storage,
            get,
            {value => dispatch(action(value))},
            {
                transform =>
                    let model = storage.value
                    storage.value = reduceModel(model, action(transform(get(model))))
            }
        )
    }

    /** Builds an action-driven Binding whose read side filters equivalent projected values. */
    public func binding<Value>(
        get!: (Model) -> Value,
        action!: (Value) -> Action,
        policy!: StateMutationPolicy<Value>
    ): Binding<Value> {
        quotientProjectedBinding<Model, Value>(
            storage,
            get,
            {value => dispatch(action(value))},
            {
                transform =>
                    let model = storage.value
                    storage.value = reduceModel(model, action(transform(get(model))))
            },
            policy
        )
    }

    /** Builds an action-driven control Binding using a reusable Lens for its read projection. */
    public func binding<Value>(lens: Lens<Model, Value>, action!: (Value) -> Action): Binding<Value> {
        binding<Value>(get: {model => lens.get(model)}, action: action)
    }

    /** Builds an equality-filtered action Binding through a reusable Lens. */
    public func binding<Value>(
        lens: Lens<Model, Value>,
        action!: (Value) -> Action,
        policy!: StateMutationPolicy<Value>
    ): Binding<Value> {
        binding<Value>(get: {model => lens.get(model)}, action: action, policy: policy)
    }

    private func makeScope<LocalModel, LocalAction>(
        projection: ScopedModelProjection<LocalModel>,
        liftAction: (LocalAction) -> Action
    ): ScopedStore<LocalModel, LocalAction> {
        ScopedStore<LocalModel, LocalAction>(
            projection,
            {localAction => dispatch(liftAction(localAction))},
            {
                actions => dispatchProduced({
                    acceptRoot => for (localAction in actions) {
                        acceptRoot(liftAction(localAction))
                    }
                })
            },
            {
                produceLocal => dispatchProduced({
                    acceptRoot => produceLocal({localAction => acceptRoot(liftAction(localAction))})
                })
            }
        )
    }
}
