package cui.core

@Test
func diagnosedPolicyCountsResultsAndCanResetWithoutChangingState(): Unit {
    let policy = diagnoseStateMutationPolicy<Int64>(structuralEqualityPolicy<Int64>())
    let state = State<Int64>(1, policy: policy)

    state.value = 1
    state.value = 2
    let snapshot = policy.diagnostics()
    @Expect(snapshot.comparisons, UInt64(2))
    @Expect(snapshot.equivalentResults, UInt64(1))
    @Expect(snapshot.distinctResults, UInt64(1))
    @Expect(snapshot.failures, UInt64(0))
    @Expect(snapshot.totalNanoseconds >= snapshot.maximumNanoseconds)
    @Expect(state.value, Int64(2))

    policy.resetDiagnostics()
    let reset = policy.diagnostics()
    @Expect(reset.comparisons, UInt64(0))
    @Expect(state.value, Int64(2))
}

@Test
func diagnosedPolicyRecordsAndRethrowsComparisonFailure(): Unit {
    let policy = diagnoseStateMutationPolicy<Int64>(
        stateMutationPolicy<Int64>({_, _ => throw IllegalStateException("expected diagnosed failure")})
    )
    var didThrow = false

    try {
        policy.equivalent(1, 1)
    } catch (_: IllegalStateException) {
        didThrow = true
    }

    let snapshot = policy.diagnostics()
    @Expect(didThrow)
    @Expect(snapshot.comparisons, UInt64(1))
    @Expect(snapshot.failures, UInt64(1))
    @Expect(snapshot.equivalentResults, UInt64(0))
    @Expect(snapshot.distinctResults, UInt64(0))
    @Expect(snapshot.totalNanoseconds >= snapshot.maximumNanoseconds)
}
