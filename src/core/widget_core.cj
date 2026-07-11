/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package cui.core

import sdl.{Rect, Size, UiEvent}

protected let CUI_CONTROL_H: Float32 = 38.0
protected let CUI_SMALL_H: Float32 = 28.0
protected let CUI_GAP: Float32 = 8.0

public interface Widget {
    func measure(ctx: UiContext, available: Size): Size
    func layout(ctx: UiContext, rect: Rect): Unit
    func draw(ctx: UiContext): Unit
    func handle(ctx: UiContext, event: UiEvent): Bool

    /**
     * A flexible widget receives a share of its stack's leftover space instead of the
     * size it measured; non-flexible widgets hug their content. `flexWeight` sets the
     * relative share — wrap any widget in `Flexible(weight: ...)` to opt it in.
     */
    func isFlexible(): Bool {
        false
    }

    func flexWeight(): Float32 {
        1.0
    }
}

public enum Axis {
    | Horizontal
    | Vertical
}

public enum ButtonRole {
    | Normal
    | Primary
    | Danger
}

public enum TextAlign {
    | Leading
    | Center
    | Trailing
}
