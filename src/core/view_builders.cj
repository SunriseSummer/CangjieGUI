/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package cui.core

import sdl.{Insets, Rect, Size, UiEvent}

public class VStack <: Widget {
    private let stack: Stack

    public init(
        spacing!: Float32 = CUI_GAP,
        padding!: Insets = Insets(0.0),
        flexible!: Bool = true,
        body!: () -> Unit
    ) {
        stack = Stack(Axis.Vertical, buildChildren(body), spacing: spacing, padding: padding, flexible: flexible)
        emit(this)
    }

    public func measure(ctx: UiContext, available: Size): Size {
        stack.measure(ctx, available)
    }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        stack.layout(ctx, rect)
    }

    public func draw(ctx: UiContext): Unit {
        stack.draw(ctx)
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        stack.handle(ctx, event)
    }

    public func isFlexible(): Bool {
        stack.isFlexible()
    }
}

public class HStack <: Widget {
    private let stack: Stack

    public init(
        spacing!: Float32 = CUI_GAP,
        padding!: Insets = Insets(0.0),
        flexible!: Bool = true,
        body!: () -> Unit
    ) {
        stack = Stack(Axis.Horizontal, buildChildren(body), spacing: spacing, padding: padding, flexible: flexible)
        emit(this)
    }

    public func measure(ctx: UiContext, available: Size): Size {
        stack.measure(ctx, available)
    }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        stack.layout(ctx, rect)
    }

    public func draw(ctx: UiContext): Unit {
        stack.draw(ctx)
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        stack.handle(ctx, event)
    }

    public func isFlexible(): Bool {
        stack.isFlexible()
    }
}

/**
 * Opts its content into the enclosing stack's space-sharing pass. A Flexible child is
 * stretched to `weight` shares of the leftover space instead of hugging its content, so
 * equal-weight cells form aligned columns and a heavier cell spans several of them:
 *
 *     HStack(spacing: 10.0) {
 *         Flexible(weight: 2.0) { Button("0", onZero) }   // twice as wide as the others
 *         Flexible { Button(".", onDot) }
 *         Flexible { Button("=", onEquals) }
 *     }
 *
 * An empty block (`Flexible {}`) reserves a blank cell, which is how grids keep their
 * column rhythm through missing entries.
 */
public class Flexible <: Widget {
    private let child: Widget
    private let weight: Float32

    public init(weight!: Float32 = 1.0, body!: () -> Unit) {
        this.child = buildChild(body)
        this.weight = max(0.0, weight)
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
        child.handle(ctx, event)
    }

    public func isFlexible(): Bool {
        true
    }

    public func flexWeight(): Float32 {
        weight
    }
}
