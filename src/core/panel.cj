package cui.core

import sdl.{Insets, Rect, Size, SurfaceStyle, UiEvent}

public class Panel <: Widget {
    private let child: Widget
    private var panelInsets: LengthInsets
    private var customStyle: ?SurfaceStyle
    private var isFlexiblePanel: Bool
    private var frame = Rect.zero()

    public init(
        padding!: LengthInsets = LengthInsets(vpLength(12.0)),
        style!: ?SurfaceStyle = None,
        flexible!: Bool = true,
        body!: () -> Unit
    ) {
        child = buildChild(body)
        this.panelInsets = padding
        this.customStyle = style
        this.isFlexiblePanel = flexible
        emit(this)
    }

    /** Sets the inset between the panel surface and its content, e.g. `16.vp`. */
    public func contentPadding(all: Length): Panel {
        panelInsets = LengthInsets(all)
        this
    }

    /** Sets independent horizontal and vertical content insets. */
    public func contentPadding(horizontal: Length, vertical: Length): Panel {
        panelInsets = LengthInsets(horizontal, vertical)
        this
    }

    /** Sets per-edge content insets. */
    public func contentPadding(value: LengthInsets): Panel {
        panelInsets = value
        this
    }

    /** Sets content insets from already-resolved logical-pixel values. */
    public func contentPadding(value: Insets): Panel {
        panelInsets = LengthInsets.of(value)
        this
    }

    /** Overrides the theme panel surface. */
    public func style(value: SurfaceStyle): Panel {
        customStyle = Some(value)
        this
    }

    /** Controls whether the panel participates in its enclosing stack's flex pass. */
    public func flexible(value: Bool): Panel {
        isFlexiblePanel = value
        this
    }

    /**
     * Sizes this panel to its content along the enclosing stack's main axis rather than filling the
     * offered space — the intent-revealing name for the common `.flexible(false)`.
     */
    public func hug(): Panel {
        isFlexiblePanel = false
        this
    }

    public func measure(ctx: UiContext, available: Size): Size {
        let insets = ctx.resolve(panelInsets)
        let inner = Size(max(0.0, available.w - insets.horizontal()), max(0.0, available.h - insets.vertical()))
        let measured = child.measure(ctx, inner)
        Size(min(available.w, measured.w + insets.horizontal()),
            min(available.h, measured.h + insets.vertical()))
    }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        frame = rect
        child.layout(ctx, frame.inset(ctx.resolve(panelInsets)))
    }

    public func draw(ctx: UiContext): Unit {
        match (customStyle) {
            case Some(value) => drawSurface(ctx, frame, value)
            case None => drawSurface(ctx, frame, ctx.theme.panelSurface())
        }
        child.draw(ctx)
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        child.handle(ctx, event)
    }

    public func isFlexible(): Bool {
        isFlexiblePanel && child.isFlexible()
    }

    public func flexWeight(): Float32 {
        // A panel is sizing chrome around its content: when it takes part in a flex pass,
        // the content's declared weight decides the share, not the wrapper.
        child.flexWeight()
    }

    public func focusableId(): ?String {
        child.focusableId()
    }

    public func focusableIds(): Array<String> {
        child.focusableIds()
    }
}
