package cui.core

private class PolicyPullbackModel {
    let count: Int64
    let sibling: String

    init(count: Int64, sibling: String) {
        this.count = count
        this.sibling = sibling
    }
}

private class PolicyPullbackProbe {
    var notifications: Int64 = 0
    var calls: Int64 = 0
}

@Test
func policyPullbackSuppressesChangesOutsideItsProjection(): Unit {
    let policy = structuralEqualityPolicy<Int64>().pullback<PolicyPullbackModel>({model => model.count})
    let model = State<PolicyPullbackModel>(PolicyPullbackModel(2, "a"), policy: policy)
    let probe = PolicyPullbackProbe()
    let observation = model.observe({_, _ => probe.notifications += 1})

    model.value = PolicyPullbackModel(2, "b")
    @Expect(model.value.sibling, "a")
    @Expect(model.revision, UInt64(0))
    @Expect(probe.notifications, Int64(0))

    model.value = PolicyPullbackModel(3, "c")
    @Expect(model.value.count, Int64(3))
    @Expect(model.value.sibling, "c")
    @Expect(model.revision, UInt64(1))
    @Expect(probe.notifications, Int64(1))
    observation.close()
}

@Test
func policyPullbackCompositionMatchesComposedProjectionAndPropagatesFailure(): Unit {
    let structural = structuralEqualityPolicy<Int64>()
    let composed = structural.pullback<?PolicyPullbackModel>({value => value.getOrThrow().count})
    let factored = structural.pullback<PolicyPullbackModel>({model => model.count})
        .pullback<?PolicyPullbackModel>({value => value.getOrThrow()})
    let first = Some(PolicyPullbackModel(4, "a"))
    let sameClass = Some(PolicyPullbackModel(4, "b"))
    let otherClass = Some(PolicyPullbackModel(5, "a"))
    @Expect(composed.equivalent(first, sameClass), factored.equivalent(first, sameClass))
    @Expect(composed.equivalent(first, otherClass), factored.equivalent(first, otherClass))

    let probe = PolicyPullbackProbe()
    let throwing = stateMutationPolicy<Int64>({_, _ =>
        probe.calls += 1
        throw IllegalStateException("expected pulled-back policy failure")
    })
    let nested = throwing.pullback<PolicyPullbackModel>({model => model.count})
        .pullback<?PolicyPullbackModel>({value => value.getOrThrow()})
    var didThrow = false

    try {
        nested.equivalent(Some(PolicyPullbackModel(1, "a")), Some(PolicyPullbackModel(1, "b")))
    } catch (_: IllegalStateException) {
        didThrow = true
    }

    @Expect(didThrow)
    @Expect(probe.calls, Int64(1))
}
