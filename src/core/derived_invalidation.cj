package cui.core

import std.collection.ArrayList

/* Type-erased constructor for one lazily attached Observable invalidation subscription. */
interface InvalidationSubscriptionFactory {
    func subscribe(callback: () -> Unit): () -> Unit
}

class TypedInvalidationSubscriptionFactory<T> <: InvalidationSubscriptionFactory {
    private let source: Observable<T>

    init(source: Observable<T>) {
        this.source = source
    }

    /** Attaches one invalidation-only callback and returns its idempotent cancellation action. */
    public func subscribe(callback: () -> Unit): () -> Unit {
        subscribeObservableInvalidation(source, callback)
    }
}

/* Keeps State-array invalidation edges statically typed through lazy attachment. */
class StateInvalidationSubscriptionFactory<T> <: InvalidationSubscriptionFactory {
    private let source: State<T>

    init(source: State<T>) {
        this.source = source
    }

    /** Attaches one statically typed State invalidation callback and returns its cancellation. */
    public func subscribe(callback: () -> Unit): () -> Unit {
        let observation = source.observe({_, _ => callback()})
        {=> observation.close()}
    }
}

func invalidationFactories<T>(source: Observable<T>): Array<InvalidationSubscriptionFactory> {
    [TypedInvalidationSubscriptionFactory<T>(source)]
}

func invalidationFactories<A, B>(
    first: Observable<A>,
    second: Observable<B>
): Array<InvalidationSubscriptionFactory> {
    [TypedInvalidationSubscriptionFactory<A>(first), TypedInvalidationSubscriptionFactory<B>(second)]
}

func invalidationFactories<A, B, C>(
    first: Observable<A>,
    second: Observable<B>,
    third: Observable<C>
): Array<InvalidationSubscriptionFactory> {
    [TypedInvalidationSubscriptionFactory<A>(first), TypedInvalidationSubscriptionFactory<B>(second),
        TypedInvalidationSubscriptionFactory<C>(third)]
}

func invalidationFactories<A, B, C, D>(
    first: Observable<A>,
    second: Observable<B>,
    third: Observable<C>,
    fourth: Observable<D>
): Array<InvalidationSubscriptionFactory> {
    [TypedInvalidationSubscriptionFactory<A>(first), TypedInvalidationSubscriptionFactory<B>(second),
        TypedInvalidationSubscriptionFactory<C>(third), TypedInvalidationSubscriptionFactory<D>(fourth)]
}

func invalidationFactories<A, B, C, D, E>(
    first: Observable<A>,
    second: Observable<B>,
    third: Observable<C>,
    fourth: Observable<D>,
    fifth: Observable<E>
): Array<InvalidationSubscriptionFactory> {
    [TypedInvalidationSubscriptionFactory<A>(first), TypedInvalidationSubscriptionFactory<B>(second),
        TypedInvalidationSubscriptionFactory<C>(third), TypedInvalidationSubscriptionFactory<D>(fourth),
        TypedInvalidationSubscriptionFactory<E>(fifth)]
}

func invalidationFactories<T>(sources: Array<Observable<T>>): Array<InvalidationSubscriptionFactory> {
    Array<InvalidationSubscriptionFactory>(sources.size,
        {index => TypedInvalidationSubscriptionFactory<T>(sources[index])})
}

func invalidationFactories<T>(sources: Array<State<T>>): Array<InvalidationSubscriptionFactory> {
    Array<InvalidationSubscriptionFactory>(sources.size,
        {index => StateInvalidationSubscriptionFactory<T>(sources[index])})
}

func connectInvalidations(
    factories: Array<InvalidationSubscriptionFactory>,
    callback: () -> Unit
): Array<() -> Unit> {
    let cancels = ArrayList<() -> Unit>()
    try {
        for (factory in factories) {
            cancels.add(factory.subscribe(callback))
        }
    } catch (connectFailure: Exception) {
        throw rollbackUiFailure(connectFailure, {=> closeInvalidations(cancels.toArray())})
    }
    cancels.toArray()
}

func closeInvalidations(cancels: Array<() -> Unit>): ?Exception {
    var failures: ?UiFailureCollector = None
    var index = cancels.size - 1
    while (index >= 0) {
        try {
            cancels[index]()
        } catch (error: Exception) {
            failures = appendUiFailure(failures, error)
        }
        index -= 1
    }
    collectedUiFailure(failures)
}

private func subscribeObservableInvalidation<T>(source: Observable<T>, callback: () -> Unit): () -> Unit {
    match (source as State<T>) {
        case Some(state) =>
            let observation = state.observe({_, _ => callback()})
            {=> observation.close()}
        case None => match (source as DerivedState<T>) {
            case Some(derived) =>
                let observation = derived.observeInvalidation(callback)
                {=> observation.close()}
            case None => match (source as Binding<T>) {
                case Some(binding) =>
                    let observation = binding.observeInvalidation(callback)
                    {=> observation.close()}
                case None =>
                    let observation = source.observe({_, _ => callback()})
                    {=> observation.close()}
            }
        }
    }
}
