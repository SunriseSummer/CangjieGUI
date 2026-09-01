package cui.core

private class FeatureChild {
    let id: Int64
    let count: Int64

    init(id: Int64, count: Int64) {
        this.id = id
        this.count = count
    }
}

private class FeatureAction {
    let amount: Int64
    let replacementId: ?Int64

    init(amount: Int64, replacementId!: ?Int64 = None) {
        this.amount = amount
        this.replacementId = replacementId
    }
}

private class OptionalFeatureParent {
    let child: ?FeatureChild
    let lastCount: Int64

    init(child: ?FeatureChild, lastCount: Int64) {
        this.child = child
        this.lastCount = lastCount
    }
}

private class OptionalFeatureAction {
    let child: ?FeatureAction
    let dismiss: Bool

    init(child!: ?FeatureAction = None, dismiss!: Bool = false) {
        this.child = child
        this.dismiss = dismiss
    }
}

private class IdentifiedFeatureParent {
    let children: IdentifiedArray<Int64, FeatureChild>
    let lastCount: Int64

    init(children: IdentifiedArray<Int64, FeatureChild>, lastCount: Int64) {
        this.children = children
        this.lastCount = lastCount
    }
}

private class IdentifiedFeatureRootAction {
    let child: ?IdentifiedAction<Int64, FeatureAction>
    let remove: Bool

    init(
        child!: ?IdentifiedAction<Int64, FeatureAction> = None,
        remove!: Bool = false
    ) {
        this.child = child
        this.remove = remove
    }
}

private class FeatureReducerProbe {
    var didThrow = false
    var parentRuns: Int64 = 0
}

private func featureChildReducer(): Reducer<FeatureChild, FeatureAction> {
    Reducer<FeatureChild, FeatureAction>({
        model, action => FeatureChild(
            match (action.replacementId) {
                case Some(id) => id
                case None => model.id
            },
            model.count + action.amount
        )
    })
}

private func optionalFeatureLens(): Lens<OptionalFeatureParent, ?FeatureChild> {
    Lens<OptionalFeatureParent, ?FeatureChild>(
        get: {model => model.child},
        set: {model, child => OptionalFeatureParent(child, model.lastCount)}
    )
}

private func identifiedFeatureLens(): Lens<IdentifiedFeatureParent, IdentifiedArray<Int64, FeatureChild>> {
    Lens<IdentifiedFeatureParent, IdentifiedArray<Int64, FeatureChild>>(
        get: {model => model.children},
        set: {model, children => IdentifiedFeatureParent(children, model.lastCount)}
    )
}

private func optionalFeatureActionPrism(): Prism<OptionalFeatureAction, FeatureAction> {
    Prism<OptionalFeatureAction, FeatureAction>(
        extract: {action => action.child},
        embed: {action => OptionalFeatureAction(child: Some(action))}
    )
}

private func identifiedFeatureActionPrism(): Prism<IdentifiedFeatureRootAction, IdentifiedAction<Int64, FeatureAction>> {
    Prism<IdentifiedFeatureRootAction, IdentifiedAction<Int64, FeatureAction>>(
        extract: {action => action.child},
        embed: {action => IdentifiedFeatureRootAction(child: Some(action))}
    )
}

private func twoFeatureChildren(): IdentifiedArray<Int64, FeatureChild> {
    IdentifiedArray<Int64, FeatureChild>(
        [FeatureChild(10, 1), FeatureChild(20, 4)],
        id: {child => child.id}
    )
}

@Test
func identifiedArraySnapshotsIndexesAppendsAndRemoves(): Unit {
    let source = [FeatureChild(10, 1), FeatureChild(20, 2)]
    let values = IdentifiedArray<Int64, FeatureChild>(source, id: {child => child.id})
    source[0] = FeatureChild(99, 9)

    @Expect(values.size, Int64(2))
    @Expect(values.at(0).id, Int64(10))
    @Expect(values.get(20).getOrThrow().count, Int64(2))
    @Expect(values.indexOf(20).getOrThrow(), Int64(1))
    @Expect(values.get(99).isNone())

    let appended = values.appending(FeatureChild(30, 3))
    let removed = appended.removing(20).getOrThrow()

    @Expect(values.size, Int64(2))
    @Expect(appended.size, Int64(3))
    @Expect(removed.size, Int64(2))
    @Expect(removed.at(0).id, Int64(10))
    @Expect(removed.at(1).id, Int64(30))
    @Expect(removed.indexOf(30).getOrThrow(), Int64(1))
}

@Test
func identifiedArrayRejectsDuplicateAndMutatedIdentity(): Unit {
    let probe = FeatureReducerProbe()
    try {
        let _ = IdentifiedArray<Int64, FeatureChild>(
            [FeatureChild(1, 0), FeatureChild(1, 2)],
            id: {child => child.id}
        )
    } catch (_: IllegalArgumentException) {
        probe.didThrow = true
    }
    @Expect(probe.didThrow)

    probe.didThrow = false
    let values = twoFeatureChildren()
    try {
        let _ = values.updating(10, {child => FeatureChild(99, child.count)})
    } catch (_: IllegalArgumentException) {
        probe.didThrow = true
    }

    @Expect(probe.didThrow)
    @Expect(values.get(10).getOrThrow().count, Int64(1))
    @Expect(values.get(99).isNone())

    probe.didThrow = false
    try {
        let _ = values.appending(FeatureChild(10, 7))
    } catch (_: IllegalArgumentException) {
        probe.didThrow = true
    }
    @Expect(probe.didThrow)
    @Expect(values.size, Int64(2))
}

@Test
func identifiedArrayPersistentChunksPreserveBoundaryOrderAndOldVersion(): Unit {
    let values = IdentifiedArray<Int64, FeatureChild>(
        Array<FeatureChild>(65, {id => FeatureChild(id, 0)}),
        id: {child => child.id}
    )
    let updated = values.updating(32, {child => FeatureChild(child.id, 7)}).getOrThrow()
    let appended = updated.appending(FeatureChild(65, 9))
    let removed = appended.removing(31).getOrThrow()

    @Expect(values.get(32).getOrThrow().count, Int64(0))
    @Expect(updated.get(32).getOrThrow().count, Int64(7))
    @Expect(updated.at(31).id, Int64(31))
    @Expect(updated.at(32).id, Int64(32))
    @Expect(appended.at(65).id, Int64(65))
    @Expect(removed.size, Int64(65))
    @Expect(removed.at(31).id, Int64(32))
    @Expect(removed.indexOf(65).getOrThrow(), Int64(64))
}

@Test
func optionalReducerMakesMissingStatePolicyExplicit(): Unit {
    let probe = FeatureReducerProbe()
    let reject = optionalReducer(featureChildReducer())
    let changed = reject.reduce(Some(FeatureChild(1, 2)), FeatureAction(3))

    @Expect(changed.getOrThrow().count, Int64(5))
    try {
        let _ = reject.reduce(None, FeatureAction(1))
    } catch (_: IllegalStateException) {
        probe.didThrow = true
    }
    @Expect(probe.didThrow)

    let ignore = optionalReducer(featureChildReducer(), missing: MissingFeaturePolicy.Ignore)
    @Expect(ignore.reduce(None, FeatureAction(1)).isNone())
}

@Test
func ifPresentRunsChildBeforeParentDismissal(): Unit {
    let parent = Reducer<OptionalFeatureParent, OptionalFeatureAction>({
        model, action => if (action.dismiss) {
            OptionalFeatureParent(
                None,
                match (model.child) {
                    case Some(child) => child.count
                    case None => -1
                }
            )
        } else {
            model
        }
    })
    let combined = parent.ifPresent<FeatureChild, FeatureAction>(
        state: optionalFeatureLens(),
        action: optionalFeatureActionPrism(),
        child: featureChildReducer()
    )

    let result = combined.reduce(
        OptionalFeatureParent(Some(FeatureChild(1, 2)), 0),
        OptionalFeatureAction(child: Some(FeatureAction(3)), dismiss: true)
    )

    @Expect(result.child.isNone())
    @Expect(result.lastCount, Int64(5))
}

@Test
func ifPresentRejectStopsParentAndIgnoreLetsParentHandleStaleAction(): Unit {
    let probe = FeatureReducerProbe()
    let parent = Reducer<OptionalFeatureParent, OptionalFeatureAction>({
        model, _ =>
            probe.parentRuns += 1
            OptionalFeatureParent(model.child, model.lastCount + 1)
    })
    let reject = parent.ifPresent<FeatureChild, FeatureAction>(
        state: optionalFeatureLens(),
        action: {action => action.child},
        child: featureChildReducer()
    )
    let staleAction = OptionalFeatureAction(child: Some(FeatureAction(1)))

    try {
        let _ = reject.reduce(OptionalFeatureParent(None, 0), staleAction)
    } catch (_: IllegalStateException) {
        probe.didThrow = true
    }
    @Expect(probe.didThrow)
    @Expect(probe.parentRuns, Int64(0))

    let ignore = parent.ifPresent<FeatureChild, FeatureAction>(
        state: optionalFeatureLens(),
        action: {action => action.child},
        child: featureChildReducer(),
        missing: MissingFeaturePolicy.Ignore
    )
    let ignored = ignore.reduce(OptionalFeatureParent(None, 0), staleAction)

    @Expect(probe.parentRuns, Int64(1))
    @Expect(ignored.child.isNone())
    @Expect(ignored.lastCount, Int64(1))
}

@Test
func identifiedReducerTargetsStableIdAndRejectsMissingByDefault(): Unit {
    let probe = FeatureReducerProbe()
    let reducer = identifiedReducer<Int64, FeatureChild, FeatureAction>(featureChildReducer())
    let changed = reducer.reduce(twoFeatureChildren(), IdentifiedAction<Int64, FeatureAction>(20, FeatureAction(3)))

    @Expect(changed.get(10).getOrThrow().count, Int64(1))
    @Expect(changed.get(20).getOrThrow().count, Int64(7))
    try {
        let _ = reducer.reduce(changed, IdentifiedAction<Int64, FeatureAction>(99, FeatureAction(1)))
    } catch (_: IllegalStateException) {
        probe.didThrow = true
    }
    @Expect(probe.didThrow)

    let ignore = identifiedReducer<Int64, FeatureChild, FeatureAction>(
        featureChildReducer(),
        missing: MissingFeaturePolicy.Ignore
    )
    @Expect(ignore.reduce(changed, IdentifiedAction<Int64, FeatureAction>(99, FeatureAction(1))).size, Int64(2))
}

@Test
func forEachRunsTargetChildBeforeParentRemoval(): Unit {
    let parent = Reducer<IdentifiedFeatureParent, IdentifiedFeatureRootAction>({
        model, action => match (action.child) {
            case Some(target) where action.remove =>
                let updatedCount = model.children.get(target.id).getOrThrow().count
                IdentifiedFeatureParent(model.children.removing(target.id).getOrThrow(), updatedCount)
            case _ => model
        }
    })
    let combined = parent.forEach<Int64, FeatureChild, FeatureAction>(
        state: identifiedFeatureLens(),
        action: identifiedFeatureActionPrism(),
        child: featureChildReducer()
    )

    let result = combined.reduce(
        IdentifiedFeatureParent(twoFeatureChildren(), 0),
        IdentifiedFeatureRootAction(
            child: Some(IdentifiedAction<Int64, FeatureAction>(20, FeatureAction(3))),
            remove: true
        )
    )

    @Expect(result.children.get(20).isNone())
    @Expect(result.children.get(10).isSome())
    @Expect(result.lastCount, Int64(7))
}

@Test
func effectFeatureCompositionPreservesChildThenParentEffectOrder(): Unit {
    let child = EffectReducer<FeatureChild, FeatureAction, String>({
        model, action => Transition<FeatureChild, String>(
            FeatureChild(model.id, model.count + action.amount),
            effect: "child"
        )
    })
    let optionalParent = EffectReducer<OptionalFeatureParent, OptionalFeatureAction, String>({
        model, action => if (action.dismiss) {
            Transition<OptionalFeatureParent, String>(
                OptionalFeatureParent(None, model.child.getOrThrow().count),
                effect: "parent"
            )
        } else {
            Transition<OptionalFeatureParent, String>(model)
        }
    })
    let combined = optionalParent.ifPresent<FeatureChild, FeatureAction, String>(
        state: optionalFeatureLens(),
        action: optionalFeatureActionPrism(),
        child: child,
        effect: {effect => effect}
    )

    let transition = combined.reduce(
        OptionalFeatureParent(Some(FeatureChild(1, 2)), 0),
        OptionalFeatureAction(child: Some(FeatureAction(3)), dismiss: true)
    )
    let effects = transition.effects.toArray()

    @Expect(transition.model.lastCount, Int64(5))
    @Expect(effects.size, Int64(2))
    @Expect(effects[0], "child")
    @Expect(effects[1], "parent")
}

@Test
func effectForEachPreservesIdentityAndEffectOrder(): Unit {
    let child = EffectReducer<FeatureChild, FeatureAction, String>({
        model, action => Transition<FeatureChild, String>(
            FeatureChild(model.id, model.count + action.amount),
            effect: "child"
        )
    })
    let parent = EffectReducer<IdentifiedFeatureParent, IdentifiedFeatureRootAction, String>({
        model, action => match (action.child) {
            case Some(target) where action.remove => Transition<IdentifiedFeatureParent, String>(
                IdentifiedFeatureParent(
                    model.children.removing(target.id).getOrThrow(),
                    model.children.get(target.id).getOrThrow().count
                ),
                effect: "parent"
            )
            case _ => Transition<IdentifiedFeatureParent, String>(model)
        }
    })
    let combined = parent.forEach<Int64, FeatureChild, FeatureAction, String>(
        state: identifiedFeatureLens(),
        action: identifiedFeatureActionPrism(),
        child: child,
        effect: {effect => effect}
    )

    let transition = combined.reduce(
        IdentifiedFeatureParent(twoFeatureChildren(), 0),
        IdentifiedFeatureRootAction(
            child: Some(IdentifiedAction<Int64, FeatureAction>(20, FeatureAction(3))),
            remove: true
        )
    )
    let effects = transition.effects.toArray()

    @Expect(transition.model.children.get(20).isNone())
    @Expect(transition.model.lastCount, Int64(7))
    @Expect(effects[0], "child")
    @Expect(effects[1], "parent")
}
