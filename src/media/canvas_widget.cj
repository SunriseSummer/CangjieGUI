/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package cui.media

import sdl.{Rect, Renderer, Size, UiEvent}
import cui.core.{UiContext, Widget, drawSurface, emit}

public class CanvasWidget <: Widget {
    private let onDraw: (Renderer, Rect) -> Unit
    private let onEvent: (UiEvent, Rect) -> Bool
    private var frame = Rect.zero()

    public init(onDraw: (Renderer, Rect) -> Unit, onEvent!: (UiEvent, Rect) -> Bool = {_, _ => false}) {
        this.onDraw = onDraw
        this.onEvent = onEvent
        emit(this)
    }

    public func measure(_: UiContext, available: Size): Size {
        Size(available.w, available.h)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        drawSurface(ctx, frame, ctx.theme.fieldSurface(false))
        ctx.renderer.setClip(frame.inset(1.0))
        onDraw(ctx.renderer, frame)
        ctx.renderer.resetClip()
    }

    public func handle(_: UiContext, event: UiEvent): Bool {
        onEvent(event, frame)
    }

    public func isFlexible(): Bool {
        true
    }
}
