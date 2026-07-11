/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package cui.core

import sdl.{Color, FontSizes, IconName, MouseButton, Rect, Size, SurfaceStyle, UiEvent, drawIcon}

private let ICON_DEFAULT_SIZE: Float32 = 18.0
private let ICON_BUTTON_PAD: Float32 = 10.0
private let ICON_TEXT_GAP: Float32 = 8.0

public class Icon <: Widget {
    private let icon: IconName
    private let size: Float32
    private let color: ?Color
    private var frame = Rect.zero()

    public init(icon: IconName, size!: Float32 = ICON_DEFAULT_SIZE, color!: ?Color = None) {
        this.icon = icon
        this.size = size
        this.color = color
        emit(this)
    }

    public func measure(_: UiContext, _: Size): Size {
        Size(size, size)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        drawIcon(ctx.renderer, icon, centeredIconRect(frame, size), iconColor(ctx))
    }

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }

    private func iconColor(ctx: UiContext): Color {
        match (color) {
            case Some(value) => value
            case None => ctx.theme.text
        }
    }
}

public class IconButton <: Widget {
    private let icon: IconName
    private let label: ?String
    private let role: ButtonRole
    private let style: ?SurfaceStyle
    private let onClick: () -> Unit
    private var frame = Rect.zero()

    public init(
        icon: IconName,
        label!: ?String = None,
        role!: ButtonRole = ButtonRole.Normal,
        style!: ?SurfaceStyle = None,
        onClick!: () -> Unit
    ) {
        this.icon = icon
        this.label = label
        this.role = role
        this.style = style
        this.onClick = onClick
        emit(this)
    }

    public func measure(ctx: UiContext, available: Size): Size {
        let width = match (label) {
            case Some(value) => max(76.0,
                ICON_BUTTON_PAD * 2.0 + ICON_DEFAULT_SIZE + ICON_TEXT_GAP + ctx.renderer.textWidth(value))
            case None => CUI_CONTROL_H
        }
        Size(min(available.w, width), CUI_CONTROL_H)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        drawSurface(ctx, frame, buttonStyle(ctx))
        let color = contentColor(ctx)
        drawIcon(ctx.renderer, icon, iconFrame(), color)
        match (label) {
            case Some(value) => ctx
                .renderer
                .text(value, iconFrame().right() + ICON_TEXT_GAP,
                    frame.centerY() - ctx.renderer.textHeight(pointSize: FontSizes.CONTROL) / 2.0, color,
                    pointSize: FontSizes.CONTROL)
            case None => ()
        }
    }

    public func handle(_: UiContext, event: UiEvent): Bool {
        match (event) {
            case UiEvent.MouseDown(MouseButton.Left, x, y) =>
                if (frame.contains(x, y)) {
                    onClick()
                    return true
                }
            case _ => ()
        }
        false
    }

    private func iconFrame(): Rect {
        match (label) {
            case Some(_) => Rect(
                frame.x + ICON_BUTTON_PAD,
                frame.centerY() - ICON_DEFAULT_SIZE / 2.0,
                ICON_DEFAULT_SIZE,
                ICON_DEFAULT_SIZE
            )
            case None => centeredIconRect(frame, ICON_DEFAULT_SIZE)
        }
    }

    private func contentColor(ctx: UiContext): Color {
        match (role) {
            case ButtonRole.Normal => ctx.theme.text
            case _ => ctx.theme.accentText
        }
    }

    private func buttonStyle(ctx: UiContext): SurfaceStyle {
        match (style) {
            case Some(value) => value
            case None =>
                let base = ctx.theme.buttonSurface(role)
                match (role) {
                    case ButtonRole.Normal =>
                        if (frame.contains(ctx.mouseX, ctx.mouseY)) {
                            base.withFill(ctx.theme.fieldActive)
                        } else {
                            base
                        }
                    case _ => base
                }
        }
    }
}

public class Divider <: Widget {
    private let axis: Axis
    private let color: ?Color
    private var frame = Rect.zero()

    public init(axis!: Axis = Axis.Horizontal, color!: ?Color = None) {
        this.axis = axis
        this.color = color
        emit(this)
    }

    public func measure(_: UiContext, _: Size): Size {
        // A divider only contributes its 1px thickness to a container's content size; the
        // parent's layout stretches it along the cross axis to span its siblings.
        match (axis) {
            case Axis.Horizontal => Size(0.0, 1.0)
            case Axis.Vertical => Size(1.0, 0.0)
        }
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        let c = match (color) {
            case Some(value) => value
            case None => ctx.theme.panelEdge
        }
        ctx.renderer.fill(dividerRect(), c)
    }

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }

    private func dividerRect(): Rect {
        match (axis) {
            case Axis.Horizontal => Rect(frame.x, frame.centerY(), frame.w, 1.0)
            case Axis.Vertical => Rect(frame.centerX(), frame.y + 4.0, 1.0, max(0.0, frame.h - 8.0))
        }
    }
}

private func centeredIconRect(frame: Rect, size: Float32): Rect {
    Rect(frame.centerX() - size / 2.0, frame.centerY() - size / 2.0, size, size)
}
