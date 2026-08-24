package cui.core

import sdl.{FrameInfo, Rect, Size, UiEvent}

/*
 * Wraps a subtree with an event interceptor: `onEvent` sees every event before the child
 * and consumes it by returning true. The context-aware overload exposes event-time metadata for
 * modifier shortcuts; the one-argument overload remains source compatible. The hook explicitly
 * subscribes to frame ticks (never consumable), while child frame subscribers are registered
 * independently. Use for container-level shortcuts or gestures that a stock control does not expose.
 */
public class EventHandler <: Widget {
    private let child: Widget
    private let onEvent: (UiContext, UiEvent) -> Bool

    public init(onEvent!: (UiEvent) -> Bool, body!: () -> Unit) {
        this.onEvent = {_, event => onEvent(event)}
        registerFrameSubscriber({
            _, info => let _ = onEvent(UiEvent.Frame(info))
        })
        this.child = buildChild("EventHandler", body)
        emit(this)
    }

    public init(onEvent!: (UiContext, UiEvent) -> Bool, body!: () -> Unit) {
        this.onEvent = onEvent
        registerFrameSubscriber({
            ctx, info => let _ = onEvent(ctx, UiEvent.Frame(info))
        })
        this.child = buildChild("ContextEventHandler", body)
        emit(this)
    }

    public func measure(ctx: UiContext, available: Size): Size {
        child.measure(ctx, available)
    }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        child.layout(ctx, rect)
    }

    public func draw(ctx: UiContext): Unit {
        child.draw(ctx)
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        match (event) {
            case UiEvent.Frame(_) =>
                // Direct-call compatibility: a Frame tick cannot be intercepted by the hook.
                let _ = onEvent(ctx, event) // cjcheck-ignore: ignore-result # broadcast semantics: a frame tick must not be intercepted by the hook
                broadcastEvent(child, ctx, event)
                return false
            case _ => ()
        }
        if (onEvent(ctx, event)) {
            return true
        }
        child.handle(ctx, event)
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

    public func focusableId(): ?String {
        child.focusableId()
    }

    public func focusableIds(): Array<String> {
        child.focusableIds()
    }
}

/*
 * Wraps a subtree with a per-frame hook: `onFrame` runs on every rendered frame with that
 * frame's timing info. Registering one keeps the dirty-frame loop rendering continuously
 * (the hook is a per-frame contract), so idle windows with a FrameHandler are not free —
 * prefer `Spring`/`Animator` for value animation and use this for polling-style work.
 */
public class FrameHandler <: Widget {
    private let child: Widget
    private let onFrame: (FrameInfo) -> Unit

    public init(onFrame!: (FrameInfo) -> Unit, body!: () -> Unit) {
        this.onFrame = onFrame
        registerFrameSubscriber(
            {
                ctx, info =>
                    ctx.requestFrame()
                    onFrame(info)
            }
        )
        this.child = buildChild("FrameHandler", body)
        emit(this)
    }

    public func measure(ctx: UiContext, available: Size): Size {
        child.measure(ctx, available)
    }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        child.layout(ctx, rect)
    }

    public func draw(ctx: UiContext): Unit {
        child.draw(ctx)
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        match (event) {
            case UiEvent.Frame(info) =>
                // A frame hook is a per-frame contract: keep the loop rendering so onFrame keeps
                // firing (animations, dialog polling) instead of being frozen by dirty-frame skipping.
                ctx.requestFrame()
                onFrame(info)
                broadcastEvent(child, ctx, event)
                return false
            case _ => return child.handle(ctx, event)
        }
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

    public func focusableId(): ?String {
        child.focusableId()
    }

    public func focusableIds(): Array<String> {
        child.focusableIds()
    }
}
