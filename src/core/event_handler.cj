/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package cui.core

import sdl.{FrameInfo, Rect, Size, UiEvent}

public class EventHandler <: Widget {
    private let child: Widget
    private let onEvent: (UiEvent) -> Bool

    public init(onEvent!: (UiEvent) -> Bool, body!: () -> Unit) {
        this.child = buildChild(body)
        this.onEvent = onEvent
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
                let _ = onEvent(event)
                let _ = child.handle(ctx, event)
                return false
            case _ => ()
        }
        if (onEvent(event)) {
            return true
        }
        child.handle(ctx, event)
    }

    public func isFlexible(): Bool {
        child.isFlexible()
    }
}

public class FrameHandler <: Widget {
    private let child: Widget
    private let onFrame: (FrameInfo) -> Unit

    public init(onFrame!: (FrameInfo) -> Unit, body!: () -> Unit) {
        this.child = buildChild(body)
        this.onFrame = onFrame
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
                onFrame(info)
                let _ = child.handle(ctx, event)
                return false
            case _ => return child.handle(ctx, event)
        }
    }

    public func isFlexible(): Bool {
        child.isFlexible()
    }
}
