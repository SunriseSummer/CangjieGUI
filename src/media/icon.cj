package cui.media

import cui.core.{Length, LengthUnit, PointerEventScope, Semantics, SemanticsNode, SemanticsRole}
import cui.core.{UiContext, Widget, controlIdentity, emit}
import sdl.{Color, Rect, Size, UiEvent}

/**
 * A static caller-provided icon, fitted inside a square (18 vp by default). Template sources follow
 * the foreground; Original sources preserve color. Measurement never decodes. Failed loads reserve
 * their size and paint nothing unless a caller-provided fallback is set. Decorative by default.
 */
public class Icon <: Widget & Resource {
    private let painter: IconPainter
    private var frame = Rect.zero()
    private var semanticLabel = ""
    private var semanticId = ""

    public init(source: IconSource, style!: IconStyle = IconStyle()) {
        painter = IconPainter(source)
        painter.style = style
        emit(this)
    }

    /** File shorthand for a Template icon. Use renderingMode(Original) for multicolor artwork. */
    public init(path: String, style!: IconStyle = IconStyle()) {
        this(IconSource(path), style: style)
    }

    /** Shares an existing immutable image source without copying its bytes. */
    public init(source: ImageSource, style!: IconStyle = IconStyle()) {
        this(IconSource(source), style: style)
    }

    /** Replaces all icon appearance settings. */
    public func iconStyle(value: IconStyle): Icon {
        painter.style = value
        this
    }

    /** Sets a finite non-negative square extent; zero hides the icon without decoding it. */
    public func iconSize(value: Length): Icon {
        let old = painter.style
        iconStyle(IconStyle(size: value, color: old.color, opacity: old.opacity, sampling: old.sampling, flip: old.flip))
    }

    /** Sets the extent in virtual pixels. */
    public func iconSize(value: Float32): Icon {
        iconSize(Length(value, LengthUnit.Vp))
    }

    /** Sets Template color; Original sources keep their own RGB. */
    public func foregroundColor(value: Color): Icon {
        let old = painter.style
        iconStyle(
            IconStyle(size: old.size, color: Some(value), opacity: old.opacity, sampling: old.sampling, flip: old.flip))
    }

    /** Replaces the source's color intent without changing its resource identity. */
    public func renderingMode(value: IconRenderingMode): Icon {
        painter.source = painter.source.withRenderingMode(value)
        painter.reset()
        this
    }

    /** Sets opacity in finite 0..1, independent of source color mode. */
    public func iconOpacity(value: Float32): Icon {
        let old = painter.style
        iconStyle(IconStyle(size: old.size, color: old.color, opacity: value, sampling: old.sampling, flip: old.flip))
    }

    /** Supplies application artwork for a failed primary source; fallback is attempted once, without recursion. */
    public func fallback(value: IconSource): Icon {
        painter.fallback = Some(value)
        painter.reset()
        this
    }

    /** Gives a meaningful standalone icon an accessibility label; empty makes it decorative again. */
    public func alt(value: String): Icon {
        semanticLabel = value
        if (!value.isEmpty() && semanticId.isEmpty()) {
            semanticId = controlIdentity("Icon")
        }
        this
    }

    public func measure(ctx: UiContext, available: Size): Size {
        let extent = min(painter.extent(ctx), max(0.0, min(available.w, available.h)))
        Size(extent, extent)
    }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        frame = rect
        if (!semanticLabel.isEmpty()) {
            ctx.registerSemantics(
                SemanticsNode(semanticId, Semantics(label: semanticLabel, role: SemanticsRole.Image), rect))
        }
    }

    public func draw(ctx: UiContext): Unit {
        painter.draw(ctx, iconSquare(frame, painter.extent(ctx)), ctx.theme.text)
    }

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }
    public func pointerEventScope(): PointerEventScope {
        PointerEventScope.LayoutBounds
    }

    /** Primary load status, independent of a successful fallback; no I/O. */
    public func status(): ImageStatus {
        painter.status()
    }
    /** Primary load diagnostics; no I/O. */
    public func loadError(): ?String {
        painter.loadError()
    }
    /** Whether this view has been retired with close. */
    public func isClosed(): Bool {
        painter.closed
    }
    /** Retires this view; shared textures remain under the bounded cache's ownership. */
    public func close(): Unit {
        painter.closed = true
        painter.reset()
    }
}

internal func iconSquare(frame: Rect, extent: Float32): Rect {
    let size = max(0.0, min(extent, min(frame.w, frame.h)))
    Rect(frame.centerX() - size / 2.0, frame.centerY() - size / 2.0, size, size)
}
