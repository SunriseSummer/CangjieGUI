package cui.core

/*
 * Keeps ordinary nested scopes fused onto one derived node. An explicit quotient policy is a real
 * semantic boundary: later projections fuse onto that distinct node instead of bypassing it.
 */
interface ScopedModelProjection<Model> {
    func observable(): Observable<Model>
    func focus<Local>(transform: (Model) -> Local): ScopedModelProjection<Local>
    func focus<Local>(
        transform: (Model) -> Local,
        policy!: StateMutationPolicy<Local>
    ): ScopedModelProjection<Local>
    func select<Local>(transform: (Model) -> Local): DerivedState<Local>
    func select<Local>(
        transform: (Model) -> Local,
        policy!: StateMutationPolicy<Local>
    ): DerivedState<Local>
}

/* Identity connection keeps the root Observable fast path until a real projection is requested. */
class IdentityScopedModelProjection<Model> <: ScopedModelProjection<Model> {
    private let source: Observable<Model>

    init(source: Observable<Model>) {
        this.source = source
    }

    /**
     * Returns the root Observable without creating an identity DerivedState.
     */
    public func observable(): Observable<Model> {
        source
    }

    /**
     * Starts a fused projection at the first real state boundary.
     */
    public func focus<Local>(transform: (Model) -> Local): ScopedModelProjection<Local> {
        FusedScopedModelProjection<Model, Local>(source, transform)
    }

    /**
     * Starts a fused projection with an explicit observational-equivalence boundary.
     */
    public func focus<Local>(
        transform: (Model) -> Local,
        policy!: StateMutationPolicy<Local>
    ): ScopedModelProjection<Local> {
        FusedScopedModelProjection<Model, Local>(source, transform, policy)
    }

    /** Selects directly from the root source without an identity projection node. */
    public func select<Local>(transform: (Model) -> Local): DerivedState<Local> {
        source.map(transform)
    }

    /** Selects one root quotient under an explicit result-equivalence policy. */
    public func select<Local>(
        transform: (Model) -> Local,
        policy!: StateMutationPolicy<Local>
    ): DerivedState<Local> {
        source.map(transform, policy: policy)
    }
}

class FusedScopedModelProjection<Root, Model> <: ScopedModelProjection<Model> {
    private let rootSource: Observable<Root>
    private let projectModel: (Root) -> Model
    private let node: DerivedState<Model>
    private let quotientBoundary: Bool

    init(rootSource: Observable<Root>, projectModel: (Root) -> Model) {
        this.rootSource = rootSource
        this.projectModel = projectModel
        node = rootSource.map(projectModel)
        quotientBoundary = false
    }

    init(
        rootSource: Observable<Root>,
        projectModel: (Root) -> Model,
        policy: StateMutationPolicy<Model>
    ) {
        this.rootSource = rootSource
        this.projectModel = projectModel
        node = rootSource.map(projectModel, policy: policy)
        quotientBoundary = true
    }

    /**
     * Returns the single derived node that represents this composed projection.
     */
    public func observable(): Observable<Model> {
        node
    }

    /**
     * Composes an ordinary projection, fusing through non-quotient ancestors only.
     */
    public func focus<Local>(transform: (Model) -> Local): ScopedModelProjection<Local> {
        if (quotientBoundary) {
            return FusedScopedModelProjection<Model, Local>(node, transform)
        }
        FusedScopedModelProjection<Root, Local>(
            rootSource,
            {root => transform(projectModel(root))}
        )
    }

    /**
     * Composes a projection and establishes a new observational-equivalence boundary.
     */
    public func focus<Local>(
        transform: (Model) -> Local,
        policy!: StateMutationPolicy<Local>
    ): ScopedModelProjection<Local> {
        if (quotientBoundary) {
            return FusedScopedModelProjection<Model, Local>(node, transform, policy)
        }
        FusedScopedModelProjection<Root, Local>(
            rootSource,
            {root => transform(projectModel(root))},
            policy
        )
    }

    /** Fuses a selector through ordinary scope products and stops at a quotient boundary. */
    public func select<Local>(transform: (Model) -> Local): DerivedState<Local> {
        if (quotientBoundary) {
            return node.map(transform)
        }
        rootSource.map({root => transform(projectModel(root))})
    }

    /** Fuses the selector and its result quotient through ordinary scope products. */
    public func select<Local>(
        transform: (Model) -> Local,
        policy!: StateMutationPolicy<Local>
    ): DerivedState<Local> {
        if (quotientBoundary) {
            return node.map(transform, policy: policy)
        }
        rootSource.map({root => transform(projectModel(root))}, policy: policy)
    }
}

/**
 * A feature-local view of a root ModelStore or connected EffectStore. It exposes only the focused
 * model and local Action vocabulary, retains a single root source of truth, and composes scopes
 * without intermediate action arrays during batch dispatch.
 */
public class ScopedStore<Model, Action> <: Observable<Model> {
    private let projection: ScopedModelProjection<Model>
    private let source: Observable<Model>
    private let dispatchAction: (Action) -> Unit
    private let dispatchBatch: (Array<Action>) -> Unit
    private let dispatchProduced: (((Action) -> Unit) -> Unit) -> Unit

    init(
        projection: ScopedModelProjection<Model>,
        dispatchAction: (Action) -> Unit,
        dispatchBatch: (Array<Action>) -> Unit,
        dispatchProduced: (((Action) -> Unit) -> Unit) -> Unit
    ) {
        this.projection = projection
        source = projection.observable()
        this.dispatchAction = dispatchAction
        this.dispatchBatch = dispatchBatch
        this.dispatchProduced = dispatchProduced
    }

    /** Reads the latest focused model. */
    public func get(): Model {
        source.get()
    }

    /** Revision of this focus; an identity connection shares the root store's revision. */
    public prop revision: UInt64 {
        get() {
            source.revision
        }
    }

    /** Observes committed transitions of this focused projection. */
    public func observe(callback: (Model, Model) -> Unit): StateObservation<Model> {
        source.observe(callback)
    }

    /** Lifts and dispatches one local Action to the root store. */
    public func dispatch(action: Action): Unit {
        dispatchAction(action)
    }

    /**
     * Lifts an ordered local Action sequence and folds it into one root commit. An empty sequence
     * performs no work; a failed reducer call commits neither local nor root intermediate state.
     */
    public func dispatchAll(actions: Array<Action>): Unit {
        if (actions.isEmpty()) {
            return
        }
        dispatchBatch(actions)
    }

    /** Builds a cached read-only selector from the focused model. */
    public func select<Value>(selector: (Model) -> Value): DerivedState<Value> {
        projection.select(selector)
    }

    /** Builds a selector that filters equivalent projected results. */
    public func select<Value>(
        selector: (Model) -> Value,
        policy!: StateMutationPolicy<Value>
    ): DerivedState<Value> {
        projection.select(selector, policy: policy)
    }

    /** Builds a cached read-only selector through a Lens. */
    public func select<Value>(lens: Lens<Model, Value>): DerivedState<Value> {
        projection.select({model => lens.get(model)})
    }

    /** Builds an equality-filtered selector through a Lens. */
    public func select<Value>(
        lens: Lens<Model, Value>,
        policy!: StateMutationPolicy<Value>
    ): DerivedState<Value> {
        projection.select({model => lens.get(model)}, policy: policy)
    }

    /** Focuses this store again while composing child Actions into this feature's vocabulary. */
    public func scope<LocalModel, LocalAction>(
        state!: (Model) -> LocalModel,
        action!: (LocalAction) -> Action
    ): ScopedStore<LocalModel, LocalAction> {
        makeScope<LocalModel, LocalAction>(projection.focus<LocalModel>(state), action)
    }

    /** Focuses this store again and filters equivalent changes in the child domain. */
    public func scope<LocalModel, LocalAction>(
        state!: (Model) -> LocalModel,
        action!: (LocalAction) -> Action,
        policy!: StateMutationPolicy<LocalModel>
    ): ScopedStore<LocalModel, LocalAction> {
        makeScope<LocalModel, LocalAction>(projection.focus<LocalModel>(state, policy: policy), action)
    }

    /** Focuses this store again through a composed Lens boundary. */
    public func scope<LocalModel, LocalAction>(
        state!: Lens<Model, LocalModel>,
        action!: (LocalAction) -> Action
    ): ScopedStore<LocalModel, LocalAction> {
        makeScope<LocalModel, LocalAction>(projection.focus<LocalModel>({model => state.get(model)}), action)
    }

    /** Focuses through a Lens and filters equivalent changes in the child domain. */
    public func scope<LocalModel, LocalAction>(
        state!: Lens<Model, LocalModel>,
        action!: (LocalAction) -> Action,
        policy!: StateMutationPolicy<LocalModel>
    ): ScopedStore<LocalModel, LocalAction> {
        makeScope<LocalModel, LocalAction>(
            projection.focus<LocalModel>({model => state.get(model)}, policy: policy),
            action
        )
    }

    /** Focuses again through one composable state/Action feature boundary. */
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
            projection.focus<LocalModel>({model => state.get(model)}, policy: policy),
            path.action.embedder()
        )
    }

    /** Builds a control Binding whose writes are lifted local Actions. */
    public func binding<Value>(
        get!: (Model) -> Value,
        action!: (Value) -> Action
    ): Binding<Value> {
        projectedBinding<Model, Value>(
            source,
            get,
            {value => dispatchAction(action(value))},
            {
                transform =>
                    let model = source.get()
                    dispatchAction(action(transform(get(model))))
            }
        )
    }

    /** Builds an action Binding whose fused read projection filters equivalent values. */
    public func binding<Value>(
        get!: (Model) -> Value,
        action!: (Value) -> Action,
        policy!: StateMutationPolicy<Value>
    ): Binding<Value> {
        projectedValueBinding<Value>(
            projection.select(get, policy: policy),
            {value => dispatchAction(action(value))},
            {
                transform =>
                    let model = source.get()
                    dispatchAction(action(transform(get(model))))
            }
        )
    }

    /** Builds an action-driven Binding through a reusable Lens. */
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
        childProjection: ScopedModelProjection<LocalModel>,
        liftAction: (LocalAction) -> Action
    ): ScopedStore<LocalModel, LocalAction> {
        ScopedStore<LocalModel, LocalAction>(
            childProjection,
            {localAction => dispatchAction(liftAction(localAction))},
            {
                actions => dispatchProduced({
                    acceptParent => for (localAction in actions) {
                        acceptParent(liftAction(localAction))
                    }
                })
            },
            {
                produceLocal => dispatchProduced({
                    acceptParent => produceLocal({localAction => acceptParent(liftAction(localAction))})
                })
            }
        )
    }
}
