package cui.core

import sdl.{Color, Pen, Rect, Size, SurfaceStyle, UiEvent}

/**
 * Internal modifier vocabulary. Each chained call wraps the previous node, so modifier
 * order stays observable and predictable, matching the layout tree shown in source.
 * Sizes are stored as unit-carrying `Length` values and resolved against the active
 * `UiContext` scales during measure/layout, never at construction time.
 */
protected enum WidgetModifier {
    | Width(Length)
    | Height(Length)
    | MinWidth(Length)
    | MaxWidth(Length)
    | MinHeight(Length)
    | MaxHeight(Length)
    | FillWidth
    | FillHeight
    | Padding(LengthInsets)
    | Surface(SurfaceStyle)
    | Background(Color, Length)
    | PerCornerBackground(Corners, Color)
    | GradientBackground(Gradient, Length)
    | DropShadow(Shadow, Length)
    | MultiShadow(Array<Shadow>, Length)
    | PaintOverflow(PaintOutset)
    | Border(Color, Float32, Length)
    | DashedBorder(Color, Float32, Length, Float32, Float32)
    | Flex(Float32)
    | Visible(Bool)
    | Enabled(Bool)
    | Accessibility(String, Semantics)
    | PointerLayoutBounds
}

class ModifiedWidget <: Widget {
    private let child: Widget
    private let operation: WidgetModifier
    private var frame = Rect.zero()

    init(child: Widget, operation: WidgetModifier) {
        this.child = child
        this.operation = operation
    }

    public func measure(ctx: UiContext, available: Size): Size {
        match (operation) {
            case WidgetModifier.Width(length) =>
                let value = exact(ctx, length)
                let childSize = child.measure(ctx, Size(min(value, available.w), available.h))
                Size(min(value, available.w), childSize.h)
            case WidgetModifier.Height(length) =>
                let value = exact(ctx, length)
                let childSize = child.measure(ctx, Size(available.w, min(value, available.h)))
                Size(childSize.w, min(value, available.h))
            case WidgetModifier.MinWidth(length) =>
                let childSize = child.measure(ctx, available)
                Size(min(available.w, max(exact(ctx, length), childSize.w)), childSize.h)
            case WidgetModifier.MaxWidth(length) =>
                let limit = min(exact(ctx, length), available.w)
                let childSize = child.measure(ctx, Size(limit, available.h))
                Size(min(limit, childSize.w), childSize.h)
            case WidgetModifier.MinHeight(length) =>
                let childSize = child.measure(ctx, available)
                Size(childSize.w, min(available.h, max(exact(ctx, length), childSize.h)))
            case WidgetModifier.MaxHeight(length) =>
                let limit = min(exact(ctx, length), available.h)
                let childSize = child.measure(ctx, Size(available.w, limit))
                Size(childSize.w, min(limit, childSize.h))
            case WidgetModifier.FillWidth =>
                let childSize = child.measure(ctx, available)
                Size(available.w, childSize.h)
            case WidgetModifier.FillHeight =>
                let childSize = child.measure(ctx, available)
                Size(childSize.w, available.h)
            case WidgetModifier.Padding(edges) => measurePadding(ctx, available, edges)
            case WidgetModifier.Visible(isVisible) =>
                if (isVisible) {
                    child.measure(ctx, available)
                } else {
                    Size.zero()
                }
            case _ => child.measure(ctx, available)
        }
    }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        frame = rect
        match (operation) {
            case WidgetModifier.Width(length) => child.layout(ctx,
                Rect(rect.x, rect.y, min(exact(ctx, length), rect.w), rect.h))
            case WidgetModifier.Height(length) => child.layout(ctx,
                Rect(rect.x, rect.y, rect.w, min(exact(ctx, length), rect.h)))
            case WidgetModifier.MaxWidth(length) => child.layout(ctx,
                Rect(rect.x, rect.y, min(exact(ctx, length), rect.w), rect.h))
            case WidgetModifier.MaxHeight(length) => child.layout(ctx,
                Rect(rect.x, rect.y, rect.w, min(exact(ctx, length), rect.h)))
            case WidgetModifier.Padding(edges) => child.layout(ctx, rect.inset(ctx.resolve(edges)))
            case WidgetModifier.Visible(isVisible) =>
                if (isVisible) {
                    child.layout(ctx, rect)
                }
            case WidgetModifier.Enabled(isEnabled) =>
                let semanticsStart = ctx.semanticRegistrationCount()
                child.layout(ctx, rect)
                if (!isEnabled) {
                    ctx.disableSemanticRegistrationsFrom(semanticsStart)
                }
            case WidgetModifier.Accessibility(id, properties) =>
                child.layout(ctx, rect)
                ctx.registerSemantics(SemanticsNode(id, properties, rect))
            case _ => child.layout(ctx, rect)
        }
    }

    public func draw(ctx: UiContext): Unit { // cjcheck-ignore: long-function # one match with one short arm per modifier kind; the length is the enum's width, not nested logic
        match (operation) {
            case WidgetModifier.Surface(style) =>
                drawSurface(ctx, frame, style)
                child.draw(ctx)
            case WidgetModifier.Background(color, radius) =>
                drawSurface(ctx, frame, SurfaceStyle(color, radius: max(0.0, ctx.resolve(radius))))
                child.draw(ctx)
            // A background whose four corners take independent radii (vp), resolved to pixels here so
            // they scale like every other radius. Painted before the child, mirroring Background.
            case WidgetModifier.PerCornerBackground(corners, color) =>
                ctx
                    .renderer
                    .fillPerCornerRoundedRect(frame, color, topLeft: ctx.resolve(vpLength(corners.topLeft)),
                        topRight: ctx.resolve(vpLength(corners.topRight)),
                        bottomRight: ctx.resolve(vpLength(corners.bottomRight)),
                        bottomLeft: ctx.resolve(vpLength(corners.bottomLeft)))
                child.draw(ctx)
            case WidgetModifier.GradientBackground(gradient, radius) =>
                ctx
                    .renderer
                    .fillRoundedRectGradient(frame, max(0.0, ctx.resolve(radius)), gradient.start, gradient.end,
                        vertical: gradient.vertical)
                child.draw(ctx)
            // The shadow is painted before the child so its halo sits behind the widget; a shadow
            // modifier is therefore chained after `background` and shares its corner radius.
            case WidgetModifier.DropShadow(shadow, radius) =>
                drawConfigurableShadow(ctx, frame, max(0.0, ctx.resolve(radius)), shadow)
                child.draw(ctx)
            // Layered shadows paint in array order (first is deepest), all behind the child — the
            // Material key-plus-ambient pair being the canonical use (see Shadow.keyAmbient).
            case WidgetModifier.MultiShadow(layers, radius) =>
                let r = max(0.0, ctx.resolve(radius))
                for (layer in layers) {
                    drawConfigurableShadow(ctx, frame, r, layer)
                }
                child.draw(ctx)
            // The border is painted after the child so it sits on top of the fill and content; the
            // stroke is centred on the edge (inset by half its width) and rounded to the radius.
            case WidgetModifier.Border(color, width, radius) =>
                child.draw(ctx)
                drawBorderStroke(ctx, color, width, radius, dash: 0.0, gap: 0.0)
            case WidgetModifier.DashedBorder(color, width, radius, dash, gap) =>
                child.draw(ctx)
                drawBorderStroke(ctx, color, width, radius, dash: dash, gap: gap)
            case WidgetModifier.Visible(isVisible) =>
                if (isVisible) {
                    child.draw(ctx)
                }
            case WidgetModifier.Enabled(isEnabled) =>
                child.draw(ctx)
                if (!isEnabled) {
                    ctx.renderer.fill(frame, ctx.theme.bg.withAlpha(96))
                }
            case _ => child.draw(ctx)
        }
    }

    // Strokes the border arm shared by Border and DashedBorder: centred on the edge (inset by
    // half the width), rounded to the resolved radius; a zero dash means a solid stroke.
    private func drawBorderStroke(ctx: UiContext, color: Color, width: Float32, radius: Length, dash!: Float32,
        gap!: Float32): Unit {
        if (width <= 0.0 || Int64(color.a) == 0) {
            return
        }
        let r = max(0.0, max(0.0, ctx.resolve(radius)) - width / 2.0)
        let pen = Pen(width: width, color: color)
        if (dash > 0.0) {
            ctx.renderer.strokeRoundedRectDashed(frame.inset(width / 2.0), r, pen, dash: dash, gap: gap)
        } else {
            ctx.renderer.strokeRoundedRect(frame.inset(width / 2.0), r, pen)
        }
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        match (operation) {
            case WidgetModifier.Visible(isVisible) => isVisible && child.handle(ctx, event)
            case WidgetModifier.Enabled(isEnabled) =>
                // Disabled suppresses input, not time: the per-frame tick still flows, so a
                // wrapped Frame hook (e.g. dialog polling) keeps running while greyed out.
                match (event) {
                case UiEvent.Frame(_) => child.handle(ctx, event)
                case _ => isEnabled && child.handle(ctx, event)
            }
            case _ => child.handle(ctx, event)
        }
    }

    public func pointerEventScope(): PointerEventScope {
        match (operation) {
            case WidgetModifier.PointerLayoutBounds => PointerEventScope.LayoutBounds
            case _ => child.pointerEventScope()
        }
    }

    public func paintOutset(): PaintOutset {
        let inherited = child.paintOutset()
        match (operation) {
            case WidgetModifier.Surface(style) => inherited.join(surfacePaintOutset(style))
            case WidgetModifier.DropShadow(shadow, _) => inherited.join(configurableShadowPaintOutset(shadow))
            case WidgetModifier.MultiShadow(layers, _) =>
                var result = inherited
                for (layer in layers) {
                    result = result.join(configurableShadowPaintOutset(layer))
                }
                result
            case WidgetModifier.PaintOverflow(value) => inherited.join(value)
            case WidgetModifier.Visible(false) => PaintOutset()
            case _ => inherited
        }
    }

    public func isFlexible(): Bool {
        match (operation) {
            case WidgetModifier.Flex(_) => true
            case WidgetModifier.Visible(isVisible) => isVisible && child.isFlexible()
            case _ => child.isFlexible()
        }
    }

    public func flexWeight(): Float32 {
        match (operation) {
            case WidgetModifier.Flex(weight) => weight
            case _ => child.flexWeight()
        }
    }

    public func acceptsStretch(axis: Axis): Bool {
        match (operation) {
            // A size modifier pins its own axis and defers the other to the child, so a chain
            // like `.width(w).height(h)` reports both axes rigid — hard-coding the cross axis
            // to `true` here would mask an inner size modifier and break ZStack alignment.
            case WidgetModifier.Width(_) => match (axis) {
                case Axis.Horizontal => false
                case Axis.Vertical => child.acceptsStretch(axis)
            }
            case WidgetModifier.MaxWidth(_) => match (axis) {
                case Axis.Horizontal => false
                case Axis.Vertical => child.acceptsStretch(axis)
            }
            case WidgetModifier.Height(_) => match (axis) {
                case Axis.Horizontal => child.acceptsStretch(axis)
                case Axis.Vertical => false
            }
            case WidgetModifier.MaxHeight(_) => match (axis) {
                case Axis.Horizontal => child.acceptsStretch(axis)
                case Axis.Vertical => false
            }
            case WidgetModifier.FillWidth => match (axis) {
                case Axis.Horizontal => true
                case Axis.Vertical => child.acceptsStretch(axis)
            }
            case WidgetModifier.FillHeight => match (axis) {
                case Axis.Horizontal => child.acceptsStretch(axis)
                case Axis.Vertical => true
            }
            case _ => child.acceptsStretch(axis)
        }
    }

    public func participatesInLayout(): Bool {
        match (operation) {
            case WidgetModifier.Visible(isVisible) => isVisible && child.participatesInLayout()
            case _ => child.participatesInLayout()
        }
    }

    public func needsDetachedLayout(): Bool {
        match (operation) {
            case WidgetModifier.Visible(isVisible) => isVisible && child.needsDetachedLayout()
            case _ => child.needsDetachedLayout()
        }
    }

    public func focusableId(): ?String {
        child.focusableId()
    }

    public func focusableIds(): Array<String> {
        child.focusableIds()
    }

    /** Resolves an exact-size length, clamped to non-negative logical pixels. */
    private func exact(ctx: UiContext, length: Length): Float32 {
        max(0.0, ctx.resolve(length))
    }

    private func measurePadding(ctx: UiContext, available: Size, edges: LengthInsets): Size {
        let resolved = ctx.resolve(edges)
        let inner = Size(
            max(0.0, available.w - resolved.horizontal()),
            max(0.0, available.h - resolved.vertical())
        )
        let childSize = child.measure(ctx, inner)
        Size(
            min(available.w, childSize.w + resolved.horizontal()),
            min(available.h, childSize.h + resolved.vertical())
        )
    }
}

protected func applyModifier(widget: Widget, modifier: WidgetModifier): Widget {
    let modified = ModifiedWidget(widget, modifier)
    replaceLastEmission(widget, modified)
    modified
}
