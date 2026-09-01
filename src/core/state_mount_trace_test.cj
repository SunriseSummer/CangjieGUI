package cui.core

@Test
func unchangedWideBuildDependencyTraceReusesCommittedPrefixWithoutTransientIndex(): Unit {
    let scope = StateMountScope()
    let states = Array<State<Int64>>(16, {index => State<Int64>(index)})
    let first = StateMountBuild(scope, collectStateReads: true, invalidate: {=> ()})
    for (state in states) {
        first.readState(state)
    }
    first.commitStateReads()

    let second = StateMountBuild(scope, collectStateReads: true, invalidate: {=> ()})
    for (state in states) {
        second.readState(state)
    }

    @Expect(!second.usesIndexedDependencySources())
    second.commitStateReads()
    @Expect(scope.buildDependencyCount(), Int64(16))
    for (state in states) {
        @Expect(state.listenerSlotCount(), Int64(1))
    }
    scope.closeBuildDependencies()
}

@Test
func wideBuildDependencyPrefixFallsBackForReorderAndReplacement(): Unit {
    let scope = StateMountScope()
    let states = Array<State<Int64>>(16, {index => State<Int64>(index)})
    let replacement = State<Int64>(99)
    let first = StateMountBuild(scope, collectStateReads: true, invalidate: {=> ()})
    for (state in states) {
        first.readState(state)
    }
    first.commitStateReads()

    let reordered = StateMountBuild(scope, collectStateReads: true, invalidate: {=> ()})
    for (index in 0..8) {
        reordered.readState(states[index])
    }
    reordered.readState(states[9])
    reordered.readState(states[8])
    for (index in 10..16) {
        reordered.readState(states[index])
    }
    @Expect(reordered.usesIndexedDependencySources())
    reordered.commitStateReads()
    for (state in states) {
        @Expect(state.listenerSlotCount(), Int64(1))
    }

    let replaced = StateMountBuild(scope, collectStateReads: true, invalidate: {=> ()})
    for (index in 0..8) {
        replaced.readState(states[index])
    }
    replaced.readState(replacement)
    for (index in 9..16) {
        replaced.readState(states[index])
    }
    replaced.commitStateReads()

    @Expect(scope.buildDependencyCount(), Int64(16))
    @Expect(states[8].listenerSlotCount(), Int64(0))
    @Expect(replacement.listenerSlotCount(), Int64(1))
    for (index in 0..8) {
        @Expect(states[index].listenerSlotCount(), Int64(1))
    }
    for (index in 9..16) {
        @Expect(states[index].listenerSlotCount(), Int64(1))
    }
    scope.closeBuildDependencies()
}
