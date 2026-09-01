package cui.core

private class EntityReducerChild {
    let id: Int64
    let count: Int64

    init(id: Int64, count: Int64) {
        this.id = id
        this.count = count
    }
}

private class EntityReducerParent {
    let entities: EntityTable<Int64, EntityReducerChild>
    let lastCount: Int64

    init(entities: EntityTable<Int64, EntityReducerChild>, lastCount: Int64) {
        this.entities = entities
        this.lastCount = lastCount
    }
}

private class EntityReducerAction {
    let child: ?IdentifiedAction<Int64, Int64>
    let children: ?Array<IdentifiedAction<Int64, Int64>>
    let remove: Bool

    init(
        child!: ?IdentifiedAction<Int64, Int64> = None,
        children!: ?Array<IdentifiedAction<Int64, Int64>> = None,
        remove!: Bool = false
    ) {
        this.child = child
        this.children = children
        this.remove = remove
    }
}

private class EntityReducerProbe {
    var didThrow = false
    var parentRuns: Int64 = 0
}

private func entityReducerChildren(): EntityTable<Int64, EntityReducerChild> {
    EntityTable<Int64, EntityReducerChild>(
        [EntityReducerChild(10, 1), EntityReducerChild(20, 4)],
        id: {child => child.id}
    )
}

private func entityReducerLens(): Lens<EntityReducerParent, EntityTable<Int64, EntityReducerChild>> {
    Lens<EntityReducerParent, EntityTable<Int64, EntityReducerChild>>(
        get: {parent => parent.entities},
        set: {parent, entities => EntityReducerParent(entities, parent.lastCount)}
    )
}

private func entityReducerActionPrism(): Prism<EntityReducerAction, IdentifiedAction<Int64, Int64>> {
    Prism<EntityReducerAction, IdentifiedAction<Int64, Int64>>(
        extract: {action => action.child},
        embed: {action => EntityReducerAction(child: Some(action))}
    )
}

private func entityReducerBatchActionPrism(): Prism<EntityReducerAction, Array<IdentifiedAction<Int64, Int64>>> {
    Prism<EntityReducerAction, Array<IdentifiedAction<Int64, Int64>>>(
        extract: {action => action.children},
        embed: {actions => EntityReducerAction(children: Some(actions))}
    )
}

private func entityReducerBatchActions(): Array<IdentifiedAction<Int64, Int64>> {
    Array<IdentifiedAction<Int64, Int64>>(10, {
        index => IdentifiedAction<Int64, Int64>(20, if (index == 0) {
            3
        } else if (index == 1) {
            -2
        } else {
            0
        })
    })
}

private func entityReducerNextChild(child: EntityReducerChild, action: Int64): EntityReducerChild {
    if (action < 0) {
        EntityReducerChild(child.id, child.count * -action)
    } else {
        EntityReducerChild(child.id, child.count + action)
    }
}

private func entityReducerChildReducer(): Reducer<EntityReducerChild, Int64> {
    Reducer<EntityReducerChild, Int64>({child, action => entityReducerNextChild(child, action)})
}

@Test
func entityReducerTargetsOneEntityAndMakesMissingPolicyExplicit(): Unit {
    let probe = EntityReducerProbe()
    let reducer = entityReducer<Int64, EntityReducerChild, Int64>(entityReducerChildReducer())
    let changed = reducer.reduce(entityReducerChildren(), IdentifiedAction<Int64, Int64>(20, 3))

    @Expect(changed.get(10).getOrThrow().count, Int64(1))
    @Expect(changed.get(20).getOrThrow().count, Int64(7))
    try {
        let _ = reducer.reduce(changed, IdentifiedAction<Int64, Int64>(99, 1))
    } catch (_: IllegalStateException) {
        probe.didThrow = true
    }
    @Expect(probe.didThrow)

    let ignore = entityReducer<Int64, EntityReducerChild, Int64>(
        entityReducerChildReducer(),
        missing: MissingFeaturePolicy.Ignore
    )
    @Expect(ignore.reduce(changed, IdentifiedAction<Int64, Int64>(99, 1)).size, Int64(2))
}

@Test
func forEntityRunsChildBeforeParentRemoval(): Unit {
    let parent = Reducer<EntityReducerParent, EntityReducerAction>({
        model, action => match (action.child) {
            case Some(target) where action.remove =>
                let finalCount = model.entities.get(target.id).getOrThrow().count
                EntityReducerParent(model.entities.removing(target.id).getOrThrow(), finalCount)
            case _ => model
        }
    })
    let combined = parent.forEntity<Int64, EntityReducerChild, Int64>(
        state: entityReducerLens(),
        action: entityReducerActionPrism(),
        child: entityReducerChildReducer()
    )

    let result = combined.reduce(
        EntityReducerParent(entityReducerChildren(), 0),
        EntityReducerAction(child: Some(IdentifiedAction<Int64, Int64>(20, 3)), remove: true)
    )

    @Expect(result.entities.get(20).isNone())
    @Expect(result.entities.get(10).isSome())
    @Expect(result.lastCount, Int64(7))
}

@Test
func forEntityRejectStopsParentAndIgnoreAllowsStaleRootAction(): Unit {
    let probe = EntityReducerProbe()
    let parent = Reducer<EntityReducerParent, EntityReducerAction>({
        model, _ =>
            probe.parentRuns += 1
            EntityReducerParent(model.entities, model.lastCount + 1)
    })
    let reject = parent.forEntity<Int64, EntityReducerChild, Int64>(
        state: entityReducerLens(),
        action: {action => action.child},
        child: entityReducerChildReducer()
    )
    let stale = EntityReducerAction(child: Some(IdentifiedAction<Int64, Int64>(99, 1)))

    try {
        let _ = reject.reduce(EntityReducerParent(entityReducerChildren(), 0), stale)
    } catch (_: IllegalStateException) {
        probe.didThrow = true
    }
    @Expect(probe.didThrow)
    @Expect(probe.parentRuns, Int64(0))

    let ignore = parent.forEntity<Int64, EntityReducerChild, Int64>(
        state: entityReducerLens(),
        action: entityReducerActionPrism(),
        child: entityReducerChildReducer(),
        missing: MissingFeaturePolicy.Ignore
    )
    let result = ignore.reduce(EntityReducerParent(entityReducerChildren(), 0), stale)

    @Expect(probe.parentRuns, Int64(1))
    @Expect(result.lastCount, Int64(1))
}

@Test
func effectForEntityPreservesChildThenParentEffectOrder(): Unit {
    let child = EffectReducer<EntityReducerChild, Int64, String>({
        model, amount => Transition<EntityReducerChild, String>(
            EntityReducerChild(model.id, model.count + amount),
            effect: "child"
        )
    })
    let parent = EffectReducer<EntityReducerParent, EntityReducerAction, String>({
        model, action => match (action.child) {
            case Some(target) where action.remove => Transition<EntityReducerParent, String>(
                EntityReducerParent(
                    model.entities.removing(target.id).getOrThrow(),
                    model.entities.get(target.id).getOrThrow().count
                ),
                effect: "parent"
            )
            case _ => Transition<EntityReducerParent, String>(model)
        }
    })
    let combined = parent.forEntity<Int64, EntityReducerChild, Int64, String>(
        state: entityReducerLens(),
        action: entityReducerActionPrism(),
        child: child,
        effect: {effect => effect}
    )
    let transition = combined.reduce(
        EntityReducerParent(entityReducerChildren(), 0),
        EntityReducerAction(child: Some(IdentifiedAction<Int64, Int64>(20, 3)), remove: true)
    )
    let effects = transition.effects.toArray()

    @Expect(transition.model.entities.get(20).isNone())
    @Expect(transition.model.lastCount, Int64(7))
    @Expect(effects[0], "child")
    @Expect(effects[1], "parent")
}

@Test
func entityBatchReducerComposesDuplicateIdsInOrderAndKeepsSourceVersion(): Unit {
    let source = entityReducerChildren()
    let reducer = entityBatchReducer<Int64, EntityReducerChild, Int64>(entityReducerChildReducer())
    let changed = reducer.reduce(source, entityReducerBatchActions())

    @Expect(source.get(20).getOrThrow().count, Int64(4))
    @Expect(changed.get(10).getOrThrow().count, Int64(1))
    @Expect(changed.get(20).getOrThrow().count, Int64(14))
}

@Test
func entityBatchReducerMakesRejectAndIgnoreAtomicAndExplicit(): Unit {
    let probe = EntityReducerProbe()
    let source = entityReducerChildren()
    let actions = Array<IdentifiedAction<Int64, Int64>>(10, {
        index => IdentifiedAction<Int64, Int64>(if (index == 9) { 99 } else { 20 }, 1)
    })
    let reject = entityBatchReducer<Int64, EntityReducerChild, Int64>(entityReducerChildReducer())
    try {
        let _ = reject.reduce(source, actions)
    } catch (_: IllegalStateException) {
        probe.didThrow = true
    }

    @Expect(probe.didThrow)
    @Expect(source.get(20).getOrThrow().count, Int64(4))

    let ignore = entityBatchReducer<Int64, EntityReducerChild, Int64>(
        entityReducerChildReducer(),
        missing: MissingFeaturePolicy.Ignore
    )
    let changed = ignore.reduce(source, actions)
    @Expect(changed.get(20).getOrThrow().count, Int64(13))
}

@Test
func forEntitiesRunsCompleteChildBatchBeforeParent(): Unit {
    let parent = Reducer<EntityReducerParent, EntityReducerAction>({
        model, action => match (action.children) {
            case Some(_) => EntityReducerParent(model.entities, model.entities.get(20).getOrThrow().count)
            case None => model
        }
    })
    let combined = parent.forEntities<Int64, EntityReducerChild, Int64>(
        state: entityReducerLens(),
        action: entityReducerBatchActionPrism(),
        child: entityReducerChildReducer()
    )
    let result = combined.reduce(
        EntityReducerParent(entityReducerChildren(), 0),
        EntityReducerAction(children: Some(entityReducerBatchActions()))
    )

    @Expect(result.entities.get(20).getOrThrow().count, Int64(14))
    @Expect(result.lastCount, Int64(14))
}

@Test
func effectForEntitiesPreservesEveryChildEffectBeforeParent(): Unit {
    let child = EffectReducer<EntityReducerChild, Int64, String>({
        model, action => Transition<EntityReducerChild, String>(
            entityReducerNextChild(model, action),
            effect: "child:${action}"
        )
    })
    let parent = EffectReducer<EntityReducerParent, EntityReducerAction, String>({
        model, action => match (action.children) {
            case Some(_) => Transition<EntityReducerParent, String>(
                EntityReducerParent(model.entities, model.entities.get(20).getOrThrow().count),
                effect: "parent"
            )
            case None => Transition<EntityReducerParent, String>(model)
        }
    })
    let combined = parent.forEntities<Int64, EntityReducerChild, Int64, String>(
        state: entityReducerLens(),
        action: entityReducerBatchActionPrism(),
        child: child,
        effect: {effect => effect}
    )
    let transition = combined.reduce(
        EntityReducerParent(entityReducerChildren(), 0),
        EntityReducerAction(children: Some(entityReducerBatchActions()))
    )
    let effects = transition.effects.toArray()

    @Expect(transition.model.lastCount, Int64(14))
    @Expect(effects.size, Int64(11))
    @Expect(effects[0], "child:3")
    @Expect(effects[1], "child:-2")
    @Expect(effects[10], "parent")
}

@Test
func entityBatchEffectReducerRejectsAtomicallyAndIgnoreSkipsMissingEffects(): Unit {
    let probe = EntityReducerProbe()
    let source = entityReducerChildren()
    let child = EffectReducer<EntityReducerChild, Int64, String>({
        model, action => Transition<EntityReducerChild, String>(
            entityReducerNextChild(model, action),
            effect: "child:${action}"
        )
    })
    let actions = Array<IdentifiedAction<Int64, Int64>>(10, {
        index => IdentifiedAction<Int64, Int64>(if (index == 9) { 99 } else { 20 }, 1)
    })
    let reject = entityBatchReducer<Int64, EntityReducerChild, Int64, String>(child)
    try {
        let _ = reject.reduce(source, actions)
    } catch (_: IllegalStateException) {
        probe.didThrow = true
    }

    @Expect(probe.didThrow)
    @Expect(source.get(20).getOrThrow().count, Int64(4))

    let ignore = entityBatchReducer<Int64, EntityReducerChild, Int64, String>(
        child,
        missing: MissingFeaturePolicy.Ignore
    )
    let transition = ignore.reduce(source, actions)
    @Expect(transition.model.get(20).getOrThrow().count, Int64(13))
    @Expect(transition.effects.toArray().size, Int64(9))
}
