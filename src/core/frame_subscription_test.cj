package cui.core

@Test
func stableAutomaticFrameSubscriptionsReuseOneImmutableFragment(): Unit {
    let store = StateStore()
    enableAutomaticComposition(store)
    let body: () -> Unit = {
        => subscribeFrame({_, _ => ()})
        Spacer()
    }

    let _ = buildRoot(body, store)
    let stableCreations = frameSubscriptionSnapshotCreations(store)
    let _ = buildRoot(body, store)
    let _ = buildRoot(body, store)

    @Expect(frameSubscriberCount(store), Int64(1))
    @Expect(frameSubscriptionSnapshotCreations(store), stableCreations)
}

@Test
func dirtyAutomaticBranchRebuildsThenReusesFrameSubscriptionFragment(): Unit {
    let store = StateStore()
    enableAutomaticComposition(store)
    let value = State<Int64>(0)
    let body: () -> Unit = {
        => let _ = value.value
        subscribeFrame({_, _ => ()})
        Spacer()
    }

    let _ = buildRoot(body, store)
    value.value = 1
    let _ = buildRoot(body, store)
    let rebuiltCreations = frameSubscriptionSnapshotCreations(store)
    let _ = buildRoot(body, store)

    @Expect(frameSubscriberCount(store), Int64(1))
    @Expect(frameSubscriptionSnapshotCreations(store), rebuiltCreations)
}
