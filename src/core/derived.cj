package cui.core

import std.collection.ArrayList

/*
 * Derived, read-only state and two-way bindings.
 *
 * DerivedState follows the pull model that fits a rebuilt UI: reading `value` recomputes only when
 * a source revision moved. Stable instances become one lazy invalidation node in active framework
 * collectors; state-backed instances created inside a build retain direct source edges so ephemeral
 * objects never churn subscriptions. Push-style `observe` owns upstream edges only for its lifetime.
 */

/** A mutable box shared between closures; works around var-capture restrictions. */
class ValueCell<T> {
    var value: T

    init(value: T) {
        this.value = value
    }
}

/*
 * State-backed graphs use the process write epoch as an exact negative filter: if no State was
 * written, no source revision can have moved. An epoch change falls back to the complete revision
 * vector, while custom Observable implementations always use that vector. Samples commit only
 * after compute succeeds, preserving retry and source-self-write semantics.
 */
class DerivedRevisionTracker {
    private let captureSourceRevisions: () -> Array<UInt64>
    private let stateWriteEpochEligible: Bool
    private var seen = Array<UInt64>()
    private var captured: ?Array<UInt64> = None
    private var committedStateWriteEpoch: UInt64 = UInt64(0)
    private var capturedStateWriteEpoch: UInt64 = UInt64(0)
    private var hasCommitted = false

    init(
        captureSourceRevisions: () -> Array<UInt64>,
        stateWriteEpochEligible: Bool
    ) {
        this.captureSourceRevisions = captureSourceRevisions
        this.stateWriteEpochEligible = stateWriteEpochEligible
    }

    func captureChanged(): Bool {
        let stateWriteEpoch = currentStateGeneration()
        if (hasCommitted && stateWriteEpochEligible && stateWriteEpoch == committedStateWriteEpoch) {
            return false
        }
        let current = captureSourceRevisions()
        if (hasCommitted && !revisionsDiffer(seen, current)) {
            if (stateWriteEpochEligible) {
                committedStateWriteEpoch = stateWriteEpoch
            }
            return false
        }
        captured = Some(current)
        capturedStateWriteEpoch = stateWriteEpoch
        true
    }

    func commitCaptured(): Unit {
        seen = match (captured) {
            case Some(revisions) => revisions
            case None => throw IllegalStateException("Derived revision commit requires a captured source vector")
        }
        captured = None
        committedStateWriteEpoch = capturedStateWriteEpoch
        hasCommitted = true
    }

    func stageCaptured(revisions: Array<UInt64>, stateWriteEpoch: UInt64): Unit {
        captured = Some(revisions)
        capturedStateWriteEpoch = stateWriteEpoch
    }

    func usesStateWriteEpoch(): Bool {
        stateWriteEpochEligible
    }
}

private func revisionsDiffer(previous: Array<UInt64>, current: Array<UInt64>): Bool {
    if (previous.size != current.size) {
        return true
    }
    var index: Int64 = 0
    while (index < previous.size) {
        if (previous[index] != current[index]) {
            return true
        }
        index += 1
    }
    false
}

/**
 * A read-only observable computed from one or more sources, created with `derive` or
 * `Observable.map`. The computation is lazy and cached: it reruns only when a source
 * revision changes between reads.
 */
public open class DerivedState<T> <: Observable<T> {
    private let identity = allocateStateIdentity()
    private let compute: () -> T
    private let initialCompute: ?(() -> DerivedInitialComputation<T>)
    private let revisionTracker: DerivedRevisionTracker
    private let invalidationSources: () -> Array<InvalidationSubscriptionFactory>
    private let recordSourceReads: () -> Unit
    private let aggregateDependencyEligible: Bool
    protected var cachedValue: ?T = None
    protected var selfRevision: UInt64 = UInt64(0)

    init(
        compute: () -> T,
        initialCompute: ?(() -> DerivedInitialComputation<T>),
        revisionTracker: DerivedRevisionTracker,
        invalidationSources: () -> Array<InvalidationSubscriptionFactory>,
        recordSourceReads: () -> Unit,
        aggregateDependencyEligible: Bool
    ) {
        this.compute = compute
        this.initialCompute = initialCompute
        this.revisionTracker = revisionTracker
        this.invalidationSources = invalidationSources
        this.recordSourceReads = recordSourceReads
        this.aggregateDependencyEligible = aggregateDependencyEligible
    }

    /** The computed value, refreshed if any source changed since the last read. */
    public prop value: T {
        get() {
            refreshIfStale()
        }
    }

    public func get(): T {
        value
    }

    public prop revision: UInt64 {
        get() {
            let _ = refreshIfStale() // cjcheck-ignore: ignore-result # called for its refresh side effect; selfRevision is read next
            selfRevision
        }
    }

    public func observe(callback: (T, T) -> Unit): StateObservation<T> {
        let previous = ValueCell<T>(value)
        let observationIdentity = allocateStateIdentity()
        let notify = {
            =>
                let next = value
                let before = previous.value
                previous.value = next
                callback(before, next)
        }
        let deferredAction = DeferredStateObserverAction(observationIdentity, notify)
        observeInvalidation(
            {
                =>
                    let deferred = match (currentFrameScheduler()) {
                        case Some(scheduler) => scheduler.deferStateObserver(deferredAction)
                        case None => false
                    }
                    if (!deferred) {
                        notify()
                    }
            }
        )
    }

    private func refreshIfStale(): T {
        if (aggregateDependencyEligible) {
            return collectDerivedStateRead<T>(this, {=> refreshCachedValue()})
        }
        if (cachedValue.isSome() && isStateReadCollectionActive()) {
            recordSourceReads()
        }
        refreshCachedValue()
    }

    protected func refreshCachedValue(): T {
        if (cachedValue.isNone()) {
            match (initialCompute) {
                case Some(initialize) =>
                    let initial = initialize()
                    revisionTracker.stageCaptured(initial.sourceRevisions, initial.stateWriteEpoch)
                    return commitFresh(initial.value)
                case None => ()
            }
        }
        let changed = revisionTracker.captureChanged()
        match (cachedValue) {
            case Some(cached) where !changed => cached
            case _ => recompute()
        }
    }

    protected func settleCachedRepresentative(): Unit {
        cachedValue = Some(refreshCachedValue())
    }

    private func recompute(): T {
        commitFresh(compute())
    }

    protected open func commitFresh(fresh: T): T {
        cachedValue = Some(fresh)
        revisionTracker.commitCaptured()
        selfRevision = nextRevision(selfRevision)
        fresh
    }

    protected func commitCapturedRevisions(): Unit {
        revisionTracker.commitCaptured()
    }

    /**
     * Returns a quotient node that suppresses revisions, observations, and retained invalidations
     * while consecutive results are equivalent under `policy`.
     */
    public func distinct(policy: StateMutationPolicy<T>): DerivedState<T> {
        deriveDistinct<T, T>(this, {value => value}, policy)
    }

    func usesStateWriteEpoch(): Bool {
        revisionTracker.usesStateWriteEpoch()
    }

    func dependencyIdentity(): UInt64 {
        identity
    }

    func observeInvalidation(callback: () -> Unit): StateObservation<T> {
        let cancels = connectInvalidations(invalidationSources(), invalidationCallback(callback))
        StateObservation<T>({
            => match (closeInvalidations(cancels)) {
                case Some(error) => throw error
                case None => ()
            }
        })
    }

    protected open func invalidationCallback(callback: () -> Unit): () -> Unit {
        callback
    }
}

/* Result equivalence is a separate runtime specialization, so ordinary nodes pay no field tax. */
private class DistinctDerivedState<T> <: DerivedState<T> {
    private let policy: StateMutationPolicy<T>

    init(
        compute: () -> T,
        revisionTracker: DerivedRevisionTracker,
        invalidationSources: () -> Array<InvalidationSubscriptionFactory>,
        recordSourceReads: () -> Unit,
        aggregateDependencyEligible: Bool,
        policy: StateMutationPolicy<T>
    ) {
        super(compute, None, revisionTracker, invalidationSources, recordSourceReads, aggregateDependencyEligible)
        this.policy = policy
    }

    protected override func commitFresh(fresh: T): T {
        match (cachedValue) {
            case Some(cached) =>
                if (policy.equivalent(cached, fresh)) {
                    commitCapturedRevisions()
                    return cached
                }
            case None => ()
        }
        super.commitFresh(fresh)
    }

    protected override func invalidationCallback(callback: () -> Unit): () -> Unit {
        settleCachedRepresentative()
        let observedRevision = ValueCell<UInt64>(selfRevision)
        {
            =>
                settleCachedRepresentative()
                let nextRevision = selfRevision
                if (nextRevision != observedRevision.value) {
                    observedRevision.value = nextRevision
                    callback()
                }
        }
    }
}

/** Returns a read-only state computed from one source. */
public func derive<A, T>(source: Observable<A>, compute: (A) -> T): DerivedState<T> {
    let stateEpochEligible = usesStateWriteEpoch(source)
    DerivedState<T>(
        {=> compute(source.get())},
        None,
        DerivedRevisionTracker({=> [source.revision]}, stateEpochEligible),
        {=> invalidationFactories(source)},
        {=> recordRevision(source)},
        shouldAggregateDerivedDependency(stateEpochEligible)
    )
}

/* Builds a one-source derived quotient without adding a second identity/projection node. */
func deriveDistinct<A, T>(
    source: Observable<A>,
    compute: (A) -> T,
    policy: StateMutationPolicy<T>
): DerivedState<T> {
    let stateEpochEligible = usesStateWriteEpoch(source)
    DistinctDerivedState<T>(
        {=> compute(source.get())},
        DerivedRevisionTracker({=> [source.revision]}, stateEpochEligible),
        {=> invalidationFactories(source)},
        {=> recordRevision(source)},
        shouldAggregateDerivedDependency(stateEpochEligible),
        policy
    )
}

/* Builds a fused quotient over one fixed heterogeneous source product. */
func fixedDistinctDerivedState<T>(
    compute: () -> T,
    captureSourceRevisions: () -> Array<UInt64>,
    invalidationSources: () -> Array<InvalidationSubscriptionFactory>,
    recordSourceReads: () -> Unit,
    stateWriteEpochEligible: Bool,
    policy: StateMutationPolicy<T>
): DerivedState<T> {
    DistinctDerivedState<T>(
        compute,
        DerivedRevisionTracker(captureSourceRevisions, stateWriteEpochEligible),
        invalidationSources,
        recordSourceReads,
        shouldAggregateDerivedDependency(stateWriteEpochEligible),
        policy
    )
}

/** Returns a read-only state computed from two sources. */
public func derive<A, B, T>(first: Observable<A>, second: Observable<B>, compute: (A, B) -> T): DerivedState<T> {
    let stateEpochEligible = usesStateWriteEpoch(first) && usesStateWriteEpoch(second)
    DerivedState<T>(
        {=> compute(first.get(), second.get())},
        None,
        DerivedRevisionTracker(
            {=> [first.revision, second.revision]},
            stateEpochEligible
        ),
        {=> invalidationFactories(first, second)},
        {
            =>
                recordRevision(first)
                recordRevision(second)
        },
        shouldAggregateDerivedDependency(stateEpochEligible)
    )
}

/** Returns a read-only state computed from three sources. */
public func derive<A, B, C, T>(
    first: Observable<A>,
    second: Observable<B>,
    third: Observable<C>,
    compute: (A, B, C) -> T
): DerivedState<T> {
    let stateEpochEligible = usesStateWriteEpoch(first) && usesStateWriteEpoch(second) && usesStateWriteEpoch(third)
    DerivedState<T>(
        {=> compute(first.get(), second.get(), third.get())},
        None,
        DerivedRevisionTracker(
            {=> [first.revision, second.revision, third.revision]},
            stateEpochEligible
        ),
        {=> invalidationFactories(first, second, third)},
        {
            =>
                recordRevision(first)
                recordRevision(second)
                recordRevision(third)
        },
        shouldAggregateDerivedDependency(stateEpochEligible)
    )
}

private func deriveStableStates<A, T>(
    stableSources: Array<State<A>>,
    compute: (Array<A>) -> T
): DerivedState<T> {
    let stateEpochEligible = true
    DerivedState<T>(
        {=> compute(currentStateValues(stableSources))},
        Some({=> initialStateComputation(stableSources, compute)}),
        DerivedRevisionTracker({=> currentStateRevisions(stableSources)}, stateEpochEligible),
        {=> invalidationFactories(stableSources)},
        {=> recordStateRevisions(stableSources)},
        shouldAggregateDerivedDependency(stateEpochEligible)
    )
}

/**
 * Returns a read-only state derived from a snapshotted array of writable State sources. This avoids
 * constructing an erased Observable array and keeps value/revision sampling statically specialized.
 */
public func deriveStates<A, T>(sources: Array<State<A>>, compute: (Array<A>) -> T): DerivedState<T> {
    deriveStableStates(sources.clone(), compute)
}

/**
 * Returns a read-only state computed from any number of same-typed Observable sources. The source
 * topology is snapshotted at construction. A homogeneous runtime State vector is normalized once
 * into the statically specialized value/revision path even when the array type was erased.
 */
public func derive<A, T>(sources: Array<Observable<A>>, compute: (Array<A>) -> T): DerivedState<T> {
    match (concreteStateSources(sources)) {
        case Some(states) => return deriveStableStates(states, compute)
        case None => ()
    }
    let stableSources = sources.clone()
    let stateEpochEligible = allUseStateWriteEpoch(stableSources)
    let initialCompute: ?(() -> DerivedInitialComputation<T>) = if (stateEpochEligible) {
        Some({=> initialStateBackedComputation(stableSources, compute)})
    } else {
        None
    }
    DerivedState<T>(
        {=> compute(currentValues(stableSources))},
        initialCompute,
        DerivedRevisionTracker({=> currentRevisions(stableSources)}, stateEpochEligible),
        {=> invalidationFactories(stableSources)},
        {=> recordRevisions(stableSources)},
        shouldAggregateDerivedDependency(stateEpochEligible)
    )
}

private func concreteStateSources<A>(sources: Array<Observable<A>>): ?Array<State<A>> {
    let states = ArrayList<State<A>>(sources.size)
    for (source in sources) {
        match (source as State<A>) {
            case Some(state) => states.add(state)
            case None => return None
        }
    }
    Some(states.toArray())
}

private func currentStateValues<A>(sources: Array<State<A>>): Array<A> {
    Array<A>(sources.size, {i => sources[i].get()})
}

private func currentStateRevisions<A>(sources: Array<State<A>>): Array<UInt64> {
    Array<UInt64>(sources.size, {i => sources[i].revision})
}

private func currentValues<A>(sources: Array<Observable<A>>): Array<A> {
    Array<A>(sources.size, {i => sources[i].get()})
}

private func currentRevisions<A>(sources: Array<Observable<A>>): Array<UInt64> {
    Array<UInt64>(sources.size, {i => sources[i].revision})
}

func recordRevision<T>(source: Observable<T>): Unit {
    match (source.revision) {
        case _ => ()
    }
}

private func recordRevisions<T>(sources: Array<Observable<T>>): Unit {
    for (source in sources) {
        recordRevision(source)
    }
}

private func recordStateRevisions<T>(sources: Array<State<T>>): Unit {
    for (source in sources) {
        match (source.revision) {
            case _ => ()
        }
    }
}

func shouldAggregateDerivedDependency(stateEpochEligible: Bool): Bool {
    isRememberedValueConstructionActive() || !isStateReadCollectionActive() || !stateEpochEligible
}
