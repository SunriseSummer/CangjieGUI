package cui.core

import sdl.Rect

/* Exactly the three legal temporal states of an Element layout memo. */
enum ElementLayoutState {
    | Absent
    | Stale(ElementLayoutCommit)
    | Current(ElementLayoutCommit)
}

/* Replayable and routable side effects produced by one layout evaluation. */
struct ElementLayoutEffects {
    let overlays: ?OverlaySnapshot
    let semantics: ?SemanticFragment
    let eventTopology: ElementEventTopologyCommit

    init(
        overlays: ?OverlaySnapshot,
        semantics: ?SemanticFragment,
        eventTopology!: ElementEventTopologyCommit = ElementEventTopologyCommit.Preserve
    ) {
        this.overlays = overlays
        this.semantics = semantics
        this.eventTopology = eventTopology
    }
}

/*
 * One immutable layout commit. Geometry and replayable side effects become visible together, so a
 * self-invalidated layout cannot publish half of a transaction into the Element space.
 */
class ElementLayoutCommit {
    let bounds: Rect
    let visibleBounds: Rect
    let declaredPaintBounds: Rect
    private let environment: UiEnvironmentKey
    private let overlays: ?OverlaySnapshot
    private let semantics: ?SemanticFragment
    private let eventTopology: ElementEventTopologyCommit

    init(
        bounds: Rect,
        visibilityClip: ?Rect,
        paintOutset: PaintOutset,
        environment: UiEnvironmentKey,
        effects: ElementLayoutEffects
    ) {
        this.bounds = bounds
        this.visibleBounds = visibleBoundsForLayout(bounds, visibilityClip)
        this.declaredPaintBounds = paintOutset.expand(bounds)
        this.environment = environment
        this.overlays = effects.overlays
        this.semantics = effects.semantics
        this.eventTopology = effects.eventTopology
    }

    func matches(
        bounds: Rect,
        visibleBounds: Rect,
        declaredPaintBounds: Rect,
        environment: UiEnvironmentKey
    ): Bool {
        sameAutomaticRect(this.bounds, bounds) && sameAutomaticRect(this.visibleBounds, visibleBounds) &&
            sameAutomaticRect(this.declaredPaintBounds, declaredPaintBounds) && sameUiEnvironment(this.environment,
            environment)
    }

    func replay(ctx: UiContext): Unit {
        match (overlays) {
            case Some(snapshot) => ctx.registerOverlayFragment(snapshot)
            case None => ()
        }
        match (semantics) {
            case Some(fragment) => ctx.registerSemanticContribution(fragment)
            case None => ()
        }
    }

    func environmentMatches(environment: UiEnvironmentKey): Bool {
        sameUiEnvironment(this.environment, environment)
    }

    func eventTopologyCommit(): ElementEventTopologyCommit {
        eventTopology
    }
}

extend ElementSceneSpace {
    func publishLayout(value: ElementLayoutCommit): Bool {
        ensureAlive("publish layout")
        let geometryChanged = match (lastLayoutCommit()) {
            case Some(previous) => !sameAutomaticRect(previous.bounds, value.bounds) ||
                !sameAutomaticRect(previous.declaredPaintBounds, value.declaredPaintBounds)
            case None => !sameAutomaticRect(Rect.zero(), value.bounds) ||
                !sameAutomaticRect(Rect.zero(), value.declaredPaintBounds)
        }
        publishEventTopology(value.eventTopologyCommit())
        layoutState = ElementLayoutState.Current(value)
        revision = nextRevision(revision)
        noteOwnerChange()
        geometryChanged
    }

    func layoutMatches(
        bounds: Rect,
        visibilityClip: ?Rect,
        paintOutset: PaintOutset,
        environment: UiEnvironmentKey
    ): Bool {
        ensureAlive("inspect layout")
        match (layoutState) {
            case ElementLayoutState.Current(value) => value.matches(bounds,
                visibleBoundsForLayout(bounds, visibilityClip), paintOutset.expand(bounds), environment)
            case _ => false
        }
    }

    func paintGeometryMatches(bounds: Rect, paintOutset: PaintOutset): Bool {
        ensureAlive("inspect paint layout")
        match (lastLayoutCommit()) {
            case Some(value) => sameAutomaticRect(value.bounds, bounds) && sameAutomaticRect(value.declaredPaintBounds,
                paintOutset.expand(bounds))
            case None => sameAutomaticRect(Rect.zero(), bounds) && sameAutomaticRect(Rect.zero(),
                paintOutset.expand(bounds))
        }
    }

    /** Replays a committed layout, or throws `IllegalStateException` when no valid commit exists. */
    func replayLayout(ctx: UiContext): Unit {
        ensureAlive("replay layout")
        match (layoutState) {
            case ElementLayoutState.Current(value) => value.replay(ctx)
            case _ => throw IllegalStateException("Cannot replay an invalid Element layout")
        }
    }

    func layoutEnvironmentMatches(environment: UiEnvironmentKey): Bool {
        ensureAlive("inspect layout environment")
        match (lastLayoutCommit()) {
            case Some(value) => value.environmentMatches(environment)
            case None => false
        }
    }

    func invalidateLayout(): Unit {
        ensureAlive("invalidate layout")
        if (!layoutIsCurrent()) {
            return
        }
        invalidateLayoutState()
        revision = nextRevision(revision)
        noteOwnerChange()
    }

    func hasLayout(): Bool {
        ensureAlive("inspect layout validity")
        layoutIsCurrent()
    }

    func layoutIsCurrent(): Bool {
        match (layoutState) {
            case ElementLayoutState.Current(_) => true
            case _ => false
        }
    }

    func committedLayoutBounds(): Rect {
        ensureAlive("inspect layout bounds")
        match (lastLayoutCommit()) {
            case Some(value) => value.bounds
            case None => Rect.zero()
        }
    }

    func invalidateLayoutState(): Unit {
        match (layoutState) {
            case ElementLayoutState.Current(value) => layoutState = ElementLayoutState.Stale(value)
            case _ => ()
        }
    }

    func lastLayoutCommit(): ?ElementLayoutCommit {
        match (layoutState) {
            case ElementLayoutState.Current(value) => Some(value)
            case ElementLayoutState.Stale(value) => Some(value)
            case ElementLayoutState.Absent => None
        }
    }
}

private func visibleBoundsForLayout(bounds: Rect, visibilityClip: ?Rect): Rect {
    match (visibilityClip) {
        case Some(clip) => bounds.intersection(clip)
        case None => bounds
    }
}
