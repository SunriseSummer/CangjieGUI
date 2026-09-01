package cui.core

private class SparseEffectFoldProbe {
    var handlerCalls: Int64 = 0
    var effectCount: Int64 = -1
}

@Test
func effectStoreEffectFreeBatchCommitsOnceAndHandsOffTheEmptyIdentity(): Unit {
    let reducer = EffectReducer<Int64, Int64, String>(
        {model, action => Transition<Int64, String>(model + action)})
    let store = EffectStore<Int64, Int64, String>(0, reducer)
    let probe = SparseEffectFoldProbe()

    store.dispatchAll(
        Array<Int64>(32, repeat: Int64(1)),
        handleEffects: {
            effects =>
                probe.handlerCalls += 1
                probe.effectCount = effects.size
        }
    )

    @Expect(store.get(), Int64(32))
    @Expect(store.revision, UInt64(1))
    @Expect(probe.handlerCalls, Int64(1))
    @Expect(probe.effectCount, Int64(0))
}
