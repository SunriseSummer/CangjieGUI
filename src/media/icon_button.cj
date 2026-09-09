package cui.media

import cui.core.{ButtonRole, CUI_CONTROL_H, Length, LengthUnit, PointerEventScope, Semantics, SemanticsAction}
import cui.core.{SemanticsRole, UiContext, Widget, buttonInteractionStyle, drawFocusRing, drawSurface, emit}
import cui.core.{focusableControlIdentity, handleButtonProtocol, rekeyControl}
import sdl.{Color, FontSizes, Rect, Size, SurfaceStyle, UiEvent}

/**
 * A button with caller-provided icon media and an optional visible label. Uses the shared Button
 * press/focus protocol. The icon is decorative; label or accessibilityLabel names the button.
 * Button surface and icon appearance are independent. No image I/O during measurement.
 */
public class IconButton <: Widget {
    private let painter: IconPainter
    private var labelText: String
    private var accessibleName = ""
    private var buttonRole: ButtonRole
    private var customStyle: ?SurfaceStyle
    private var textGap = Length(8.0, LengthUnit.Vp)
    private let onClick: () -> Unit
    private var controlId: String
    private var frame = Rect.zero()

    public init(source: IconSource, label!: String = "", role!: ButtonRole = ButtonRole.Normal,
        style!: ?SurfaceStyle = None, iconStyle!: IconStyle = IconStyle(), onClick!: () -> Unit) {
        painter = IconPainter(source)
        painter.style = iconStyle
        labelText = label
        buttonRole = role
        customStyle = style
        this.onClick = onClick
        controlId = focusableControlIdentity("IconButton:${label}")
        emit(this)
    }

    /** File shorthand for a Template source. */
    public init(path: String, label!: String = "", role!: ButtonRole = ButtonRole.Normal, style!: ?SurfaceStyle = None,
        iconStyle!: IconStyle = IconStyle(), onClick!: () -> Unit) {
        this(IconSource(path), label: label, role: role, style: style, iconStyle: iconStyle, onClick: onClick)
    }

    /** Shares an existing immutable image source without copying its bytes. */
    public init(source: ImageSource, label!: String = "", role!: ButtonRole = ButtonRole.Normal,
        style!: ?SurfaceStyle = None, iconStyle!: IconStyle = IconStyle(), onClick!: () -> Unit) {
        this(IconSource(source), label: label, role: role, style: style, iconStyle: iconStyle, onClick: onClick)
    }

    /** Pins focus and press identity across tree reshapes; empty keys throw `IllegalArgumentException`. */
    public func key(value: String): IconButton {
        controlId = rekeyControl(controlId, value, "IconButton")
        this
    }

    /** Sets a visible label; empty leaves an icon-only button. */
    public func label(value: String): IconButton {
        labelText = value
        this
    }
    /** Overrides the accessible name without adding visible text. */
    public func accessibilityLabel(value: String): IconButton {
        accessibleName = value
        this
    }
    /** Selects semantic button surface and foreground colors. */
    public func role(value: ButtonRole): IconButton {
        buttonRole = value
        this
    }
    /** Overrides the button surface. */
    public func style(value: SurfaceStyle): IconButton {
        customStyle = Some(value)
        this
    }
    /** Replaces only the icon appearance. */
    public func iconStyle(value: IconStyle): IconButton {
        painter.style = value
        this
    }

    /** Sets the finite non-negative icon size; the hit target retains the normal control minimum. */
    public func iconSize(value: Length): IconButton {
        let old = painter.style
        iconStyle(IconStyle(size: value, color: old.color, opacity: old.opacity, sampling: old.sampling, flip: old.flip))
    }
    /** Sets the icon extent in virtual pixels. */
    public func iconSize(value: Float32): IconButton {
        iconSize(Length(value, LengthUnit.Vp))
    }

    /** Sets Template icon color; does not recolor the label or an Original source. */
    public func foregroundColor(value: Color): IconButton {
        let old = painter.style
        iconStyle(
            IconStyle(size: old.size, color: Some(value), opacity: old.opacity, sampling: old.sampling, flip: old.flip))
    }

    /** Replaces color intent while retaining resource identity. */
    public func renderingMode(value: IconRenderingMode): IconButton {
        painter.source = painter.source.withRenderingMode(value)
        painter.reset()
        this
    }

    /** Sets finite 0..1 opacity independently of source color mode. */
    public func iconOpacity(value: Float32): IconButton {
        let old = painter.style
        iconStyle(IconStyle(size: old.size, color: old.color, opacity: value, sampling: old.sampling, flip: old.flip))
    }

    /** Sets the finite non-negative space between icon and visible label. */
    public func iconGap(value: Length): IconButton {
        checkedImageLength(value.value)
        textGap = value
        this
    }

    /** Sets user-provided fallback artwork for decode/upload failure. */
    public func fallback(value: IconSource): IconButton {
        painter.fallback = Some(value)
        painter.reset()
        this
    }

    /** Primary source status; querying it never loads the resource. */
    public func status(): ImageStatus {
        painter.status()
    }
    /** Primary load failure, independent of a successful fallback; no I/O. */
    public func loadError(): ?String {
        painter.loadError()
    }

    public func measure(ctx: UiContext, available: Size): Size {
        let extent = painter.extent(ctx)
        let ps = ctx.textSize(fallback: FontSizes.CONTROL)
        let width = if (labelText.isEmpty()) {
            max(CUI_CONTROL_H, extent + 20.0)
        } else {
            max(76.0, 20.0 + extent + gap(ctx) + ctx.textWidth(labelText, pointSize: ps))
        }
        let textHeight: Float32 = if (labelText.isEmpty()) {
            0.0
        } else {
            ctx.textHeight(pointSize: ps) + 12.0
        }
        Size(max(0.0, min(available.w, width)),
            max(0.0, min(available.h, max(CUI_CONTROL_H, max(extent + 20.0, textHeight)))))
    }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        frame = rect
        ctx.registerSemanticProvider(controlId, rect, [SemanticsAction.Activate], {
            => Semantics(label: if (accessibleName.isEmpty()) {
                labelText
            } else {
                accessibleName
            }, role: SemanticsRole.Button)
        }, {
            action => match (action) {
                case SemanticsAction.Activate =>
                    onClick();
                    true
                case _ => false
            }
        })
    }

    public func draw(ctx: UiContext): Unit {
        drawSurface(ctx, frame, buttonInteractionStyle(ctx, controlId, buttonRole, customStyle))
        let color = match (buttonRole) {
            case ButtonRole.Normal => ctx.theme.text;
            case _ => ctx.theme.accentText
        }
        let content = frame.inset(min(10.0, max(0.0, min(frame.w, frame.h) / 2.0)))
        let bounds = if (labelText.isEmpty()) {
            iconSquare(content, painter.extent(ctx))
        } else {
            let extent = max(0.0, min(painter.extent(ctx), min(content.w, content.h)))
            Rect(content.x, frame.centerY() - extent / 2.0, extent, extent)
        }
        ctx.renderer.pushClip(frame.inset(2.0))
        try {
            painter.draw(ctx, bounds, color)
            if (!labelText.isEmpty()) {
                let ps = ctx.textSize(fallback: FontSizes.CONTROL)
                ctx.text(labelText, bounds.right() + gap(ctx), frame.centerY() - ctx.textHeight(pointSize: ps) / 2.0,
                    color, pointSize: ps)
            }
        } finally {
            ctx.renderer.popClip()
        }
        if (ctx.showFocusRing(controlId)) {
            drawFocusRing(ctx, frame, ctx.theme.controlRadius)
        }
    }

    private func gap(ctx: UiContext): Float32 {
        let value = ctx.resolve(textGap)
        if (value.isNaN() || value.isInf()) {
            0.0
        } else {
            max(0.0, value)
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
}
