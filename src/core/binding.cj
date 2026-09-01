package cui.core

/**
 * A writable projection of a component inside another bindable value, created with
 * `Bindable.project`. Focused transformations compose into one root-model update, so
 * nested projections retain one source of truth and one read-modify-write snapshot.
 */
public class Binding<T> <: Bindable<T> {
    private let read: () -> T
    private let write: (T) -> Unit
    private let modify: ((T) -> T) -> Unit
    private let revisionSource: () -> UInt64
    private let snapshotSource: () -> (T, UInt64)
    private let observeSource: ((T, T) -> Unit) -> StateObservation<T>
    private let invalidationSource: InvalidationSubscriptionFactory
    private let stateWriteEpochEligible: Bool

    init(
        read: () -> T,
        write: (T) -> Unit,
        modify: ((T) -> T) -> Unit,
        revisionSource: () -> UInt64,
        snapshotSource: () -> (T, UInt64),
        observeSource: ((T, T) -> Unit) -> StateObservation<T>,
        invalidationSource: InvalidationSubscriptionFactory,
        stateWriteEpochEligible: Bool
    ) {
        this.read = read
        this.write = write
        this.modify = modify
        this.revisionSource = revisionSource
        this.snapshotSource = snapshotSource
        this.observeSource = observeSource
        this.invalidationSource = invalidationSource
        this.stateWriteEpochEligible = stateWriteEpochEligible
    }

    public mut prop value: T {
        get() {
            read()
        }
        set(next) {
            write(next)
        }
    }

    public prop revision: UInt64 {
        get() {
            revisionSource()
        }
    }

    /** Lifts one focused-value transformation into one source-model update. */
    public func update(transform: (T) -> T): Unit {
        modify(transform)
    }

    public func observe(callback: (T, T) -> Unit): StateObservation<T> {
        observeSource(callback)
    }

    func usesStateWriteEpoch(): Bool {
        stateWriteEpochEligible
    }

    func observeInvalidation(callback: () -> Unit): StateObservation<T> {
        let cancel = invalidationSource.subscribe(callback)
        StateObservation<T>({=> cancel()})
    }

    func valueRevisionSnapshot(): (T, UInt64) {
        snapshotSource()
    }
}

/** Builds the binding behind `Bindable.project`. */
internal func bindingOf<S, T>(source: Bindable<S>, get: (S) -> T, set: (S, T) -> S): Binding<T> {
    projectedBinding<S, T>(
        source,
        get,
        bindingWrite(source, set),
        bindingModify(source, get, set)
    )
}

/** Builds a writable projection with an explicit observational quotient on its read side. */
internal func bindingOf<S, T>(
    source: Bindable<S>,
    get: (S) -> T,
    set: (S, T) -> S,
    policy: StateMutationPolicy<T>
): Binding<T> {
    quotientProjectedBinding<S, T>(
        source,
        get,
        bindingWrite(source, set),
        bindingModify(source, get, set),
        policy
    )
}

/** Builds a binding that preserves a Lens's fused endomorphism path for focused updates. */
internal func bindingOf<S, T>(source: Bindable<S>, lens: Lens<S, T>): Binding<T> {
    projectedBinding<S, T>(
        source,
        {value => lens.get(value)},
        bindingWrite<S, T>(source, {value, focused => lens.set(value, focused)}),
        {transform => source.update({value => lens.update(value, transform)})}
    )
}

/** Adds a read quotient without discarding the Lens's fused writable update path. */
internal func bindingOf<S, T>(
    source: Bindable<S>,
    lens: Lens<S, T>,
    policy: StateMutationPolicy<T>
): Binding<T> {
    quotientProjectedBinding<S, T>(
        source,
        {value => lens.get(value)},
        bindingWrite<S, T>(source, {value, focused => lens.set(value, focused)}),
        {transform => source.update({value => lens.update(value, transform)})},
        policy
    )
}

private func bindingWrite<S, T>(source: Bindable<S>, set: (S, T) -> S): (T) -> Unit {
    match (source as State<S>) {
        case Some(state) => {next => state.value = set(state.value, next)}
        case None => {next => source.update({current => set(current, next)})}
    }
}

private func bindingModify<S, T>(
    source: Bindable<S>,
    get: (S) -> T,
    set: (S, T) -> S
): ((T) -> T) -> Unit {
    {transform => source.update({current => set(current, transform(get(current)))})}
}

/* Builds a writable projection whose write authority may be an action dispatcher, not a Bindable. */
internal func projectedBinding<S, T>(
    source: Observable<S>,
    get: (S) -> T,
    write: (T) -> Unit,
    modify: ((T) -> T) -> Unit
): Binding<T> {
    Binding<T>(
        {=> get(source.get())},
        write,
        modify,
        {=> source.revision},
        {
            =>
                let (value, revision) = observableValueRevisionSnapshot(source)
                (get(value), revision)
        },
        {
            callback =>
                let observation = source.observe({prev, cur => callback(get(prev), get(cur))})
                StateObservation<T>({=> observation.close()})
        },
        TypedInvalidationSubscriptionFactory<S>(source),
        usesStateWriteEpoch(source)
    )
}

/* Adds a result quotient to the read side while preserving the original write authority. */
internal func quotientProjectedBinding<S, T>(
    source: Observable<S>,
    get: (S) -> T,
    write: (T) -> Unit,
    modify: ((T) -> T) -> Unit,
    policy: StateMutationPolicy<T>
): Binding<T> {
    projectedValueBinding<T>(source.map(get, policy: policy), write, modify)
}

/* Builds a Binding from an already projected value source and independent write authority. */
internal func projectedValueBinding<T>(
    source: Observable<T>,
    write: (T) -> Unit,
    modify: ((T) -> T) -> Unit
): Binding<T> {
    Binding<T>(
        {=> source.get()},
        write,
        modify,
        {=> source.revision},
        {=> observableValueRevisionSnapshot(source)},
        {callback => source.observe(callback)},
        TypedInvalidationSubscriptionFactory<T>(source),
        usesStateWriteEpoch(source)
    )
}

func usesStateWriteEpoch<T>(source: Observable<T>): Bool {
    match (source as State<T>) {
        case Some(_) => true
        case None => match (source as DerivedState<T>) {
            case Some(derived) => derived.usesStateWriteEpoch()
            case None => match (source as Binding<T>) {
                case Some(binding) => binding.usesStateWriteEpoch()
                case None => false
            }
        }
    }
}

func allUseStateWriteEpoch<T>(sources: Array<Observable<T>>): Bool {
    for (source in sources) {
        if (!usesStateWriteEpoch(source)) {
            return false
        }
    }
    true
}
