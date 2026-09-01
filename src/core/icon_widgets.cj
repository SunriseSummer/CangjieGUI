package cui.core

import sdl.{Color, FontSizes, IconName, Rect, Size, SurfaceStyle, UiEvent, drawIcon}

private let ICON_DEFAULT_SIZE: Float32 = 18.0
private let ICON_BUTTON_PAD: Float32 = 10.0
private let ICON_TEXT_GAP: Float32 = 8.0

/**
 * A non-interactive vector icon drawn at a square extent (default 18 vp), in the theme text color
 * unless `foregroundColor` overrides it. For a clickable icon use `IconButton`.
 */
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

    public func pointerEventScope(): PointerEventScope {
        PointerEventScope.LayoutBounds
    }

    private func iconColor(ctx: UiContext): Color {
        match (iconColorOverride) {
            case Some(value) => value
            case None => ctx.theme.text
        }
    }
}

/*
 * A button whose face is an icon, optionally with a text label beside it. Activation matches `Button`:
 * `onClick` fires on a press released inside, or on Enter/Space while focused; `role` and `style`
 * color the surface the same way. Icon-only buttons in one view stay distinct through per-build
 * identities; `key` pins an identity that survives tree reshapes.
 */
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
    public func key(value: String): IconButton {
        controlId = rekeyControl(controlId, value, "IconButton")
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
            // Measure at the same size draw uses (FontSizes.CONTROL), so the two cannot drift
            // apart if the token tables ever diverge from the measurement default.
            case Some(value) => max(76.0,
                ICON_BUTTON_PAD * 2.0 + ICON_DEFAULT_SIZE + ICON_TEXT_GAP + ctx
                    .renderer
                    .textWidth(value, pointSize: FontSizes.CONTROL))
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
        handleButtonProtocol(ctx, event, frame, controlId, onClick)
    }

    public func pointerEventScope(): PointerEventScope {
        PointerEventScope.LayoutBounds
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
        buttonInteractionStyle(ctx, controlId, buttonRole, customStyle)
    }
}

/**
 * A hairline rule separating content: 1 logical pixel thick along its `axis`, stretched across the
 * cross axis by the parent stack. Color defaults to the theme's panel edge.
 */
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

    public func pointerEventScope(): PointerEventScope {
        PointerEventScope.LayoutBounds
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
