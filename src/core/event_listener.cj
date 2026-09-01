package cui.core

import std.collection.{HashMap, HashSet}
import sdl.{Rect, Size, UiEvent}

private let EVENT_LISTENER_FOCUS_INDEX_THRESHOLD: Int64 = 8

/**
 * Observes a targeted subtree during capture, target, or bubble propagation. Pointer targeting uses
 * the subtree's laid-out bounds; keyboard and text targeting follows its focus stops. `Global`
 * scope is intended for application shortcuts. Returning Handled still permits the remaining path;
 * StopPropagation stops it; Consume applies both effects.
 */
public class EventListener <: Widget {
    private let child: Widget
    private let phase: EventPhase
    private let scope: EventScope
    private let listener: (UiContext, UiEvent) -> EventOutcome
    private let focusIds: Array<String>
    private let focusIdIndex: ?HashSet<String>
    private let focusTargets: Array<FocusTarget>
    private let focusTargetByKey: ?HashMap<String, FocusTarget>
    private let usesOwnedFocusTargets: Bool
    private var frame = Rect.zero()

    public init(
        phase!: EventPhase = EventPhase.Bubble,
        scope!: EventScope = EventScope.Subtree,
        onEvent!: (UiContext, UiEvent) -> EventOutcome,
        body!: () -> Unit
    ) {
        this.phase = phase
        this.scope = scope
        this.listener = onEvent
        let focusStart = currentFocusDeclarationCount()
        this.child = buildChild("EventListener", body)
        this.focusIds = child.focusableIds()
        this.focusIdIndex = eventListenerFocusIndex(focusIds)
        match (eventListenerFocusTargetsFrom(focusStart)) {
            case Some(targets) =>
                this.focusTargets = targets
                this.focusTargetByKey = eventListenerFocusTargetIndex(targets)
                this.usesOwnedFocusTargets = true
            case None =>
                this.focusTargets = []
                this.focusTargetByKey = None
                this.usesOwnedFocusTargets = false
        }
        emit(this)
    }

    init(
        child: Widget,
        phase: EventPhase,
        scope: EventScope,
        onEvent: (UiContext, UiEvent) -> EventOutcome,
        focusFragment: ?FocusSnapshot
    ) {
        this.phase = phase
        this.scope = scope
        this.listener = onEvent
        this.child = child
        this.focusIds = child.focusableIds()
        this.focusIdIndex = eventListenerFocusIndex(focusIds)
        match (focusFragment) {
            case Some(snapshot) =>
                this.focusTargets = snapshot.targets
                this.focusTargetByKey = eventListenerFocusTargetIndex(focusTargets)
                this.usesOwnedFocusTargets = true
            case None =>
                this.focusTargets = []
                this.focusTargetByKey = None
                this.usesOwnedFocusTargets = false
        }
    }

    public func measure(ctx: UiContext, available: Size): Size {
        child.measure(ctx, available)
    }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        frame = rect
        child.layout(ctx, rect)
    }

    public func draw(ctx: UiContext): Unit {
        child.draw(ctx)
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        match (event) {
            case UiEvent.Frame(_) =>
                broadcastEvent(child, ctx, event)
                return false
            case _ => ()
        }
        if (!targetsSubtree(ctx, event)) {
            return child.handle(ctx, event)
        }
        let ownsPropagation = ctx.enterEventPropagation()
        try {
            match (phase) {
                case EventPhase.Capture | EventPhase.Target => dispatchBeforeChild(ctx, event)
                case EventPhase.Bubble => dispatchAfterChild(ctx, event)
            }
            ctx.eventWasHandled() || ctx.eventIsPropagationStopped()
        } finally {
            ctx.leaveEventPropagation(ownsPropagation)
        }
    }

    public func pointerEventScope(): PointerEventScope {
        match (scope) {
            case EventScope.Global => PointerEventScope.Unbounded
            case EventScope.Subtree => child.pointerEventScope()
        }
    }

    public func paintOutset(): PaintOutset {
        child.paintOutset()
    }

    public func isFlexible(): Bool {
        child.isFlexible()
    }

    public func flexWeight(): Float32 {
        child.flexWeight()
    }

    public func acceptsStretch(axis: Axis): Bool {
        child.acceptsStretch(axis)
    }

    public func participatesInLayout(): Bool {
        child.participatesInLayout()
    }

    public func needsDetachedLayout(): Bool {
        child.needsDetachedLayout()
    }

    public func focusableId(): ?String {
        child.focusableId()
    }

    public func focusableIds(): Array<String> {
        focusIds
    }

    private func dispatchBeforeChild(ctx: UiContext, event: UiEvent): Unit {
        if (!ctx.eventIsPropagationStopped()) {
            ctx.applyEventOutcome(listener(ctx, event))
        }
        if (!ctx.eventIsPropagationStopped()) {
            ctx.noteEventHandled(child.handle(ctx, event))
        }
    }

    private func dispatchAfterChild(ctx: UiContext, event: UiEvent): Unit {
        ctx.noteEventHandled(child.handle(ctx, event))
        if (!ctx.eventIsPropagationStopped()) {
            ctx.applyEventOutcome(listener(ctx, event))
        }
    }

    private func targetsSubtree(ctx: UiContext, event: UiEvent): Bool {
        match (scope) {
            case EventScope.Global => return true
            case EventScope.Subtree => ()
        }
        match (event) {
            case UiEvent.MouseMove(x, y) => frame.contains(x, y) || ctx.leftMouseDown
            case UiEvent.MouseDown(_, x, y) => frame.contains(x, y)
            case UiEvent.MouseUp(_, x, y) => frame.contains(x, y) || ctx.leftMouseDown
            case UiEvent.MouseWheel(_, _, x, y) => frame.contains(x, y)
            case UiEvent.DropFile(_, x, y) => frame.contains(x, y)
            case UiEvent.DropText(_, x, y) => frame.contains(x, y)
            case UiEvent.DropPosition(x, y) => frame.contains(x, y)
            case UiEvent.KeyDown(_, _) | UiEvent.KeyUp(_) | UiEvent.TextEditing(_, _, _)
                | UiEvent.TextEditingCandidates(_, _, _) | UiEvent.TextInput(_) => subtreeHasFocus(ctx)
            case _ => true
        }
    }

    private func subtreeHasFocus(ctx: UiContext): Bool {
        if (!eventListenerFocusIdMatches(focusIds, focusIdIndex, ctx.focusId)) {
            return false
        }
        if (!usesOwnedFocusTargets) {
            return true
        }
        match (focusTargetByKey) {
            case Some(index) => match (index.get(ctx.focusId)) {
                case Some(target) => return ctx.hasFocusTarget(target)
                case None => return false
            }
            case None => ()
        }
        for (target in focusTargets) {
            if (target.key == ctx.focusId && ctx.hasFocusTarget(target)) {
                return true
            }
        }
        false
    }
}

private func eventListenerFocusIdMatches(ids: Array<String>, index: ?HashSet<String>, focused: String): Bool {
    match (index) {
        case Some(values) => return values.contains(focused)
        case None => ()
    }
    for (id in ids) {
        if (id == focused) {
            return true
        }
    }
    false
}

private func eventListenerFocusIndex(ids: Array<String>): ?HashSet<String> {
    if (ids.size <= EVENT_LISTENER_FOCUS_INDEX_THRESHOLD) {
        return None
    }
    let index = HashSet<String>()
    for (id in ids) {
        index.add(id)
    }
    Some(index)
}

private func eventListenerFocusTargetsFrom(start: Int64): ?Array<FocusTarget> {
    if (start < 0) {
        return None
    }
    match (currentStateStoreIfActive()) {
        case Some(store) => Some(store.focusFragmentFrom(start).targets)
        case None => None
    }
}

private func eventListenerFocusTargetIndex(targets: Array<FocusTarget>): ?HashMap<String, FocusTarget> {
    if (targets.size <= EVENT_LISTENER_FOCUS_INDEX_THRESHOLD) {
        return None
    }
    let index = HashMap<String, FocusTarget>()
    for (target in targets) {
        match (index.add(target.key, target)) {
            case Some(_) => throw IllegalStateException("EventListener focus targets were not normalized")
            case None => ()
        }
    }
    Some(index)
}

func applyEventListener(
    child: Widget,
    phase: EventPhase,
    scope: EventScope,
    onEvent: (UiContext, UiEvent) -> EventOutcome
): Widget {
    let listener = EventListener(child, phase, scope, onEvent, focusFragmentForEmission(child))
    replaceLastEmission(child, listener)
    listener
}
