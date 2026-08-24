package cui.core

@Test
func stateTracksRevisionAndCancellableObservers(): Unit {
    let state = State<Int64>(2)
    let observedTotal = State<Int64>(0)
    let observation = state.observe({previous, current => observedTotal.value += previous + current})

    state.update({value => value + 3})

    @Expect(state.value, Int64(5))
    @Expect(state.revision, UInt64(1))
    @Expect(observedTotal.value, Int64(7))

    observation.close()
    state.value = 9
    @Expect(observedTotal.value, Int64(7))
    @Expect(observation.isClosed())
}

@Test
func stateStoreSupportsDirectRememberUntilClear(): Unit {
    let store = StateStore()
    let first = store.remember<Int64>("direct") {3}
    first.value = 8
    let second = store.remember<Int64>("direct") {99}

    @Expect(refEq((first as Object).getOrThrow(), (second as Object).getOrThrow())) // cjcheck-ignore: unchecked-cast # test asserts public StateStore identity
    @Expect(second.value, Int64(8))

    store.clear()
    let remounted = store.remember<Int64>("direct") {5}
    @Expect(!refEq((first as Object).getOrThrow(), (remounted as Object).getOrThrow())) // cjcheck-ignore: unchecked-cast # test asserts clear removes public StateStore identity
    @Expect(remounted.value, Int64(5))
}

@Test
func rememberedStateSurvivesRebuildAndResetsAfterUnmount(): Unit {
    let store = StateStore()
    let captured = State<?State<Int64>>(None)

    let _ = buildRoot(
        {
            =>
                let local = rememberState<Int64>("count") {1}
                captured.value = Some(local)
                Spacer()
        },
        store
    )
    let first = captured.value.getOrThrow()
    first.value = 42

    let _ = buildRoot(
        {
            =>
                captured.value = Some(rememberState<Int64>("count") {1})
                Spacer()
        },
        store
    )
    let second = captured.value.getOrThrow()
    // A failed cast should fail the test loudly, so getOrThrow is the intended behaviour.
    @Expect(refEq((first as Object).getOrThrow(), (second as Object).getOrThrow())) // cjcheck-ignore: unchecked-cast # test asserts identity; a cast failure must fail the test
    @Expect(second.value, Int64(42))

    let _ = buildRoot({=> Spacer()}, store)
    let _ = buildRoot(
        {
            =>
                captured.value = Some(rememberState<Int64>("count") {7})
                Spacer()
        },
        store
    )
    let third = captured.value.getOrThrow()
    @Expect(!refEq((first as Object).getOrThrow(), (third as Object).getOrThrow())) // cjcheck-ignore: unchecked-cast # test asserts identity; a cast failure must fail the test
    @Expect(third.value, Int64(7))
}

@Test
func keyedScopesIsolateRepeatedLocalStateNames(): Unit {
    let store = StateStore()
    let first = State<?State<Int64>>(None)
    let second = State<?State<Int64>>(None)

    let _ = buildRoot({
        => VStack {
            Keyed("first") {
                first.value = Some(rememberState<Int64>("selected") {1})
                Spacer()
            }
            Keyed("second") {
                second.value = Some(rememberState<Int64>("selected") {2})
                Spacer()
            }
        }
    }, store)

    @Expect(first.value.getOrThrow().value, Int64(1))
    @Expect(second.value.getOrThrow().value, Int64(2))
}

@Test
func duplicateRememberedStateKeyFailsFast(): Unit {
    let store = StateStore()
    var didThrow = false

    try {
        let _ = buildRoot(
            {
                =>
                    let _ = rememberState<Int64>("duplicate") {1}
                    let _ = rememberState<Int64>("duplicate") {2}
                    Spacer()
            },
            store
        )
    } catch (_: IllegalStateException) {
        didThrow = true
    }

    @Expect(didThrow)
}

@Test
func forEachKeyedStateFollowsItemAcrossReorder(): Unit {
    let store = StateStore()
    let first = State<?State<Int64>>(None)
    let second = State<?State<Int64>>(None)
    let build = {
        items: Array<String> => let _ = buildRoot({
            => VStack {
                ForEach(items, key: {item => item}) {
                    item =>
                        let local = rememberState<Int64>("count") {0}
                        if (item == "a") {
                            first.value = Some(local)
                        } else {
                            second.value = Some(local)
                        }
                        Spacer()
                }
            }
        }, store)
    }

    build(["a", "b"])
    first.value.getOrThrow().value = 11
    second.value.getOrThrow().value = 22

    // After a reorder each item still sees its own state, keyed by identity not position.
    build(["b", "a"])
    @Expect(first.value.getOrThrow().value, Int64(11))
    @Expect(second.value.getOrThrow().value, Int64(22))
}

// `.enabled(false)` takes a control out of Tab traversal for the frame: a stop that ignores
// Enter/Space would be a dead end. Re-enabling (or `.enabled(true)`) keeps the stop.
