package cui.core

@Test
func keylessRememberStateAcceptsStructuralMutationPolicy(): Unit {
    let store = StateStore()
    let captured = State<?State<Int64>>(None)
    let initializations = State<Int64>(0)
    let body: () -> Unit = {
        =>
            captured.value = Some(rememberState<Int64>(structuralEqualityPolicy<Int64>()) {
                initializations.value += 1
                0
            })
            Spacer()
    }

    let _ = buildRoot(body, store)
    let _ = buildRoot(body, store)
    let value = captured.value.getOrThrow()
    let notifications = State<Int64>(0)
    let observation = value.observe({_, _ => notifications.value += 1})

    value.value = 0
    @Expect(value.revision, UInt64(0))
    @Expect(notifications.value, Int64(0))
    value.value = 1
    @Expect(value.revision, UInt64(1))
    @Expect(notifications.value, Int64(1))
    @Expect(initializations.value, Int64(1))
    observation.close()
}

@Test
func keyedRememberStateAcceptsClosureMutationPolicy(): Unit {
    let store = StateStore()
    let captured = State<?State<Int64>>(None)
    let comparisons = State<Int64>(0)
    let policy = stateMutationPolicy<Int64>({previous, current =>
        comparisons.value += 1
        previous % 10 == current % 10
    })
    let _ = buildRoot({
        =>
            captured.value = Some(rememberState<Int64>("score", policy) {11})
            Spacer()
    }, store)
    let value = captured.value.getOrThrow()

    value.value = 21
    @Expect(value.value, Int64(11))
    @Expect(value.revision, UInt64(0))
    value.value = 22
    @Expect(value.value, Int64(22))
    @Expect(value.revision, UInt64(1))
    @Expect(comparisons.value, Int64(2))
}

@Test
func closureMutationPolicyFailureLeavesStateUnchanged(): Unit {
    let policy = stateMutationPolicy<Int64>({_, _ => throw IllegalStateException("expected policy failure")})
    let value = State<Int64>(7, policy: policy)
    var didThrow = false
    try {
        value.value = 8
    } catch (_: IllegalStateException) {
        didThrow = true
    }

    @Expect(didThrow)
    @Expect(value.value, Int64(7))
    @Expect(value.revision, UInt64(0))
}

@Test
func rememberedPolicyIsInitializationStateNotRebuildInput(): Unit {
    let store = StateStore()
    let captured = State<?State<Int64>>(None)
    let policyCreations = State<Int64>(0)
    let policyComparisons = State<Int64>(0)
    let body: () -> Unit = {
        =>
            policyCreations.value += 1
            let policy = stateMutationPolicy<Int64>({previous, current =>
                policyComparisons.value += 1
                previous == current
            })
            captured.value = Some(rememberState<Int64>(policy) {5})
            Spacer()
    }

    let _ = buildRoot(body, store)
    let _ = buildRoot(body, store)
    let value = captured.value.getOrThrow()
    value.value = 5

    @Expect(policyCreations.value, Int64(2))
    @Expect(policyComparisons.value, Int64(1))
    @Expect(value.revision, UInt64(0))
}
