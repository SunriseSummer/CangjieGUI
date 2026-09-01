package cui.core

private class IdentifiedBatchChild {
    let id: Int64
    let count: Int64

    init(id: Int64, count: Int64) {
        this.id = id
        this.count = count
    }
}

private class IdentifiedBatchAction {
    let amount: Int64
    let replacementId: ?Int64

    init(amount: Int64, replacementId!: ?Int64 = None) {
        this.amount = amount
        this.replacementId = replacementId
    }
}

private class IdentifiedBatchParent {
    let children: IdentifiedArray<Int64, IdentifiedBatchChild>
    let lastCount: Int64

    init(children: IdentifiedArray<Int64, IdentifiedBatchChild>, lastCount: Int64) {
        this.children = children
        this.lastCount = lastCount
    }
}

private class IdentifiedBatchRootAction {
    let children: ?Array<IdentifiedAction<Int64, IdentifiedBatchAction>>

    init(children!: ?Array<IdentifiedAction<Int64, IdentifiedBatchAction>> = None) {
        this.children = children
    }
}

private class IdentifiedBatchProbe {
    var didThrow = false
}

private func identifiedBatchChildReducer(): Reducer<IdentifiedBatchChild, IdentifiedBatchAction> {
    Reducer<IdentifiedBatchChild, IdentifiedBatchAction>({
        model, action => IdentifiedBatchChild(
            match (action.replacementId) {
                case Some(id) => id
                case None => model.id
            },
            if (action.amount < 0) {
                model.count * -action.amount
            } else {
                model.count + action.amount
            }
        )
    })
}

private func identifiedBatchLens(): Lens<IdentifiedBatchParent, IdentifiedArray<Int64, IdentifiedBatchChild>> {
    Lens<IdentifiedBatchParent, IdentifiedArray<Int64, IdentifiedBatchChild>>(
        get: {model => model.children},
        set: {model, children => IdentifiedBatchParent(children, model.lastCount)}
    )
}

private func identifiedBatchActionPrism(): Prism<IdentifiedBatchRootAction, Array<IdentifiedAction<Int64,
    IdentifiedBatchAction>>> {
    Prism<IdentifiedBatchRootAction, Array<IdentifiedAction<Int64, IdentifiedBatchAction>>>(
        extract: {action => action.children},
        embed: {actions => IdentifiedBatchRootAction(children: Some(actions))}
    )
}

private func twoIdentifiedBatchChildren(): IdentifiedArray<Int64, IdentifiedBatchChild> {
    IdentifiedArray<Int64, IdentifiedBatchChild>(
        [IdentifiedBatchChild(10, 1), IdentifiedBatchChild(20, 4)],
        id: {child => child.id}
    )
}

private func orderedIdentifiedBatchActions(): Array<IdentifiedAction<Int64, IdentifiedBatchAction>> {
    Array<IdentifiedAction<Int64, IdentifiedBatchAction>>(10, {
        index => IdentifiedAction<Int64, IdentifiedBatchAction>(20, IdentifiedBatchAction(if (index == 0) {
            3
        } else if (index == 1) {
            -2
        } else {
            0
        }))
    })
}

@Test
func identifiedBatchReducerClonesTouchedChunksOnceAndPreservesOrder(): Unit {
    let source = IdentifiedArray<Int64, IdentifiedBatchChild>(
        Array<IdentifiedBatchChild>(65, {id => IdentifiedBatchChild(id, id)}),
        id: {child => child.id}
    )
    let actions = Array<IdentifiedAction<Int64, IdentifiedBatchAction>>(10, {
        index => if (index == 0) {
            IdentifiedAction<Int64, IdentifiedBatchAction>(31, IdentifiedBatchAction(3))
        } else if (index == 1) {
            IdentifiedAction<Int64, IdentifiedBatchAction>(31, IdentifiedBatchAction(-2))
        } else if (index == 9) {
            IdentifiedAction<Int64, IdentifiedBatchAction>(64, IdentifiedBatchAction(5))
        } else {
            IdentifiedAction<Int64, IdentifiedBatchAction>(32, IdentifiedBatchAction(1))
        }
    })
    let reducer = identifiedBatchReducer<Int64, IdentifiedBatchChild, IdentifiedBatchAction>(
        identifiedBatchChildReducer()
    )
    let changed = reducer.reduce(source, actions)

    @Expect(source.get(31).getOrThrow().count, Int64(31))
    @Expect(source.get(32).getOrThrow().count, Int64(32))
    @Expect(source.get(64).getOrThrow().count, Int64(64))
    @Expect(changed.get(31).getOrThrow().count, Int64(68))
    @Expect(changed.get(32).getOrThrow().count, Int64(39))
    @Expect(changed.get(64).getOrThrow().count, Int64(69))
}

@Test
func identifiedBatchReducerRejectsAtomicallyAndIgnoreSkipsMissing(): Unit {
    let probe = IdentifiedBatchProbe()
    let source = IdentifiedArray<Int64, IdentifiedBatchChild>(
        Array<IdentifiedBatchChild>(65, {id => IdentifiedBatchChild(id, id)}),
        id: {child => child.id}
    )
    let actions = Array<IdentifiedAction<Int64, IdentifiedBatchAction>>(10, {
        index => IdentifiedAction<Int64, IdentifiedBatchAction>(
            if (index == 9) { 99 } else { 32 },
            IdentifiedBatchAction(1)
        )
    })
    let reject = identifiedBatchReducer<Int64, IdentifiedBatchChild, IdentifiedBatchAction>(
        identifiedBatchChildReducer()
    )
    try {
        let _ = reject.reduce(source, actions)
    } catch (_: IllegalStateException) {
        probe.didThrow = true
    }

    @Expect(probe.didThrow)
    @Expect(source.get(32).getOrThrow().count, Int64(32))

    let ignore = identifiedBatchReducer<Int64, IdentifiedBatchChild, IdentifiedBatchAction>(
        identifiedBatchChildReducer(),
        missing: MissingFeaturePolicy.Ignore
    )
    @Expect(ignore.reduce(source, actions).get(32).getOrThrow().count, Int64(41))

    probe.didThrow = false
    let invalidIdentity = Array<IdentifiedAction<Int64, IdentifiedBatchAction>>(10, {
        index => IdentifiedAction<Int64, IdentifiedBatchAction>(32, IdentifiedBatchAction(
            1,
            replacementId: if (index == 9) { Some(Int64(99)) } else { None }
        ))
    })
    try {
        let _ = reject.reduce(source, invalidIdentity)
    } catch (_: IllegalArgumentException) {
        probe.didThrow = true
    }
    @Expect(probe.didThrow)
    @Expect(source.get(32).getOrThrow().count, Int64(32))
}

@Test
func forEachBatchRunsCompleteChildTraversalBeforeParent(): Unit {
    let parent = Reducer<IdentifiedBatchParent, IdentifiedBatchRootAction>({
        model, action => match (action.children) {
            case Some(_) => IdentifiedBatchParent(model.children, model.children.get(20).getOrThrow().count)
            case None => model
        }
    })
    let combined = parent.forEachBatch<Int64, IdentifiedBatchChild, IdentifiedBatchAction>(
        state: identifiedBatchLens(),
        action: identifiedBatchActionPrism(),
        child: identifiedBatchChildReducer()
    )
    let result = combined.reduce(
        IdentifiedBatchParent(twoIdentifiedBatchChildren(), 0),
        IdentifiedBatchRootAction(children: Some(orderedIdentifiedBatchActions()))
    )

    @Expect(result.children.get(20).getOrThrow().count, Int64(14))
    @Expect(result.lastCount, Int64(14))
}

@Test
func effectForEachBatchPreservesChildEffectsBeforeParent(): Unit {
    let pure = identifiedBatchChildReducer()
    let child = EffectReducer<IdentifiedBatchChild, IdentifiedBatchAction, String>({
        model, action => Transition<IdentifiedBatchChild, String>(
            pure.reduce(model, action),
            effect: "child:${action.amount}"
        )
    })
    let parent = EffectReducer<IdentifiedBatchParent, IdentifiedBatchRootAction, String>({
        model, action => match (action.children) {
            case Some(_) => Transition<IdentifiedBatchParent, String>(
                IdentifiedBatchParent(model.children, model.children.get(20).getOrThrow().count),
                effect: "parent"
            )
            case None => Transition<IdentifiedBatchParent, String>(model)
        }
    })
    let combined = parent.forEachBatch<Int64, IdentifiedBatchChild, IdentifiedBatchAction, String>(
        state: identifiedBatchLens(),
        action: identifiedBatchActionPrism(),
        child: child,
        effect: {effect => effect}
    )
    let transition = combined.reduce(
        IdentifiedBatchParent(twoIdentifiedBatchChildren(), 0),
        IdentifiedBatchRootAction(children: Some(orderedIdentifiedBatchActions()))
    )
    let effects = transition.effects.toArray()

    @Expect(transition.model.lastCount, Int64(14))
    @Expect(effects.size, Int64(11))
    @Expect(effects[0], "child:3")
    @Expect(effects[1], "child:-2")
    @Expect(effects[10], "parent")
}

@Test
func identifiedBatchEffectReducerRejectsAtomicallyAndIgnoreSkipsMissingEffects(): Unit {
    let probe = IdentifiedBatchProbe()
    let source = IdentifiedArray<Int64, IdentifiedBatchChild>(
        Array<IdentifiedBatchChild>(65, {id => IdentifiedBatchChild(id, id)}),
        id: {child => child.id}
    )
    let pure = identifiedBatchChildReducer()
    let child = EffectReducer<IdentifiedBatchChild, IdentifiedBatchAction, String>({
        model, action => Transition<IdentifiedBatchChild, String>(
            pure.reduce(model, action),
            effect: "child:${action.amount}"
        )
    })
    let actions = Array<IdentifiedAction<Int64, IdentifiedBatchAction>>(10, {
        index => IdentifiedAction<Int64, IdentifiedBatchAction>(
            if (index == 9) { 99 } else { 32 },
            IdentifiedBatchAction(1)
        )
    })
    let reject = identifiedBatchReducer<Int64, IdentifiedBatchChild, IdentifiedBatchAction, String>(child)
    try {
        let _ = reject.reduce(source, actions)
    } catch (_: IllegalStateException) {
        probe.didThrow = true
    }

    @Expect(probe.didThrow)
    @Expect(source.get(32).getOrThrow().count, Int64(32))

    let ignore = identifiedBatchReducer<Int64, IdentifiedBatchChild, IdentifiedBatchAction, String>(
        child,
        missing: MissingFeaturePolicy.Ignore
    )
    let transition = ignore.reduce(source, actions)
    @Expect(transition.model.get(32).getOrThrow().count, Int64(41))
    @Expect(transition.effects.toArray().size, Int64(9))
}
