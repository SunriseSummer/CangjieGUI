package cui.core

/* Isolated state/effect accumulator used by connected scoped action producers. */
private class EffectActionFold<Model, Action, Effect> {
    private let reduceTransition: (Model, Action) -> Transition<Model, Effect>
    var model: Model
    var effects = EffectBatch<Effect>()
    var count: Int64 = 0

    init(initial: Model, reduceTransition: (Model, Action) -> Transition<Model, Effect>) {
        model = initial
        this.reduceTransition = reduceTransition
    }

    func accept(action: Action): Unit {
        let transition = reduceTransition(model, action)
        model = transition.model
        if (!transition.effects.isEmpty()) {
            effects = effects.then(transition.effects)
        }
        count += 1
    }
}

/**
 * A unidirectional store for pure state transitions that also describe external effects. Dispatch
 * commits the model before returning or explicitly handing the inert EffectBatch to application
 * infrastructure; the core never chooses a thread pool, network stack, or cancellation policy.
 */
public class EffectStore<Model, Action, Effect> <: Observable<Model> {
    private let storage: State<Model>
    private let reducer: EffectReducer<Model, Action, Effect>

    /** Creates an effect store with the default event-style model mutation policy. */
    public init(initial: Model, reducer: EffectReducer<Model, Action, Effect>) {
        storage = State<Model>(initial)
        this.reducer = reducer
    }

    /** Creates an effect store with an explicit model observational-equivalence policy. */
    public init(
        initial: Model,
        reducer: EffectReducer<Model, Action, Effect>,
        policy!: StateMutationPolicy<Model>
    ) {
        storage = State<Model>(initial, policy: policy)
        this.reducer = reducer
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

    /** Reduces and commits one action, then returns its still-uninterpreted effects. */
    public func dispatch(action: Action): EffectBatch<Effect> {
        let transition = reducer.reduce(storage.value, action)
        storage.value = transition.model
        transition.effects
    }

    /**
     * Reduces and commits one action, then hands its effects to `handleEffects`. If model observers
     * fail after the revision commits, effects are still handed off once before failures are
     * reported. A pre-commit policy/reducer failure runs no effects.
     */
    public func dispatch(action: Action, handleEffects!: (EffectBatch<Effect>) -> Unit): Unit {
        commitAndHandle(reducer.reduce(storage.value, action), handleEffects)
    }

    /**
     * Folds an ordered action sequence over one model and commits once, returning effects in
     * action/reducer order. An empty sequence performs no write and returns the empty batch.
     */
    public func dispatchAll(actions: Array<Action>): EffectBatch<Effect> {
        if (actions.isEmpty()) {
            return EffectBatch<Effect>()
        }
        let transition = reduceAll(actions)
        storage.value = transition.model
        transition.effects
    }

    /** Atomically folds actions, commits once, then explicitly hands off the ordered effect batch. */
    public func dispatchAll(actions: Array<Action>, handleEffects!: (EffectBatch<Effect>) -> Unit): Unit {
        if (actions.isEmpty()) {
            return
        }
        commitAndHandle(reduceAll(actions), handleEffects)
    }

    /** Builds a cached read-only selector from the complete model. */
    public func select<Value>(selector: (Model) -> Value): DerivedState<Value> {
        storage.map(selector)
    }

    /** Builds an equality-filtered selector from the complete model. */
    public func select<Value>(
        selector: (Model) -> Value,
        policy!: StateMutationPolicy<Value>
    ): DerivedState<Value> {
        storage.map(selector, policy: policy)
    }

    /** Builds a cached selector through a Lens. */
    public func select<Value>(lens: Lens<Model, Value>): DerivedState<Value> {
        storage.map({model => lens.get(model)})
    }

    /** Builds an equality-filtered selector through a Lens. */
    public func select<Value>(
        lens: Lens<Model, Value>,
        policy!: StateMutationPolicy<Value>
    ): DerivedState<Value> {
        storage.map({model => lens.get(model)}, policy: policy)
    }

    /**
     * Connects one explicit effect interpreter and returns an action-only UI facade. Every future
     * dispatch through the facade commits first and hands the complete batch to this interpreter;
     * effects are never discarded, while views no longer need the root Effect type.
     */
    public func connect(handleEffects!: (EffectBatch<Effect>) -> Unit): ScopedStore<Model, Action> {
        ScopedStore<Model, Action>(
            IdentityScopedModelProjection<Model>(storage),
            {action => dispatch(action, handleEffects: handleEffects)},
            {actions => dispatchAll(actions, handleEffects: handleEffects)},
            {produce => dispatchProduced(produce, handleEffects)}
        )
    }

    /**
     * Builds an action-driven Binding. Because Binding writes return Unit, callers must explicitly
     * provide the effect handoff rather than silently discarding effects.
     */
    public func binding<Value>(
        get!: (Model) -> Value,
        action!: (Value) -> Action,
        handleEffects!: (EffectBatch<Effect>) -> Unit
    ): Binding<Value> {
        projectedBinding<Model, Value>(
            storage,
            get,
            {value => dispatch(action(value), handleEffects: handleEffects)},
            {
                transform =>
                    let model = storage.value
                    let transition = reducer.reduce(model, action(transform(get(model))))
                    commitAndHandle(transition, handleEffects)
            }
        )
    }

    /** Builds an equality-filtered action Binding with explicit effect handoff. */
    public func binding<Value>(
        get!: (Model) -> Value,
        action!: (Value) -> Action,
        handleEffects!: (EffectBatch<Effect>) -> Unit,
        policy!: StateMutationPolicy<Value>
    ): Binding<Value> {
        quotientProjectedBinding<Model, Value>(
            storage,
            get,
            {value => dispatch(action(value), handleEffects: handleEffects)},
            {
                transform =>
                    let model = storage.value
                    let transition = reducer.reduce(model, action(transform(get(model))))
                    commitAndHandle(transition, handleEffects)
            },
            policy
        )
    }

    /** Builds an action-driven Binding through a reusable Lens with explicit effect handoff. */
    public func binding<Value>(
        lens: Lens<Model, Value>,
        action!: (Value) -> Action,
        handleEffects!: (EffectBatch<Effect>) -> Unit
    ): Binding<Value> {
        binding<Value>(get: {model => lens.get(model)}, action: action, handleEffects: handleEffects)
    }

    /** Builds an equality-filtered Lens Binding with explicit effect handoff. */
    public func binding<Value>(
        lens: Lens<Model, Value>,
        action!: (Value) -> Action,
        handleEffects!: (EffectBatch<Effect>) -> Unit,
        policy!: StateMutationPolicy<Value>
    ): Binding<Value> {
        binding<Value>(
            get: {model => lens.get(model)},
            action: action,
            handleEffects: handleEffects,
            policy: policy
        )
    }

    private func reduceAll(actions: Array<Action>): Transition<Model, Effect> {
        var next = storage.value
        var effects = EffectBatch<Effect>()
        for (action in actions) {
            let transition = reducer.reduce(next, action)
            next = transition.model
            if (!transition.effects.isEmpty()) {
                effects = effects.then(transition.effects)
            }
        }
        Transition<Model, Effect>(next, effects: effects)
    }

    private func dispatchProduced(
        produce: ((Action) -> Unit) -> Unit,
        handleEffects: (EffectBatch<Effect>) -> Unit
    ): Unit {
        let fold = EffectActionFold<Model, Action, Effect>(
            storage.value,
            {model, action => reducer.reduce(model, action)}
        )
        produce({action => fold.accept(action)})
        if (fold.count > 0) {
            commitAndHandle(
                Transition<Model, Effect>(fold.model, effects: fold.effects),
                handleEffects
            )
        }
    }

    private func commitAndHandle(
        transition: Transition<Model, Effect>,
        handleEffects: (EffectBatch<Effect>) -> Unit
    ): Unit {
        let previousRevision = storage.revision
        var commitFailure: ?Exception = None
        try {
            storage.value = transition.model
        } catch (error: Exception) {
            if (storage.revision == previousRevision) {
                throw error
            }
            commitFailure = Some(error)
        }
        try {
            handleEffects(transition.effects)
        } catch (effectFailure: Exception) {
            match (commitFailure) {
                case Some(firstFailure) => throw rollbackUiFailure(firstFailure, {=> Some(effectFailure)})
                case None => throw effectFailure
            }
        }
        match (commitFailure) {
            case Some(error) => throw error
            case None => ()
        }
    }
}
