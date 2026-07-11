/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package cui.core

import sdl.{Insets, Rect, Size, SurfaceStyle, UiEvent}

public class Panel <: Widget {
    private let child: Widget
    private let padding: Insets
    private let style: ?SurfaceStyle
    private let flexible: Bool
    private var frame = Rect.zero()

    public init(
        padding!: Insets = Insets(12.0),
        style!: ?SurfaceStyle = None,
        flexible!: Bool = true,
        body!: () -> Unit
    ) {
        child = buildChild(body)
        this.padding = padding
        this.style = style
        this.flexible = flexible
        emit(this)
    }

    public func measure(ctx: UiContext, available: Size): Size {
        let inner = Size(max(0.0, available.w - padding.horizontal()), max(0.0, available.h - padding.vertical()))
        let measured = child.measure(ctx, inner)
        Size(min(available.w, measured.w + padding.horizontal()), min(available.h, measured.h + padding.vertical()))
    }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        frame = rect
        child.layout(ctx, frame.inset(padding))
    }

    public func draw(ctx: UiContext): Unit {
        match (style) {
            case Some(value) => drawSurface(ctx, frame, value)
            case None => drawSurface(ctx, frame, ctx.theme.panelSurface())
        }
        child.draw(ctx)
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        child.handle(ctx, event)
    }

    public func isFlexible(): Bool {
        flexible && child.isFlexible()
    }
}
