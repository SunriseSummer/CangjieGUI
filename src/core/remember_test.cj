package cui.core

private class RememberProbe {
    let value: Int64

    init(value: Int64) {
        this.value = value
    }
}

@Test
func rememberRetainsArbitraryObjectWithoutMutableStateWrapper(): Unit {
    let store = StateStore()
    let initializations = ValueCell<Int64>(0)
    let captured = State<?RememberProbe>(None)
    let build = {
        => let _ = buildRoot({
            =>
                captured.value = Some(remember<RememberProbe> {
                    initializations.value += 1
                    RememberProbe(7)
                })
                Spacer()
        }, store)
    }

    build()
    let first = captured.value.getOrThrow()
    build()
    let second = captured.value.getOrThrow()

    @Expect(initializations.value, Int64(1))
    @Expect(second.value, Int64(7))
    @Expect(refEq((first as Object).getOrThrow(), (second as Object).getOrThrow())) // cjcheck-ignore: unchecked-cast # remembered class values must preserve identity
}

@Test
func rememberRejectsPositionalValueTypeDriftAndRecoversOldValue(): Unit {
    let store = StateStore()
    let useString = State<Bool>(false)
    let captured = State<Int64>(0)
    let build = {
        => let _ = buildRoot({
            =>
                if (useString.value) {
                    let _ = remember<String> {"wrong"}
                } else {
                    captured.value = remember<Int64> {7}
                }
                Spacer()
        }, store)
    }

    build()
    useString.value = true
    var didThrow = false
    try {
        build()
    } catch (_: IllegalStateException) {
        didThrow = true
    }
    @Expect(didThrow)

    useString.value = false
    build()
    @Expect(captured.value, Int64(7))
}

@Test
func rememberedDerivedBecomesOneStableLazyDependencyNode(): Unit {
    let store = StateStore()
    let states = Array<State<Int64>>(16, {index => State<Int64>(index)})
    let creations = ValueCell<Int64>(0)
    let computes = ValueCell<Int64>(0)
    let captured = State<?DerivedState<Int64>>(None)
    let build = {
        => let _ = buildRoot({
            => Keyed("derived") {
                let total = remember<DerivedState<Int64>> {
                    creations.value += 1
                    deriveStates<Int64, Int64>(states, {
                        values =>
                            computes.value += 1
                            var result: Int64 = 0
                            for (value in values) {
                                result += value
                            }
                            result
                    })
                }
                captured.value = Some(total)
                let _ = total.value
                Spacer()
            }
        }, store)
    }

    build()
    let first = captured.value.getOrThrow()
    @Expect(first.value, Int64(120))
    @Expect(creations.value, Int64(1))
    @Expect(computes.value, Int64(1))
    @Expect(store.rootMountScope.buildDependencyCount(), Int64(1))

    build()
    @Expect(refEq((first as Object).getOrThrow(), (captured.value.getOrThrow() as Object).getOrThrow())) // cjcheck-ignore: unchecked-cast # remembered DerivedState identity must survive rebuild
    @Expect(store.rootMountScope.buildDependencyCount(), Int64(1))
    @Expect(computes.value, Int64(1))

    states[15].value = 100
    build()
    @Expect(captured.value.getOrThrow().value, Int64(205))
    @Expect(computes.value, Int64(2))

    let _ = buildRoot({=> Spacer()}, store)
    for (state in states) {
        @Expect(state.listenerSlotCount(), Int64(0))
    }
}

@Test
func rememberFactoryFailureDoesNotCommitPartialValue(): Unit {
    let store = StateStore()
    let attempts = ValueCell<Int64>(0)
    var didThrow = false
    try {
        let _ = buildRoot({
            =>
                let _ = remember<RememberProbe> {
                    attempts.value += 1
                    throw IllegalStateException("expected remember factory failure")
                }
                Spacer()
        }, store)
    } catch (_: IllegalStateException) {
        didThrow = true
    }
    @Expect(didThrow)

    let captured = State<?RememberProbe>(None)
    let _ = buildRoot({
        =>
            captured.value = Some(remember<RememberProbe> {
                attempts.value += 1
                RememberProbe(9)
            })
            Spacer()
    }, store)

    @Expect(attempts.value, Int64(2))
    @Expect(captured.value.getOrThrow().value, Int64(9))
}
