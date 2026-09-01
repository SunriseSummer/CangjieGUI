package cui.core

/** Returns one fused one-source quotient under an explicit result-equivalence policy. */
public func derive<A, T>(
    source: Observable<A>,
    compute: (A) -> T,
    policy!: StateMutationPolicy<T>
): DerivedState<T> {
    deriveDistinct(source, compute, policy)
}

/** Returns one fused two-source quotient under an explicit result-equivalence policy. */
public func derive<A, B, T>(
    first: Observable<A>,
    second: Observable<B>,
    compute: (A, B) -> T,
    policy!: StateMutationPolicy<T>
): DerivedState<T> {
    let stateEpochEligible = usesStateWriteEpoch(first) && usesStateWriteEpoch(second)
    fixedDistinctDerivedState<T>(
        {=> compute(first.get(), second.get())},
        {=> [first.revision, second.revision]},
        {=> invalidationFactories(first, second)},
        {
            =>
                recordRevision(first)
                recordRevision(second)
        },
        stateEpochEligible,
        policy
    )
}

/** Returns one fused three-source quotient under an explicit result-equivalence policy. */
public func derive<A, B, C, T>(
    first: Observable<A>,
    second: Observable<B>,
    third: Observable<C>,
    compute: (A, B, C) -> T,
    policy!: StateMutationPolicy<T>
): DerivedState<T> {
    let stateEpochEligible = usesStateWriteEpoch(first) && usesStateWriteEpoch(second) && usesStateWriteEpoch(third)
    fixedDistinctDerivedState<T>(
        {=> compute(first.get(), second.get(), third.get())},
        {=> [first.revision, second.revision, third.revision]},
        {=> invalidationFactories(first, second, third)},
        {
            =>
                recordRevision(first)
                recordRevision(second)
                recordRevision(third)
        },
        stateEpochEligible,
        policy
    )
}

/** Returns one fused four-source quotient under an explicit result-equivalence policy. */
public func derive<A, B, C, D, T>(
    first: Observable<A>,
    second: Observable<B>,
    third: Observable<C>,
    fourth: Observable<D>,
    compute: (A, B, C, D) -> T,
    policy!: StateMutationPolicy<T>
): DerivedState<T> {
    let stateEpochEligible = usesStateWriteEpoch(first) && usesStateWriteEpoch(second) && usesStateWriteEpoch(third) &&
        usesStateWriteEpoch(fourth)
    fixedDistinctDerivedState<T>(
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
        stateEpochEligible,
        policy
    )
}

/** Returns one fused five-source quotient under an explicit result-equivalence policy. */
public func derive<A, B, C, D, E, T>(
    first: Observable<A>,
    second: Observable<B>,
    third: Observable<C>,
    fourth: Observable<D>,
    fifth: Observable<E>,
    compute: (A, B, C, D, E) -> T,
    policy!: StateMutationPolicy<T>
): DerivedState<T> {
    let stateEpochEligible = usesStateWriteEpoch(first) && usesStateWriteEpoch(second) && usesStateWriteEpoch(third) &&
        usesStateWriteEpoch(fourth) && usesStateWriteEpoch(fifth)
    fixedDistinctDerivedState<T>(
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
        stateEpochEligible,
        policy
    )
}
