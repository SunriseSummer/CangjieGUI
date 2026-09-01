package cui.core

private class ReducerConcatProbe {
    var calls: Int64 = 0
    var last: Int64 = -1
}

@Test
func reducerConcatPreservesIdentityOrderAndSingleReuse(): Unit {
    let probe = ReducerConcatProbe()
    let reducers = Array<Reducer<Int64, Int64>>(16, {index => Reducer<Int64, Int64>({model, _ =>
        @Expect(index, probe.last + 1)
        probe.last = index
        probe.calls += 1
        model + 1
    })})
    let single = reducers[0]

    @Expect(Reducer<Int64, Int64>.concat([]).reduce(7, 0), Int64(7))
    @Expect(refEq((single as Object).getOrThrow(), (Reducer<Int64, Int64>.concat([single]) as Object).getOrThrow())) // cjcheck-ignore: unchecked-cast # a singleton product reuses its reducer
    @Expect(Reducer<Int64, Int64>.concat(reducers).reduce(0, 0), Int64(16))
    @Expect(probe.calls, Int64(16))
}

@Test
func reducerConcatStopsAtFirstFailureAcrossBalancedBranches(): Unit {
    let probe = ReducerConcatProbe()
    let reducers = Array<Reducer<Int64, Int64>>(16, {index => Reducer<Int64, Int64>({model, _ =>
        probe.calls += 1
        probe.last = index
        if (index == 5) {
            throw IllegalStateException("expected reducer concat failure")
        }
        model + 1
    })})
    var didThrow = false

    try {
        Reducer<Int64, Int64>.concat(reducers).reduce(0, 0)
    } catch (_: IllegalStateException) {
        didThrow = true
    }

    @Expect(didThrow)
    @Expect(probe.calls, Int64(6))
    @Expect(probe.last, Int64(5))
}

@Test
func effectReducerConcatPreservesModelAndEffectOrderAtDepth(): Unit {
    let reducers = Array<EffectReducer<Int64, Int64, Int64>>(1024, {index =>
        EffectReducer<Int64, Int64, Int64>({model, _ =>
            Transition<Int64, Int64>(model + 1, effects: EffectBatch<Int64>(index))
        })
    })
    let empty = EffectReducer<Int64, Int64, Int64>.concat([]).reduce(9, 0)
    let result = EffectReducer<Int64, Int64, Int64>.concat(reducers).reduce(0, 0)
    let effects = result.effects.toArray()

    @Expect(empty.model, Int64(9))
    @Expect(empty.effects.isEmpty())
    @Expect(result.model, Int64(1024))
    @Expect(effects.size, Int64(1024))
    @Expect(effects[0], Int64(0))
    @Expect(effects[511], Int64(511))
    @Expect(effects[1023], Int64(1023))
}
