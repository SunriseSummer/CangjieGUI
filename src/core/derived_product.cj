package cui.core

/* Shared constructor for fixed heterogeneous source products wider than the built-in small cases. */
private func fixedDerivedState<T>(
    compute: () -> T,
    captureSourceRevisions: () -> Array<UInt64>,
    invalidationSources: () -> Array<InvalidationSubscriptionFactory>,
    recordSourceReads: () -> Unit,
    stateWriteEpochEligible: Bool
): DerivedState<T> {
    DerivedState<T>(
        compute,
        None,
        DerivedRevisionTracker(captureSourceRevisions, stateWriteEpochEligible),
        invalidationSources,
        recordSourceReads,
        shouldAggregateDerivedDependency(stateWriteEpochEligible)
    )
}

/** Returns one fused read-only state computed from four heterogeneous sources. */
public func derive<A, B, C, D, T>(
    first: Observable<A>,
    second: Observable<B>,
    third: Observable<C>,
    fourth: Observable<D>,
    compute: (A, B, C, D) -> T
): DerivedState<T> {
    let stateEpochEligible = usesStateWriteEpoch(first) && usesStateWriteEpoch(second) && usesStateWriteEpoch(third) &&
        usesStateWriteEpoch(fourth)
    fixedDerivedState<T>(
        {=> compute(first.get(), second.get(), third.get(), fourth.get())},
        {=> [first.revision, second.revision, third.revision, fourth.revision]},
        {=> invalidationFactories(first, second, third, fourth)},
        {
            =>
                recordRevision(first)
                recordRevision(second)
                recordRevision(third)
                recordRevision(fourth)
        },
        stateEpochEligible
    )
}

/** Returns one fused read-only state computed from five heterogeneous sources. */
public func derive<A, B, C, D, E, T>(
    first: Observable<A>,
    second: Observable<B>,
    third: Observable<C>,
    fourth: Observable<D>,
    fifth: Observable<E>,
    compute: (A, B, C, D, E) -> T
): DerivedState<T> {
    let stateEpochEligible = usesStateWriteEpoch(first) && usesStateWriteEpoch(second) && usesStateWriteEpoch(third) &&
        usesStateWriteEpoch(fourth) && usesStateWriteEpoch(fifth)
    fixedDerivedState<T>(
        {=> compute(first.get(), second.get(), third.get(), fourth.get(), fifth.get())},
        {=> [first.revision, second.revision, third.revision, fourth.revision, fifth.revision]},
        {=> invalidationFactories(first, second, third, fourth, fifth)},
        {
            =>
                recordRevision(first)
                recordRevision(second)
                recordRevision(third)
                recordRevision(fourth)
                recordRevision(fifth)
        },
        stateEpochEligible
    )
}
