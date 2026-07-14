package cui.core

import sdl.{Color, FontSizes, IconName, Key, MouseButton, Rect, Size, SurfaceStyle, UiEvent, drawIcon}

private let ICON_DEFAULT_SIZE: Float32 = 18.0
private let ICON_BUTTON_PAD: Float32 = 10.0
private let ICON_TEXT_GAP: Float32 = 8.0

public class Icon <: Widget {
    private let icon: IconName
    private var iconExtent: Length
    private var iconColorOverride: ?Color
    private var frame = Rect.zero()

    public init(icon: IconName, size!: Length = Length(ICON_DEFAULT_SIZE, LengthUnit.Vp), color!: ?Color = None) {
        this.icon = icon
        this.iconExtent = size
        this.iconColorOverride = color
        emit(this)
    }

    /** Sets the square icon extent, e.g. `.iconSize(22.vp)`. */
    public func iconSize(value: Length): Icon {
        iconExtent = value
        this
    }

    /** Sets the square icon extent in virtual pixels. */
    public func iconSize(value: Float32): Icon {
        iconSize(vpLength(value))
    }

    /** Overrides the theme-derived icon color. */
    public func foregroundColor(value: Color): Icon {
        iconColorOverride = Some(value)
        this
    }

    public func measure(ctx: UiContext, _: Size): Size {
        let extent = resolvedExtent(ctx)
        Size(extent, extent)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        drawIcon(ctx.renderer, icon, centeredIconRect(frame, resolvedExtent(ctx)), iconColor(ctx))
    }

    private func resolvedExtent(ctx: UiContext): Float32 {
        max(1.0, ctx.resolve(iconExtent))
    }

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }

    private func iconColor(ctx: UiContext): Color {
        match (iconColorOverride) {
            case Some(value) => value
            case None => ctx.theme.text
        }
    }
}

public class IconButton <: Widget {
    private let icon: IconName
    private var labelText: ?String
    private var buttonRole: ButtonRole
    private var customStyle: ?SurfaceStyle
    private let onClick: () -> Unit
    private var controlId: String
    private var frame = Rect.zero()

    public init(
        icon: IconName,
        label!: ?String = None,
        role!: ButtonRole = ButtonRole.Normal,
        style!: ?SurfaceStyle = None,
        onClick!: () -> Unit
    ) {
        this.icon = icon
        this.labelText = label
        this.buttonRole = role
        this.customStyle = style
        this.onClick = onClick
        // The build-order identity keeps several icon-only buttons in one view distinct;
        // a shared id would let one button swallow the release meant for another.
        this.controlId = focusableControlIdentity(match (label) {
            case Some(value) => "IconButton:${value}"
            case None => "IconButton"
        })
        emit(this)
    }

    /**
     * Sets an explicit focus and press identity. Defaults are already unique per build;
     * set one when identity must survive tree reshapes.
     * Throws `IllegalArgumentException` when `value` is empty.
     */
    public func id(value: String): IconButton {
        requireControlId(value, "IconButton")
        reregisterFocusable(controlId, value)
        controlId = value
        this
    }

    /** Adds a text label beside the icon. */
    public func label(value: String): IconButton {
        labelText = Some(value)
        this
    }

    /** Applies semantic button coloring. */
    public func role(value: ButtonRole): IconButton {
        buttonRole = value
        this
    }

    /** Overrides the theme-derived button surface. */
    public func style(value: SurfaceStyle): IconButton {
        customStyle = Some(value)
        this
    }

    public func measure(ctx: UiContext, available: Size): Size {
        let width = match (labelText) {
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
        match (labelText) {
            case Some(value) => ctx
                .renderer
                .text(value, iconFrame().right() + ICON_TEXT_GAP,
                    frame.centerY() - ctx.renderer.textHeight(pointSize: FontSizes.CONTROL) / 2.0, color,
                    pointSize: FontSizes.CONTROL)
            case None => ()
        }
        if (ctx.showFocusRing(controlId)) {
            drawFocusRing(ctx, frame, ctx.theme.controlRadius)
        }
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        claimHoverIfInside(ctx, event, frame, controlId, CursorShape.Interactive)
        match (event) {
            case UiEvent.MouseDown(MouseButton.Left, x, y) =>
                if (frame.contains(x, y)) {
                    ctx.focus(controlId)
                    ctx.press(controlId)
                    return true
                }
            case UiEvent.MouseUp(MouseButton.Left, x, y) =>
                if (ctx.isPressed(controlId)) {
                    if (frame.contains(x, y)) {
                        onClick()
                    }
                    return true
                }
            case UiEvent.KeyDown(Key.Enter, _) =>
                if (ctx.hasFocus(controlId)) {
                    onClick()
                    return true
                }
            case UiEvent.KeyDown(Key.Space, _) =>
                if (ctx.hasFocus(controlId)) {
                    onClick()
                    return true
                }
            case _ => ()
        }
        false
    }

    public func focusableId(): ?String {
        Some(controlId)
    }

    private func iconFrame(): Rect {
        match (labelText) {
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
        match (buttonRole) {
            case ButtonRole.Normal => ctx.theme.text
            case _ => ctx.theme.accentText
        }
    }

    private func buttonStyle(ctx: UiContext): SurfaceStyle {
        match (customStyle) {
            case Some(value) => value
            case None =>
                let base = ctx.theme.buttonSurface(buttonRole)
                match (buttonRole) {
                    case ButtonRole.Normal =>
                        var style = base
                        if (ctx.isPressed(controlId)) {
                            style = style.withFill(ctx.theme.accentSoft)
                        } else if (ctx.isHovered(controlId)) {
                            // Single-winner hover: in overlapping layouts only the visually
                            // top-most claimant highlights (same protocol as the cursor shape).
                            style = style.withFill(ctx.theme.fieldActive)
                        }
                        // The focus ring (drawn in draw() on keyboard focus) shows where
                        // Enter/Space will land — same convention as Button: a pointer
                        // press must not leave a keyboard-style accent border behind.
                        style
                    case _ => base
                }
        }
    }
}

public class Divider <: Widget {
    private var dividerAxis: Axis
    private var dividerColor: ?Color
    private var frame = Rect.zero()

    public init(axis!: Axis = Axis.Horizontal, color!: ?Color = None) {
        this.dividerAxis = axis
        this.dividerColor = color
        emit(this)
    }

    /** Sets the divider orientation. */
    public func axis(value: Axis): Divider {
        dividerAxis = value
        this
    }

    /** Overrides the theme divider color, matching Label/Icon's `foregroundColor` naming. */
    public func foregroundColor(value: Color): Divider {
        dividerColor = Some(value)
        this
    }

    /** Deprecated alias for `foregroundColor`; kept so existing call sites keep working. */
    public func color(value: Color): Divider {
        foregroundColor(value)
    }

    public func measure(_: UiContext, _: Size): Size {
        // A divider only contributes its 1px thickness to a container's content size; the
        // parent's layout stretches it along the cross axis to span its siblings.
        match (dividerAxis) {
            case Axis.Horizontal => Size(0.0, 1.0)
            case Axis.Vertical => Size(1.0, 0.0)
        }
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        let c = match (dividerColor) {
            case Some(value) => value
            case None => ctx.theme.panelEdge
        }
        ctx.renderer.fill(dividerRect(), c)
    }

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }

    private func dividerRect(): Rect {
        match (dividerAxis) {
            case Axis.Horizontal => Rect(frame.x, frame.centerY(), frame.w, 1.0)
            case Axis.Vertical => Rect(frame.centerX(), frame.y + 4.0, 1.0, max(0.0, frame.h - 8.0))
        }
    }
}

private func centeredIconRect(frame: Rect, size: Float32): Rect {
    Rect(frame.centerX() - size / 2.0, frame.centerY() - size / 2.0, size, size)
}
