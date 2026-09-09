package cui.core

import sdl.{FontSizes, FontWeight, FontStyle, Key, MouseButton, Rect, Size, SurfaceStyle, UiEvent}

/**
 * An empty, flexible widget: it measures zero and absorbs a share of its stack's leftover space,
 * pushing its siblings apart — the idiomatic way to right-align a row's tail or split a toolbar.
 */
public class Spacer <: Widget {
    public init() {
        emit(this)
    }

    public func measure(_: UiContext, _: Size): Size {
        Size.zero()
    }

    public func layout(_: UiContext, _: Rect): Unit {}

    public func draw(_: UiContext): Unit {}

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }

    public func pointerEventScope(): PointerEventScope {
        PointerEventScope.LayoutBounds
    }

    public func isFlexible(): Bool {
        true
    }
}

/*
 * A push button: a themed surface with a centered title, firing `onClick` when the primary press that
 * started inside is also released inside (dragging off before release cancels). Focusable — Enter and
 * Space activate it while focused. `role` selects semantic coloring (primary accent, danger); `style`
 * overrides the surface entirely. The focus/press identity defaults to a per-build-position value;
 * `key` pins one that survives tree reshapes.
 */
public class Button <: Widget {
    private let title: String
    private let onClick: () -> Unit
    private var buttonRole: ButtonRole
    private var customStyle: ?SurfaceStyle
    private var pointSize: ?Length
    private var titleWeight: ?FontWeight = None
    private var fontFace: ?String = None
    private var controlId: String
    private var frame = Rect.zero()

    public init(
        title: String,
        onClick: () -> Unit,
        role!: ButtonRole = ButtonRole.Normal,
        style!: ?SurfaceStyle = None,
        fontSize!: ?Length = None
    ) {
        this.title = title
        this.onClick = onClick
        this.buttonRole = role
        this.customStyle = style
        this.pointSize = fontSize
        this.controlId = focusableControlIdentity("Button:${title}")
        emit(this)
    }

    /**
     * Sets an explicit focus and press identity. Defaults are already unique per build;
     * set one when identity must survive tree reshapes (for example a button that moves
     * between containers). Throws `IllegalArgumentException` when `value` is empty.
     */
    public func key(value: String): Button {
        controlId = rekeyControl(controlId, value, "Button")
        this
    }

    /** Applies semantic button coloring. */
    public func role(value: ButtonRole): Button {
        buttonRole = value
        this
    }

    /** Overrides the theme-derived button surface. */
    public func style(value: SurfaceStyle): Button {
        customStyle = Some(value)
        this
    }

    /** Overrides the inherited font family for this button's title. */
    public func fontFamily(name: String): Button {
        fontFace = Some(name)
        this
    }

    /** Overrides only the title weight. Other style fields inherit from the surrounding text style. */
    public func fontWeight(value: FontWeight): Button {
        titleWeight = Some(value)
        this
    }

    private func titleStyle(ctx: UiContext): FontStyle {
        let inherited = ctx.effectiveFontStyle()
        match (titleWeight) {
            case Some(value) => inherited.withWeight(value);
            case None => inherited
        }
    }

    /** Sets the label font size, e.g. `.fontSize(15.fp)`. */
    public func fontSize(value: Length): Button {
        pointSize = Some(value)
        this
    }

    /** Sets the label font size in font pixels. */
    public func fontSize(value: Float32): Button {
        fontSize(Length(value, LengthUnit.Fp))
    }

    public func measure(ctx: UiContext, available: Size): Size {
        let ps = ctx.textSize(fallback: FontSizes.CONTROL, override: pointSize)
        Size(min(available.w, max(72.0, ctx.textWidth(title, pointSize: ps, font: fontFace, style: titleStyle(ctx)) +
            24.0)), max(CUI_CONTROL_H, ctx.textHeight(pointSize: ps, font: fontFace, style: titleStyle(ctx)) + 12.0))
    }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        frame = rect
        ctx.registerSemanticProvider(controlId, rect, [SemanticsAction.Activate],
            {=> Semantics(label: title, role: SemanticsRole.Button)}, {
                action => match (action) {
                    case SemanticsAction.Activate =>
                        onClick()
                        true
                    case _ => false
                }
            })
    }

    public func draw(ctx: UiContext): Unit {
        drawSurface(ctx, frame, buttonStyle(ctx))
        let textColor = match (buttonRole) {
            case ButtonRole.Normal => ctx.theme.text
            case _ => ctx.theme.accentText
        }
        // A parent may impose a size smaller than the natural title; keep ink inside its surface.
        ctx.renderer.pushClip(frame.inset(2.0))
        try {
            ctx.textCenter(title, frame, textColor,
                pointSize: ctx.textSize(fallback: FontSizes.CONTROL, override: pointSize), font: fontFace,
                style: titleStyle(ctx))
        } finally {
            ctx.renderer.popClip()
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

    private func buttonStyle(ctx: UiContext): SurfaceStyle {
        buttonInteractionStyle(ctx, controlId, buttonRole, customStyle)
    }
}

/*
 * The shared push-button interaction protocol: press claims focus, a release inside fires
 * `onClick` (dragging off before release cancels), and Enter/Space activate while focused.
 * Extracted so `Button` and `IconButton` stay behaviourally identical by construction.
 */
protected func handleButtonProtocol(
    ctx: UiContext,
    event: UiEvent,
    frame: Rect,
    controlId: String,
    onClick: () -> Unit
): Bool {
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

/*
 * The shared push-button surface: a custom style wins outright; the Normal role layers
 * pressed/hovered fills over the theme surface (single-winner hover — only the top-most
 * claimant highlights); Primary/Danger keep their strong fill in every interaction state.
 * The focus ring, drawn separately on keyboard focus, marks where Enter/Space will land.
 */
protected func buttonInteractionStyle(
    ctx: UiContext,
    controlId: String,
    buttonRole: ButtonRole,
    customStyle: ?SurfaceStyle
): SurfaceStyle {
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
                        style = style.withFill(ctx.theme.fieldActive)
                    }
                    style
                case _ => base
            }
    }
}
