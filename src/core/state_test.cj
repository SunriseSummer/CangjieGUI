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

@Test
func keylessRememberedStateUsesStableDisjointSlots(): Unit {
    let store = StateStore()
    let firstCapture = State<?State<Int64>>(None)
    let secondCapture = State<?State<Int64>>(None)
    let explicitCapture = State<?State<Int64>>(None)
    let build = {
        => let _ = buildRoot({
            =>
                firstCapture.value = Some(rememberState<Int64> {1})
                secondCapture.value = Some(rememberState<Int64> {2})
                explicitCapture.value = Some(rememberState<Int64>("0") {3})
                Spacer()
        }, store)
    }

    build()
    let first = firstCapture.value.getOrThrow()
    let second = secondCapture.value.getOrThrow()
    let explicit = explicitCapture.value.getOrThrow()
    first.value = 11
    second.value = 22
    explicit.value = 33

    build()
    @Expect(firstCapture.value.getOrThrow().value, Int64(11))
    @Expect(secondCapture.value.getOrThrow().value, Int64(22))
    @Expect(explicitCapture.value.getOrThrow().value, Int64(33))
    @Expect(!refEq((first as Object).getOrThrow(), (second as Object).getOrThrow())) // cjcheck-ignore: unchecked-cast # distinct positional slots must not alias
    @Expect(!refEq((first as Object).getOrThrow(), (explicit as Object).getOrThrow())) // cjcheck-ignore: unchecked-cast # implicit namespace must be disjoint from user keys
}

@Test
func keylessRememberedStateFollowsForEachKeyAcrossReorder(): Unit {
    let store = StateStore()
    let first = State<?State<Int64>>(None)
    let second = State<?State<Int64>>(None)
    let build = {
        items: Array<String> => let _ = buildRoot({
            => VStack {
                ForEach(items, key: {item => item}) {
                    item =>
                        let local = rememberState<Int64> {0}
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
    build(["b", "a"])

    @Expect(first.value.getOrThrow().value, Int64(11))
    @Expect(second.value.getOrThrow().value, Int64(22))
}

@Test
func keylessRememberedStateRejectsConditionalSlotDriftAndRollsBack(): Unit {
    let store = StateStore()
    let includePrefix = State<Bool>(true)
    let stableCapture = State<?State<Int64>>(None)
    let build = {
        => let _ = buildRoot({
            =>
                if (includePrefix.value) {
                    let _ = rememberState<Int64> {1}
                }
                stableCapture.value = Some(rememberState<Int64> {7})
                Spacer()
        }, store)
    }

    build()
    stableCapture.value.getOrThrow().value = 41
    includePrefix.value = false
    var didThrow = false
    try {
        build()
    } catch (_: IllegalStateException) {
        didThrow = true
    }
    @Expect(didThrow)

    includePrefix.value = true
    build()
    @Expect(stableCapture.value.getOrThrow().value, Int64(41))
}

@Test
func keylessRememberedStateAllowsWholeKeyedScopeUnmount(): Unit {
    let store = StateStore()
    let show = State<Bool>(true)
    let captured = State<?State<Int64>>(None)
    let build = {
        => let _ = buildRoot({
            => VStack {
                if (show.value) {
                    Keyed("panel") {
                        captured.value = Some(rememberState<Int64> {3})
                        Spacer()
                    }
                }
            }
        }, store)
    }

    build()
    let first = captured.value.getOrThrow()
    first.value = 9
    show.value = false
    build()
    show.value = true
    build()
    let remounted = captured.value.getOrThrow()

    @Expect(remounted.value, Int64(3))
    @Expect(!refEq((first as Object).getOrThrow(), (remounted as Object).getOrThrow())) // cjcheck-ignore: unchecked-cast # unmounted Keyed state must receive fresh identity
}

@Test
func keylessRememberedStateInsertionRollsBackAfterBuildFailure(): Unit {
    let store = StateStore()
    let initializations = State<Int64>(0)
    var didThrow = false
    try {
        let _ = buildRoot({
            =>
                let _ = rememberState<Int64> {
                    initializations.value += 1
                    5
                }
                throw IllegalStateException("expected keyless build failure")
        }, store)
    } catch (_: IllegalStateException) {
        didThrow = true
    }
    @Expect(didThrow)

    let captured = State<?State<Int64>>(None)
    let _ = buildRoot({
        =>
            captured.value = Some(rememberState<Int64> {
                initializations.value += 1
                7
            })
            Spacer()
    }, store)

    @Expect(initializations.value, Int64(2))
    @Expect(captured.value.getOrThrow().value, Int64(7))
}

// A callback that cancels observations and registers a new one DURING a notification must not
// corrupt the walk: cancelled listeners are skipped, and a listener added mid-notification first
// sees the NEXT assignment.
@Test
func stateNotifySurvivesReentrantObserveAndClose(): Unit {
    let state = State<Int64>(0)
    let log = State<String>("")
    let second = State<?StateObservation<Int64>>(None)
    let third = State<?StateObservation<Int64>>(None)
    let _ = state.observe(
        {
            _, current =>
                log.value = log.value + "a${current};"
                match (second.value) {
                    case Some(observation) => observation.close()
                    case None => ()
                }
                match (third.value) {
                    case Some(observation) => observation.close()
                    case None => ()
                }
                let _ = state.observe({_, c => log.value = log.value + "n${c};"})
        }
    )
    second.value = Some(state.observe({_, current => log.value = log.value + "b${current};"}))
    third.value = Some(state.observe({_, current => log.value = log.value + "c${current};"}))

    // The callback cancels b/c mid-walk and registers n: no crash, no b/c call, no n call yet.
    state.value = 1
    @Expect(log.value, "a1;")

    // The next assignment reaches the survivors: the original listener plus the added one.
    state.value = 2
    @Expect(log.value, "a1;a2;n2;")
}

@Test
func stateNotifyNestedWriteUsesCurrentListenersWithoutChangingOuterWindow(): Unit {
    let state = State<Int64>(0)
    let log = State<String>("")
    let nested = State<Bool>(false)
    let second = State<?StateObservation<Int64>>(None)
    let _ = state.observe(
        {
            previous, current =>
                log.value = log.value + "a${previous}>${current};"
                if (!nested.value) {
                    nested.value = true
                    match (second.value) {
                        case Some(observation) => observation.close()
                        case None => ()
                    }
                    let _ = state.observe({p, c => log.value = log.value + "n${p}>${c};"})
                    state.value = 2
                }
        }
    )
    second.value = Some(state.observe({previous, current => log.value = log.value + "b${previous}>${current};"}))

    state.value = 1
    @Expect(log.value, "a0>1;a1>2;n1>2;")

    state.value = 3
    @Expect(log.value, "a0>1;a1>2;n1>2;a2>3;n2>3;")
}

@Test
func stateNotifyCompactsCancelledListenersWhenCallbackThrows(): Unit {
    let state = State<Int64>(0)
    let log = State<String>("")
    let throwNext = State<Bool>(true)
    let second = State<?StateObservation<Int64>>(None)
    let first = state.observe(
        {
            _, current =>
                log.value = log.value + "a${current};"
                if (throwNext.value) {
                    throwNext.value = false
                    match (second.value) {
                        case Some(observation) => observation.close()
                        case None => ()
                    }
                    throw IllegalStateException("expected observer failure")
                }
        }
    )
    second.value = Some(state.observe({_, current => log.value = log.value + "b${current};"}))

    var didThrow = false
    try {
        state.value = 1
    } catch (_: IllegalStateException) {
        didThrow = true
    }
    @Expect(didThrow)
    @Expect(state.listenerSlotCount(), Int64(1))

    let third = state.observe({_, current => log.value = log.value + "c${current};"})
    state.value = 2
    @Expect(log.value, "a1;a2;c2;")

    first.close()
    third.close()
    @Expect(state.listenerSlotCount(), Int64(0))
}

@Test
func throwingStateObserverCannotBlockLaterDependencyInvalidation(): Unit {
    let source = State<Int64>(0)
    let _ = source.observe({_, _ => throw IllegalStateException("expected business observer failure")})
    let invalidations = ValueCell<Int64>(0)
    let dependencies = PhaseStateDependencies({=> invalidations.value += 1})
    let _ = collectPhaseStateReads<Int64>(dependencies, {=> source.value})

    var didThrow = false
    try {
        source.value = 1
    } catch (_: IllegalStateException) {
        didThrow = true
    }

    @Expect(didThrow)
    @Expect(invalidations.value, Int64(1))
    dependencies.close()
}

// `.enabled(false)` takes a control out of Tab traversal for the frame: a stop that ignores
// Enter/Space would be a dead end. Re-enabling (or `.enabled(true)`) keeps the stop.
