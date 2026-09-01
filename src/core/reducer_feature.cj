package cui.core

/* Batch-local Writer accumulator; the object never escapes a single effect reduction. */
private class ReducerBatchEffectFold<Model, Action, Effect> {
    private let reducer: EffectReducer<Model, Action, Effect>
    var effects = EffectBatch<Effect>()

    init(reducer: EffectReducer<Model, Action, Effect>) {
        this.reducer = reducer
    }

    func reduce(model: Model, action: Action): Model {
        let transition = reducer.reduce(model, action)
        if (!transition.effects.isEmpty()) {
            effects = effects.then(transition.effects)
        }
        transition.model
    }
}

/**
 * Lifts a pure reducer through Option. Reject catches stale child Actions by default; Ignore is the
 * lawful Option-map behavior for intentionally tolerated late results. The returned reducer throws
 * `IllegalStateException` on a missing model only when `missing` is `Reject`.
 */
public func optionalReducer<Model, Action>(
    reducer: Reducer<Model, Action>,
    missing!: MissingFeaturePolicy = MissingFeaturePolicy.Reject
): Reducer<?Model, Action> {
    Reducer<?Model, Action>({
        model, action => match (model) {
            case Some(value) => Some(reducer.reduce(value, action))
            case None =>
                handleMissingFeature(missing, "Optional reducer")
                None
        }
    })
}

/**
 * Lifts a pure reducer over an immutable stable-ID collection. The returned reducer throws
 * `IllegalStateException` on a missing ID only when `missing` is `Reject`.
 */
public func identifiedReducer<ID, Model, Action>(
    reducer: Reducer<Model, Action>,
    missing!: MissingFeaturePolicy = MissingFeaturePolicy.Reject
): Reducer<IdentifiedArray<ID, Model>, IdentifiedAction<ID, Action>> where ID <: Hashable & Equatable<ID> {
    Reducer<IdentifiedArray<ID, Model>, IdentifiedAction<ID, Action>>({
        models, identifiedAction => match (models.indexOf(identifiedAction.id)) {
            case Some(index) => models.replacingAt(
                index,
                identifiedAction.id,
                reducer.reduce(models.at(index), identifiedAction.action)
            )
            case None =>
                handleMissingFeature(missing, "Identified reducer")
                models
        }
    })
}

/**
 * Lifts a pure reducer over one explicit ordered batch of stable-ID child Actions. The complete
 * traversal produces at most one IdentifiedArray version. A missing ID throws
 * `IllegalStateException` only when `missing` is `Reject`; the source version remains unchanged.
 */
public func identifiedBatchReducer<ID, Model, Action>(
    reducer: Reducer<Model, Action>,
    missing!: MissingFeaturePolicy = MissingFeaturePolicy.Reject
): Reducer<IdentifiedArray<ID, Model>, Array<IdentifiedAction<ID, Action>>> where ID <: Hashable & Equatable<ID> {
    Reducer<IdentifiedArray<ID, Model>, Array<IdentifiedAction<ID, Action>>>(
        {
            models, actions =>
                if (actions.size == 1) {
                    let identifiedAction = actions[0]
                    return match (models.indexOf(identifiedAction.id)) {
                        case Some(index) => models.replacingAt(
                            index,
                            identifiedAction.id,
                            reducer.reduce(models.at(index), identifiedAction.action)
                        )
                        case None =>
                            handleMissingFeature(missing, "Identified batch reducer")
                            models
                    }
                }
                models.reducingAll(
                    actions,
                    {model, action => reducer.reduce(model, action)},
                    missing
                )
        }
    )
}

/**
 * Lifts a pure reducer over an immutable normalized entity table. The returned reducer throws
 * `IllegalStateException` on a missing ID only when `missing` is `Reject`.
 */
public func entityReducer<ID, Model, Action>(
    reducer: Reducer<Model, Action>,
    missing!: MissingFeaturePolicy = MissingFeaturePolicy.Reject
): Reducer<EntityTable<ID, Model>, IdentifiedAction<ID, Action>> where ID <: Hashable & Equatable<ID> {
    Reducer<EntityTable<ID, Model>, IdentifiedAction<ID, Action>>({
        models, identifiedAction => match (models.updating(
            identifiedAction.id,
            {model => reducer.reduce(model, identifiedAction.action)}
        )) {
            case Some(next) => next
            case None =>
                handleMissingFeature(missing, "Entity reducer")
                models
        }
    })
}

/**
 * Lifts a pure reducer over one explicit ordered batch of normalized entity Actions. The complete
 * batch produces at most one EntityTable version; duplicate IDs retain Action order. A missing ID
 * throws `IllegalStateException` only when `missing` is `Reject`; the source version remains unchanged.
 */
public func entityBatchReducer<ID, Model, Action>(
    reducer: Reducer<Model, Action>,
    missing!: MissingFeaturePolicy = MissingFeaturePolicy.Reject
): Reducer<EntityTable<ID, Model>, Array<IdentifiedAction<ID, Action>>> where ID <: Hashable & Equatable<ID> {
    Reducer<EntityTable<ID, Model>, Array<IdentifiedAction<ID, Action>>>({
        models, actions => models.reducingAll(
            actions,
            {model, action => reducer.reduce(model, action)},
            missing
        )
    })
}

/**
 * Lifts an effect reducer through Option with explicit stale-Action behavior. The returned reducer
 * throws `IllegalStateException` on a missing model only when `missing` is `Reject`.
 */
public func optionalReducer<Model, Action, Effect>(
    reducer: EffectReducer<Model, Action, Effect>,
    missing!: MissingFeaturePolicy = MissingFeaturePolicy.Reject
): EffectReducer<?Model, Action, Effect> {
    EffectReducer<?Model, Action, Effect>({
        model, action => match (model) {
            case Some(value) =>
                let transition = reducer.reduce(value, action)
                Transition<?Model, Effect>(Some(transition.model), effects: transition.effects)
            case None =>
                handleMissingFeature(missing, "Optional effect reducer")
                Transition<?Model, Effect>(None)
        }
    })
}

/**
 * Lifts an effect reducer over an immutable stable-ID collection. The returned reducer throws
 * `IllegalStateException` on a missing ID only when `missing` is `Reject`.
 */
public func identifiedReducer<ID, Model, Action, Effect>(
    reducer: EffectReducer<Model, Action, Effect>,
    missing!: MissingFeaturePolicy = MissingFeaturePolicy.Reject
): EffectReducer<IdentifiedArray<ID, Model>, IdentifiedAction<ID, Action>, Effect> where ID <: Hashable & Equatable<ID> {
    EffectReducer<IdentifiedArray<ID, Model>, IdentifiedAction<ID, Action>, Effect>({
        models, identifiedAction => match (models.indexOf(identifiedAction.id)) {
            case Some(index) =>
                let transition = reducer.reduce(models.at(index), identifiedAction.action)
                Transition<IdentifiedArray<ID, Model>, Effect>(
                    models.replacingAt(index, identifiedAction.id, transition.model),
                    effects: transition.effects
                )
            case None =>
                handleMissingFeature(missing, "Identified effect reducer")
                Transition<IdentifiedArray<ID, Model>, Effect>(models)
        }
    })
}

/**
 * Lifts an effect reducer over one explicit ordered batch of stable-ID child Actions. Child effects
 * retain traversal order and the model produces at most one IdentifiedArray version. A missing ID
 * throws `IllegalStateException` only when `missing` is `Reject`; no partial model or effects escape.
 */
public func identifiedBatchReducer<ID, Model, Action, Effect>(
    reducer: EffectReducer<Model, Action, Effect>,
    missing!: MissingFeaturePolicy = MissingFeaturePolicy.Reject
): EffectReducer<IdentifiedArray<ID, Model>, Array<IdentifiedAction<ID, Action>>, Effect> where ID <: Hashable & Equatable<ID> {
    EffectReducer<IdentifiedArray<ID, Model>, Array<IdentifiedAction<ID, Action>>, Effect>(
        {
            models, actions =>
                if (actions.size == 1) {
                    let identifiedAction = actions[0]
                    return match (models.indexOf(identifiedAction.id)) {
                        case Some(index) =>
                            let transition = reducer.reduce(models.at(index), identifiedAction.action)
                            Transition<IdentifiedArray<ID, Model>, Effect>(
                                models.replacingAt(index, identifiedAction.id, transition.model),
                                effects: transition.effects
                            )
                        case None =>
                            handleMissingFeature(missing, "Identified batch effect reducer")
                            Transition<IdentifiedArray<ID, Model>, Effect>(models)
                    }
                }
                let fold = ReducerBatchEffectFold<Model, Action, Effect>(reducer)
                let next = models.reducingAll(actions, {model, action => fold.reduce(model, action)}, missing)
                Transition<IdentifiedArray<ID, Model>, Effect>(next, effects: fold.effects)
        }
    )
}

/**
 * Lifts an effect reducer over an immutable normalized entity table. A missing ID throws
 * `IllegalStateException` only when `missing` is `Reject`. The same exception type also reports an
 * internal lookup/update atomicity violation, which cannot be produced by a valid EntityTable.
 */
public func entityReducer<ID, Model, Action, Effect>(
    reducer: EffectReducer<Model, Action, Effect>,
    missing!: MissingFeaturePolicy = MissingFeaturePolicy.Reject
): EffectReducer<EntityTable<ID, Model>, IdentifiedAction<ID, Action>, Effect> where ID <: Hashable & Equatable<ID> {
    EffectReducer<EntityTable<ID, Model>, IdentifiedAction<ID, Action>, Effect>({
        models, identifiedAction => match (models.get(identifiedAction.id)) {
            case Some(model) =>
                let transition = reducer.reduce(model, identifiedAction.action)
                match (models.updating(identifiedAction.id, {_ => transition.model})) {
                    case Some(next) => Transition<EntityTable<ID, Model>, Effect>(next, effects: transition.effects)
                    case None => throw IllegalStateException("EntityTable lost an ID after a successful reducer lookup")
                }
            case None =>
                handleMissingFeature(missing, "Entity effect reducer")
                Transition<EntityTable<ID, Model>, Effect>(models)
        }
    })
}

/**
 * Lifts an effect reducer over one explicit ordered batch of normalized entity Actions. Model
 * updates commit as one table version and inert effects preserve child Action order. A missing ID
 * throws `IllegalStateException` only when `missing` is `Reject`; no partial model or effects escape.
 */
public func entityBatchReducer<ID, Model, Action, Effect>(
    reducer: EffectReducer<Model, Action, Effect>,
    missing!: MissingFeaturePolicy = MissingFeaturePolicy.Reject
): EffectReducer<EntityTable<ID, Model>, Array<IdentifiedAction<ID, Action>>, Effect> where ID <: Hashable & Equatable<ID> {
    EffectReducer<EntityTable<ID, Model>, Array<IdentifiedAction<ID, Action>>, Effect>(
        {
            models, actions =>
                let fold = ReducerBatchEffectFold<Model, Action, Effect>(reducer)
                let next = models.reducingAll(actions, {model, action => fold.reduce(model, action)}, missing)
                Transition<EntityTable<ID, Model>, Effect>(next, effects: fold.effects)
        }
    )
}
