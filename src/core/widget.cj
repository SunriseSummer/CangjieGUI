package cui.core

import sdl.{Color, Rect, Size, SurfaceStyle, UiEvent}

protected let CUI_CONTROL_H: Float32 = 38.0
protected let CUI_SMALL_H: Float32 = 28.0
protected let CUI_GAP: Float32 = 8.0

/*
 * The widget contract. Application code remains declarative, while DesktopApp automatically retains
 * clean builder bodies and re-executes only State-dependent dirty paths. Widget instances are still
 * transient values rather than application state — anything that must survive replacement lives in
 * `State` (see `localState`). Constructors call `emit(this)` so the enclosing container collects the
 * widget in declaration order. The committed tree runs `measure` (preferred size within `available`),
 * `layout` (assigns the frame), `draw`, and `handle`; synthesized frame ticks use the explicit
 * subscription registry (`FrameHandler` / `subscribeFrame`) instead of traversing every widget.
 * `handle` consumption stops dispatch behind it; default modifiers wrap the widget for chaining.
 */
public interface Widget {
    /** Returns the preferred size within `available` space; must not exceed it unless unavoidable. */
    func measure(ctx: UiContext, available: Size): Size
    /** Assigns the widget's on-screen frame; children are positioned inside `rect` here. */
    func layout(ctx: UiContext, rect: Rect): Unit
    /** Paints the laid-out frame; disjoint `layout + paintOutset` may be skipped, so lifecycle work belongs in State/effects/frame subscriptions. */
    func draw(ctx: UiContext): Unit
    /** Processes one input event; returning true consumes it and stops dispatch behind this widget. */
    func handle(ctx: UiContext, event: UiEvent): Bool

    /**
     * Whether pointer handlers in this subtree are confined to the rectangle its parent assigned.
     * The compatibility default is `Unbounded`; return `LayoutBounds` to let indexed containers
     * prune the subtree for spatially disjoint pointer events. Active pointer capture bypasses the
     * index, so drags and releases still reach their owner outside the original bounds.
     */
    func pointerEventScope(): PointerEventScope {
        PointerEventScope.Unbounded
    }

    /**
     * Conservative paint overflow beyond the rectangle assigned by `layout`. Focusable leaves get
     * the framework focus-ring allowance by default; custom drawing that extends further should
     * override this method or use the fluent `paintOutset` modifier.
     */
    func paintOutset(): PaintOutset {
        if (focusableId().isSome()) {
            PaintOutset.all(4.0)
        } else {
            PaintOutset()
        }
    }

    /**
     * A flexible widget receives a share of its stack's leftover space instead of the
     * size it measured; non-flexible widgets hug their content. `flexWeight` sets the
     * relative share — wrap any widget in `Flexible(weight: ...)` to opt it in.
     */
    func isFlexible(): Bool {
        false
    }

    /** The relative share of leftover space a flexible widget receives (see `isFlexible`). */
    func flexWeight(): Float32 {
        1.0
    }

    /** Whether a stack may stretch this widget on `axis` beyond its measured size. */
    func acceptsStretch(_: Axis): Bool {
        true
    }

    /** Whether this node occupies a position in its parent layout. */
    func participatesInLayout(): Bool {
        true
    }

    /** Whether a zero-space node still needs a layout callback for portal/registration side effects. */
    func needsDetachedLayout(): Bool {
        false
    }

    /*
     * The keyboard-focus id this widget registered during construction, or `None` for
     * non-focusable widgets and multi-control containers. Single-child wrappers forward
     * their child's id; `.enabled(false)` uses it to take the control out of Tab traversal.
     */
    func focusableId(): ?String {
        None
    }

    /*
     * Every keyboard-focus id this widget's subtree registered during construction, in
     * declaration order. The default covers leaf controls (their single `focusableId`);
     * containers concatenate their children's and wrappers forward. `.enabled(false)`
     * uses it to take a whole disabled subtree out of Tab traversal.
     */
    func focusableIds(): Array<String> {
        match (focusableId()) {
            case Some(id) => [id]
            case None => []
        }
    }

    /** Constrains this widget to an exact width, e.g. `.width(160.vp)`. */
    func width(value: Length): Widget {
        applyModifier(this, WidgetModifier.Width(value))
    }

    /** Constrains this widget to an exact width in virtual pixels. */
    func width(value: Float32): Widget {
        width(vpLength(value))
    }

    /** Constrains this widget to an exact height, e.g. `.height(48.vp)`. */
    func height(value: Length): Widget {
        applyModifier(this, WidgetModifier.Height(value))
    }

    /** Constrains this widget to an exact height in virtual pixels. */
    func height(value: Float32): Widget {
        height(vpLength(value))
    }

    /** Prevents this widget from measuring narrower than `value`. */
    func minWidth(value: Length): Widget {
        applyModifier(this, WidgetModifier.MinWidth(value))
    }

    /** Prevents this widget from measuring narrower than `value` virtual pixels. */
    func minWidth(value: Float32): Widget {
        minWidth(vpLength(value))
    }

    /** Prevents this widget from measuring wider than `value`. */
    func maxWidth(value: Length): Widget {
        applyModifier(this, WidgetModifier.MaxWidth(value))
    }

    /** Prevents this widget from measuring wider than `value` virtual pixels. */
    func maxWidth(value: Float32): Widget {
        maxWidth(vpLength(value))
    }

    /** Prevents this widget from measuring shorter than `value`. */
    func minHeight(value: Length): Widget {
        applyModifier(this, WidgetModifier.MinHeight(value))
    }

    /** Prevents this widget from measuring shorter than `value` virtual pixels. */
    func minHeight(value: Float32): Widget {
        minHeight(vpLength(value))
    }

    /** Prevents this widget from measuring taller than `value`. */
    func maxHeight(value: Length): Widget {
        applyModifier(this, WidgetModifier.MaxHeight(value))
    }

    /** Prevents this widget from measuring taller than `value` virtual pixels. */
    func maxHeight(value: Float32): Widget {
        maxHeight(vpLength(value))
    }

    /** Makes this widget consume all width offered by its parent. */
    func fillWidth(): Widget {
        applyModifier(this, WidgetModifier.FillWidth)
    }

    /** Makes this widget consume all height offered by its parent. */
    func fillHeight(): Widget {
        applyModifier(this, WidgetModifier.FillHeight)
    }

    /** Adds equal space around this widget, e.g. `.padding(16.vp)`. Order is significant. */
    func padding(all: Length): Widget {
        applyModifier(this, WidgetModifier.Padding(LengthInsets(all)))
    }

    /** Adds equal space around this widget in virtual pixels. */
    func padding(all: Float32): Widget {
        padding(vpLength(all))
    }

    /** Adds horizontal and vertical space around this widget. */
    func padding(horizontal: Length, vertical: Length): Widget {
        applyModifier(this, WidgetModifier.Padding(LengthInsets(horizontal, vertical)))
    }

    /** Adds horizontal and vertical space around this widget in virtual pixels. */
    func padding(horizontal: Float32, vertical: Float32): Widget {
        padding(vpLength(horizontal), vpLength(vertical))
    }

    /** Adds independently configurable space around all four edges. */
    func padding(left: Length, top: Length, right: Length, bottom: Length): Widget {
        applyModifier(this, WidgetModifier.Padding(LengthInsets(top: top, right: right, bottom: bottom, left: left)))
    }

    /** Adds independently configurable space around all four edges in virtual pixels. */
    func padding(left: Float32, top: Float32, right: Float32, bottom: Float32): Widget {
        padding(vpLength(left), vpLength(top), vpLength(right), vpLength(bottom))
    }

    /** Paints a solid rounded background behind this widget. */
    func background(color: Color): Widget {
        applyModifier(this, WidgetModifier.Surface(SurfaceStyle(color)))
    }

    /** Paints a solid background with the requested corner radius. */
    func background(color: Color, radius: Length): Widget {
        applyModifier(this, WidgetModifier.Background(color, radius))
    }

    /** Paints a solid background with the corner radius in virtual pixels. */
    func background(color: Color, radius: Float32): Widget {
        background(color, vpLength(radius))
    }

    /**
     * Paints a solid background whose four corners take independent radii (see `Corners`) — for chat
     * bubbles, top-rounded tabs, and edge-docked sheets. Radii are in virtual pixels.
     */
    func background(color: Color, corners!: Corners): Widget {
        applyModifier(this, WidgetModifier.PerCornerBackground(corners, color))
    }

    /** Paints a complete surface style behind this widget. */
    func surface(style: SurfaceStyle): Widget {
        applyModifier(this, WidgetModifier.Surface(style))
    }

    /** Paints a linear-gradient background behind this widget (see `Gradient`). */
    func gradientBackground(gradient: Gradient): Widget {
        applyModifier(this, WidgetModifier.GradientBackground(gradient, vpLength(0.0)))
    }

    /** Paints a linear-gradient background with the given corner radius. */
    func gradientBackground(gradient: Gradient, radius: Length): Widget {
        applyModifier(this, WidgetModifier.GradientBackground(gradient, radius))
    }

    /** Paints a linear-gradient background with the corner radius in virtual pixels. */
    func gradientBackground(gradient: Gradient, radius: Float32): Widget {
        gradientBackground(gradient, vpLength(radius))
    }

    /**
     * Casts a soft drop shadow behind this widget. The halo is painted behind the child, so chain it
     * after a rounded `background` and pass the matching corner radius so the shadow hugs the corners.
     */
    func shadow(value: Shadow): Widget {
        applyModifier(this, WidgetModifier.DropShadow(value, vpLength(0.0)))
    }

    /** Casts a soft drop shadow rounded to `radius` (match the widget's own rounding). */
    func shadow(value: Shadow, radius!: Length): Widget {
        applyModifier(this, WidgetModifier.DropShadow(value, radius))
    }

    /** Casts a soft drop shadow with the corner radius in virtual pixels. */
    func shadow(value: Shadow, radius!: Float32): Widget {
        applyModifier(this, WidgetModifier.DropShadow(value, vpLength(radius)))
    }

    /** Strokes a 1px rounded border on top of this widget's fill and content. */
    /**
     * Casts several stacked drop shadows behind this widget, painted in array order (first is
     * deepest). `Shadow.keyAmbient(level)` supplies the standard Material key-plus-ambient pair.
     */
    func shadow(layers: Array<Shadow>): Widget {
        applyModifier(this, WidgetModifier.MultiShadow(layers, vpLength(0.0)))
    }

    /** Casts stacked drop shadows hugging the given corner radius. */
    func shadow(layers: Array<Shadow>, radius!: Length): Widget {
        applyModifier(this, WidgetModifier.MultiShadow(layers, radius))
    }

    /** Casts stacked drop shadows with the corner radius in virtual pixels. */
    func shadow(layers: Array<Shadow>, radius!: Float32): Widget {
        shadow(layers, radius: vpLength(radius))
    }

    /** Declares equal custom paint overflow without changing layout size or drawing. */
    func paintOutset(value: Float32): Widget {
        applyModifier(this, WidgetModifier.PaintOverflow(PaintOutset.all(value)))
    }

    /** Declares asymmetric custom paint overflow without changing layout size or drawing. */
    func paintOutset(value: PaintOutset): Widget {
        applyModifier(this, WidgetModifier.PaintOverflow(value))
    }

    /** Strokes a 1-pixel square-cornered border on top of this widget. */
    func border(color: Color): Widget {
        applyModifier(this, WidgetModifier.Border(color, 1.0, vpLength(0.0)))
    }

    /** Strokes a `width`-thick rounded border on top of this widget. */
    func border(color: Color, width!: Float32): Widget {
        applyModifier(this, WidgetModifier.Border(color, max(0.0, width), vpLength(0.0)))
    }

    /** Strokes a rounded border with the given width and corner radius (match the widget's rounding). */
    func border(color: Color, width!: Float32, radius!: Length): Widget {
        applyModifier(this, WidgetModifier.Border(color, max(0.0, width), radius))
    }

    /** Strokes a rounded border with the corner radius in virtual pixels. */
    func border(color: Color, width!: Float32, radius!: Float32): Widget {
        applyModifier(this, WidgetModifier.Border(color, max(0.0, width), vpLength(radius)))
    }

    /** Strokes a dashed 1.5px rounded border (dash 6, gap 4) on top of this widget. */
    func dashedBorder(color: Color): Widget {
        applyModifier(this, WidgetModifier.DashedBorder(color, 1.5, vpLength(0.0), 6.0, 4.0))
    }

    /** Strokes a dashed rounded border with the corner radius in virtual pixels (default dash 6, gap 4). */
    func dashedBorder(color: Color, radius!: Float32): Widget {
        applyModifier(this, WidgetModifier.DashedBorder(color, 1.5, vpLength(radius), 6.0, 4.0))
    }

    /** Strokes a fully configured dashed rounded border (width, corner radius, dash and gap lengths). */
    func dashedBorder(color: Color, width!: Float32, radius!: Float32, dash!: Float32, gap!: Float32): Widget {
        applyModifier(this,
            WidgetModifier.DashedBorder(color, max(0.0, width), vpLength(radius), max(0.0, dash), max(0.0, gap)))
    }

    /** Gives this widget a relative share of an enclosing stack's remaining space. */
    func flex(): Widget {
        applyModifier(this, WidgetModifier.Flex(1.0))
    }

    /** Gives this widget `weight` shares of an enclosing stack's remaining space. */
    func flex(weight: Float32): Widget {
        applyModifier(this, WidgetModifier.Flex(max(0.0, weight)))
    }

    /** Includes or removes this widget from layout, drawing, and event dispatch. */
    func visible(isVisible: Bool): Widget {
        if (!isVisible) {
            // A hidden subtree also leaves Tab traversal: its draw is skipped (no ring could
            // show) and its handle is suppressed (Enter/Space would do nothing), so a stop
            // kept in the ring would be an invisible dead end. Same protocol as `enabled`.
            for (id in focusableIds()) {
                unregisterFocusable(id)
            }
        }
        applyModifier(this, WidgetModifier.Visible(isVisible))
    }

    /*
     * Keeps this widget in layout and drawing while suppressing input events. A disabled
     * subtree also leaves keyboard Tab traversal — a stop that ignores Enter/Space would
     * be a dead end. Works at any granularity: on a single control or on a container
     * (an HStack form row, a whole panel), whose focus stops are removed via
     * `focusableIds()`.
     */
    func enabled(isEnabled: Bool): Widget {
        if (!isEnabled) {
            for (id in focusableIds()) {
                unregisterFocusable(id)
            }
        }
        applyModifier(this, WidgetModifier.Enabled(isEnabled))
    }

    /** Adds platform-independent accessibility properties with an automatically derived identity. */
    func semantics(properties: Semantics): Widget {
        let id = match (focusableId()) {
            case Some(focusId) => focusId
            case None => controlIdentity("Semantics:${properties.label}")
        }
        applyModifier(this, WidgetModifier.Accessibility(id, properties))
    }

    /** Adds platform-independent accessibility properties with an explicit stable identity. */
    func semantics(properties: Semantics, key!: String): Widget {
        requireControlId(key, "Semantics")
        applyModifier(this, WidgetModifier.Accessibility(key, properties))
    }

    /** Applies a reusable Modifier pipeline to this Widget. */
    func modifier(value: Modifier): Widget {
        value.applyTo(this)
    }

    /** Adds a capture, target, or bubble listener without introducing an application component. */
    func onEvent(handler!: (UiContext, UiEvent) -> EventOutcome): Widget {
        applyEventListener(this, EventPhase.Bubble, EventScope.Subtree, handler)
    }

    /** Adds an event listener at the requested phase with subtree targeting. */
    func onEvent(phase!: EventPhase, handler!: (UiContext, UiEvent) -> EventOutcome): Widget {
        applyEventListener(this, phase, EventScope.Subtree, handler)
    }

    /** Adds an event listener at the requested phase and targeting scope. */
    func onEvent(
        phase!: EventPhase,
        scope!: EventScope,
        handler!: (UiContext, UiEvent) -> EventOutcome
    ): Widget {
        applyEventListener(this, phase, scope, handler)
    }

    /**
     * Certifies that this subtree observes pointer events only inside its assigned layout rectangle.
     * Indexed multi-child containers can then skip it for disjoint points. Active pointer capture
     * still bypasses spatial pruning. Use only when custom handlers honour this boundary.
     */
    func pointerEventsWithinLayout(): Widget {
        applyModifier(this, WidgetModifier.PointerLayoutBounds)
    }
}

/*
 * Delivers `event` to `widget` as a broadcast: the consumed flag is deliberately dropped.
 * Frame ticks (and other broadcast phases) must reach every child so animations and
 * per-frame hooks keep running — no child may stop the fan-out by "consuming" the tick,
 * so the return value carries no information for the caller. Containers dispatching
 * consumable input should call `handle` directly and honour its result instead.
 */
public func broadcastEvent(widget: Widget, ctx: UiContext, event: UiEvent): Unit {
    let _ = widget.handle(ctx, event) // cjcheck-ignore: ignore-result # broadcast semantics: consumed flag is meaningless for fan-out (see function comment)
}

/** Delivers a zero-space layout callback to a detached portal/registration node when requested. */
protected func layoutDetachedIfNeeded(widget: Widget, ctx: UiContext): Unit {
    if (widget.needsDetachedLayout()) {
        widget.layout(ctx, Rect.zero())
    }
}

/** A layout direction: stacks lay out along one axis; stretch rules are asked per axis. */
public enum Axis {
    | Horizontal
    | Vertical
}

/** A button's visual intent, mapped by the theme to a fill/border set (see `buttonSurface`). */
public enum ButtonRole {
    | Normal
    | Primary
    | Danger
}

/** Horizontal text alignment within a label's frame, in reading direction. */
public enum TextAlign {
    | Leading
    | Center
    | Trailing
}

/** Controls how a stack positions children along its main axis. */
public enum MainAxisAlignment {
    | Start
    | Center
    | End
    | SpaceBetween
    | SpaceAround
    | SpaceEvenly
}

/** Controls how a stack positions children across its main axis. */
public enum CrossAxisAlignment {
    | Start
    | Center
    | End
    | Stretch
}

/** A two-dimensional alignment used by overlay-style containers. */
public enum Alignment {
    | TopLeading
    | Top
    | TopTrailing
    | Leading
    | Center
    | Trailing
    | BottomLeading
    | Bottom
    | BottomTrailing
}

/*
 * Clamps a list index into [0, count-1]; an empty list clamps to 0 so callers can keep a
 * single "current item" slot without special-casing emptiness. Shared by every control
 * that keeps a selected/highlighted position over a possibly shrinking item list.
 */
protected func clampItemIndex(index: Int64, count: Int64): Int64 {
    if (count <= 0 || index < 0) {
        0
    } else if (index >= count) {
        count - 1
    } else {
        index
    }
}
