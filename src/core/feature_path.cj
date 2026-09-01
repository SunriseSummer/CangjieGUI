package cui.core

/**
 * A composable optic for one case of a sum type. A lawful Prism satisfies
 * `extract(embed(value)) == Some(value)`; custom Prisms should also preserve a matched case when it
 * is embedded again. Unlike a Lens, extraction can fail when the source is a different case.
 */
public struct Prism<S, A> {
    private let extractValue: (S) -> ?A
    private let embedValue: (A) -> S

    public init(extract!: (S) -> ?A, embed!: (A) -> S) {
        extractValue = extract
        embedValue = embed
    }

    /** Extracts the focused case payload, or None when `source` is another case. */
    public func extract(source: S): ?A {
        extractValue(source)
    }

    /** Embeds one focused payload into the surrounding sum type. */
    public func embed(value: A): S {
        embedValue(value)
    }

    /* Captures the route once when reducers are assembled, avoiding a forwarding layer. */
    func extractor(): (S) -> ?A {
        extractValue
    }

    /* Captures the embedding once when stores are scoped, avoiding a forwarding layer. */
    func embedder(): (A) -> S {
        embedValue
    }

    /** Composes this Prism with a nested case Prism. */
    public func then<B>(next: Prism<A, B>): Prism<S, B> {
        let nextExtract = next.extractor()
        let nextEmbed = next.embedder()
        Prism<S, B>(
            extract: {
                source => match (extractValue(source)) {
                    case Some(value) => nextExtract(value)
                    case None => None
                }
            },
            embed: {value => embedValue(nextEmbed(value))}
        )
    }
}

/**
 * One reusable feature boundary: a total state Lens paired with the corresponding Action Prism.
 * Reducers use both directions of the boundary, while stores use the state projection and Action
 * embedding. Keeping them together prevents reducer and view scopes from silently routing different
 * cases. FeaturePath composition inherits the identity and associativity laws of its two optics.
 */
public struct FeaturePath<RootModel, RootAction, Model, Action> {
    /** Total projection from root state to feature state. */
    public let state: Lens<RootModel, Model>

    /** Partial projection and total embedding for the feature Action case. */
    public let action: Prism<RootAction, Action>

    public init(state!: Lens<RootModel, Model>, action!: Prism<RootAction, Action>) {
        this.state = state
        this.action = action
    }

    /** Composes this boundary with one nested feature boundary. */
    public func then<ChildModel, ChildAction>(next: FeaturePath<Model, Action, ChildModel, ChildAction>): FeaturePath<RootModel,
        RootAction, ChildModel, ChildAction> {
        FeaturePath<RootModel, RootAction, ChildModel, ChildAction>(
            state: state.then(next.state),
            action: action.then(next.action)
        )
    }
}
