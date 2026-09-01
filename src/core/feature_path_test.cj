package cui.core

private class PathLeafModel {
    let count: Int64

    init(count: Int64) {
        this.count = count
    }
}

private class PathFeatureModel {
    let leaf: PathLeafModel
    let label: String

    init(leaf: PathLeafModel, label: String) {
        this.leaf = leaf
        this.label = label
    }
}

private class PathRootModel {
    let feature: PathFeatureModel
    let sibling: String

    init(feature: PathFeatureModel, sibling: String) {
        this.feature = feature
        this.sibling = sibling
    }
}

private class PathFeatureAction {
    let leaf: ?Int64
    let rename: ?String

    init(leaf!: ?Int64 = None, rename!: ?String = None) {
        this.leaf = leaf
        this.rename = rename
    }
}

private class PathRootAction {
    let feature: ?PathFeatureAction
    let sibling: ?String

    init(feature!: ?PathFeatureAction = None, sibling!: ?String = None) {
        this.feature = feature
        this.sibling = sibling
    }
}

private func pathRootFeature(): FeaturePath<PathRootModel, PathRootAction, PathFeatureModel, PathFeatureAction> {
    FeaturePath<PathRootModel, PathRootAction, PathFeatureModel, PathFeatureAction>(
        state: Lens<PathRootModel, PathFeatureModel>(
            get: {root => root.feature},
            set: {root, feature => PathRootModel(feature, root.sibling)}
        ),
        action: Prism<PathRootAction, PathFeatureAction>(
            extract: {action => action.feature},
            embed: {action => PathRootAction(feature: Some(action))}
        )
    )
}

private func pathFeatureLeaf(): FeaturePath<PathFeatureModel, PathFeatureAction, PathLeafModel, Int64> {
    FeaturePath<PathFeatureModel, PathFeatureAction, PathLeafModel, Int64>(
        state: Lens<PathFeatureModel, PathLeafModel>(
            get: {feature => feature.leaf},
            set: {feature, leaf => PathFeatureModel(leaf, feature.label)}
        ),
        action: Prism<PathFeatureAction, Int64>(
            extract: {action => action.leaf},
            embed: {amount => PathFeatureAction(leaf: Some(amount))}
        )
    )
}

private func pathInitialModel(): PathRootModel {
    PathRootModel(PathFeatureModel(PathLeafModel(2), "feature"), "keep")
}

private func identityIntFeaturePath(): FeaturePath<Int64, Int64, Int64, Int64> {
    FeaturePath<Int64, Int64, Int64, Int64>(
        state: Lens<Int64, Int64>(get: {value => value}, set: {_, value => value}),
        action: Prism<Int64, Int64>(extract: {value => Some(value)}, embed: {value => value})
    )
}

@Test
func prismCompositionObeysEmbedExtractAndRejectsOtherCases(): Unit {
    let prism = pathRootFeature().action.then(pathFeatureLeaf().action)
    let embedded = prism.embed(7)

    @Expect(prism.extract(embedded).getOrThrow(), Int64(7))
    @Expect(prism.extract(PathRootAction(sibling: Some("other"))).isNone())
    @Expect(prism.extract(PathRootAction(feature: Some(PathFeatureAction(rename: Some("renamed"))))).isNone())
}

@Test
func featurePathCompositionKeepsStateAndActionBoundariesAligned(): Unit {
    let path = pathRootFeature().then(pathFeatureLeaf())
    let original = pathInitialModel()
    let changed = path.state.set(original, PathLeafModel(9))
    let embedded = path.action.embed(4)

    @Expect(path.state.get(original).count, Int64(2))
    @Expect(path.state.get(changed).count, Int64(9))
    @Expect(changed.feature.label, "feature")
    @Expect(changed.sibling, "keep")
    @Expect(path.action.extract(embedded).getOrThrow(), Int64(4))
}

@Test
func featurePathCompositionIsAssociativeOnBothOptics(): Unit {
    let first = identityIntFeaturePath()
    let second = identityIntFeaturePath()
    let third = identityIntFeaturePath()
    let left = first.then(second).then(third)
    let right = first.then(second.then(third))

    @Expect(left.state.get(7), right.state.get(7))
    @Expect(left.state.set(7, 11), right.state.set(7, 11))
    @Expect(left.action.extract(13).getOrThrow(), right.action.extract(13).getOrThrow())
    @Expect(left.action.embed(17), right.action.embed(17))
}

@Test
func oneFeaturePathDrivesReducerAndStoreScoping(): Unit {
    let path = pathRootFeature().then(pathFeatureLeaf())
    let leafReducer = Reducer<PathLeafModel, Int64>(
        {model, amount => PathLeafModel(model.count + amount)}
    )
    let rootReducer = leafReducer.pullback<PathRootModel, PathRootAction>(path)
    let reduced = rootReducer.reduce(pathInitialModel(), path.action.embed(3))

    @Expect(reduced.feature.leaf.count, Int64(5))
    @Expect(reduced.feature.label, "feature")
    @Expect(reduced.sibling, "keep")

    let unmatched = rootReducer.reduce(reduced, PathRootAction(sibling: Some("ignored")))
    @Expect(unmatched.feature.leaf.count, Int64(5))
    @Expect(unmatched.sibling, "keep")

    let root = ModelStore<PathRootModel, PathRootAction>(pathInitialModel(), rootReducer)
    let leaf = root.scope<PathLeafModel, Int64>(path)
    leaf.dispatchAll([2, 4])

    @Expect(leaf.get().count, Int64(8))
    @Expect(root.get().feature.leaf.count, Int64(8))
    @Expect(root.get().sibling, "keep")
    @Expect(root.revision, UInt64(1))
}

@Test
func featurePathPolicyScopesWorkAtRootAndNestedBoundaries(): Unit {
    let path = pathRootFeature().then(pathFeatureLeaf())
    let leafReducer = Reducer<PathLeafModel, Int64>(
        {model, amount => PathLeafModel(model.count + amount)}
    )
    let policy = stateMutationPolicy<PathLeafModel>({left, right => left.count == right.count})

    let directRoot = ModelStore<PathRootModel, PathRootAction>(
        pathInitialModel(),
        leafReducer.pullback<PathRootModel, PathRootAction>(path)
    )
    let directLeaf = directRoot.scope<PathLeafModel, Int64>(path, policy: policy)
    directLeaf.dispatch(3)

    @Expect(directLeaf.get().count, Int64(5))

    let nestedRoot = ModelStore<PathRootModel, PathRootAction>(
        pathInitialModel(),
        leafReducer.pullback<PathRootModel, PathRootAction>(path)
    )
    let feature = nestedRoot.scope<PathFeatureModel, PathFeatureAction>(pathRootFeature())
    let nestedLeaf = feature.scope<PathLeafModel, Int64>(pathFeatureLeaf(), policy: policy)
    nestedLeaf.dispatch(4)

    @Expect(nestedLeaf.get().count, Int64(6))
    @Expect(nestedRoot.get().feature.leaf.count, Int64(6))
    @Expect(nestedRoot.revision, UInt64(1))
}

@Test
func featurePathEffectPullbackMapsOnlyMatchedEffects(): Unit {
    let path = pathRootFeature().then(pathFeatureLeaf())
    let leafReducer = EffectReducer<PathLeafModel, Int64, String>(
        {
            model, amount => Transition<PathLeafModel, String>(
                PathLeafModel(model.count + amount),
                effect: "leaf:${amount}"
            )
        }
    )
    let rootReducer = leafReducer.pullback<PathRootModel, PathRootAction, String>(
        path,
        effect: {effect => "root/${effect}"}
    )
    let matched = rootReducer.reduce(pathInitialModel(), path.action.embed(3))
    let unmatched = rootReducer.reduce(matched.model, PathRootAction(sibling: Some("ignored")))

    @Expect(matched.model.feature.leaf.count, Int64(5))
    @Expect(matched.effects.toArray()[0], "root/leaf:3")
    @Expect(unmatched.model.feature.leaf.count, Int64(5))
    @Expect(unmatched.effects.isEmpty())
}
