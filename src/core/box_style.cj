package cui.core

import sdl.{Color, Pen, Rect, clampF32}

/**
 * A two-stop linear gradient fill for a rounded background — from `start` to `end`, running vertically
 * (top to bottom) by default or horizontally (left to right) when `vertical` is false. Apply one with
 * the `gradientBackground` modifier; it reuses the same cached geometry a solid fill does, so it costs
 * no extra tessellation.
 */
public struct Gradient {
    public let start: Color
    public let end: Color
    public let vertical: Bool

    public init(start!: Color, end!: Color, vertical!: Bool = true) {
        this.start = start
        this.end = end
        this.vertical = vertical
    }

    /** This gradient with its two stops swapped (start ↔ end). */
    public func reversed(): Gradient {
        Gradient(start: end, end: start, vertical: vertical)
    }
}

/**
 * Independent corner radii for a background — the CSS four-value `border-radius` model, ordered
 * top-left, top-right, bottom-right, bottom-left. Apply one with the `background(color, corners!:)`
 * modifier to build chat bubbles (round three corners, square the tail), top-rounded tabs, or
 * edge-docked sheets. Each radius is clamped to half the short side when drawn. Use the factories for
 * common shapes — `all` (uniform), `top` / `bottom` / `left` / `right` (round one side) — or the full
 * initializer for an arbitrary mix.
 */
public struct Corners {
    public let topLeft: Float32
    public let topRight: Float32
    public let bottomRight: Float32
    public let bottomLeft: Float32

    public init(
        topLeft!: Float32 = 0.0,
        topRight!: Float32 = 0.0,
        bottomRight!: Float32 = 0.0,
        bottomLeft!: Float32 = 0.0
    ) {
        this.topLeft = topLeft
        this.topRight = topRight
        this.bottomRight = bottomRight
        this.bottomLeft = bottomLeft
    }

    /** All four corners at the same radius (equivalent to a uniform rounded background). */
    public static func all(radius: Float32): Corners {
        Corners(topLeft: radius, topRight: radius, bottomRight: radius, bottomLeft: radius)
    }

    /** Only the top two corners rounded (top tabs, sheets rising from the bottom). */
    public static func top(radius: Float32): Corners {
        Corners(topLeft: radius, topRight: radius)
    }

    /** Only the bottom two corners rounded (dropdowns, sheets hanging from the top). */
    public static func bottom(radius: Float32): Corners {
        Corners(bottomRight: radius, bottomLeft: radius)
    }

    /** Only the left two corners rounded. */
    public static func left(radius: Float32): Corners {
        Corners(topLeft: radius, bottomLeft: radius)
    }

    /** Only the right two corners rounded. */
    public static func right(radius: Float32): Corners {
        Corners(topRight: radius, bottomRight: radius)
    }
}

/**
 * A configurable drop shadow — the CSS `box-shadow` / Material elevation model: an offset, a blur
 * radius (how far the edge fades), a spread (how much the shadow grows before fading), and a colour.
 * Apply one to any widget with the `shadow` modifier; it paints a soft halo behind the widget, so it
 * is normally chained after a rounded `background` and shares its corner radius.
 *
 * Larger shadows extend further beyond the widget; inside a scrolling container a very large blur or
 * spread may be clipped at the viewport edge (the framework reserves a fixed shadow clearance), so
 * keep card elevations modest — the `elevation` presets stay within it at their lower levels.
 */
public struct Shadow {
    public let offsetX: Float32
    public let offsetY: Float32
    public let blur: Float32
    public let spread: Float32
    public let color: Color

    public init(
        color!: Color,
        offsetY!: Float32 = 2.0,
        offsetX!: Float32 = 0.0,
        blur!: Float32 = 12.0,
        spread!: Float32 = 0.0
    ) {
        this.color = color
        this.offsetY = offsetY
        this.offsetX = offsetX
        this.blur = max(0.0, blur)
        this.spread = spread
    }

    /**
     * A Material-style elevation preset. Higher `level` drops the surface further (more offset), with
     * a softer, wider blur — the standard "how high off the page" scale. `level` is clamped to 1..6.
     */
    public static func elevation(level: Int64, color!: Color = Color.rgba(0, 0, 0, 64)): Shadow {
        let l = clampF32(Float32(level), 1.0, 6.0)
        Shadow(color: color, offsetY: l * 1.5, blur: 5.0 + l * 4.0, spread: 0.0)
    }

    /** This shadow with its colour replaced (e.g. to tint an elevation preset). */
    public func withColor(value: Color): Shadow {
        Shadow(color: value, offsetY: offsetY, offsetX: offsetX, blur: blur, spread: spread)
    }

    /**
     * The Material dual-layer elevation: a wide, faint ambient halo (light from everywhere) under a
     * tighter, darker key shadow (the directional light) — the standard commercial rendering of depth,
     * where a single-layer shadow reads flatter. Pass the result to `shadow(layers)`; layers paint in
     * order, ambient first. `level` is clamped to 1..6 and tracks the single-layer `elevation` scale,
     * and `color` tints both layers (their alphas stay proportional).
     */
    public static func keyAmbient(level: Int64, color!: Color = Color.rgb(0, 0, 0)): Array<Shadow> {
        let l = clampF32(Float32(level), 1.0, 6.0)
        [
            Shadow(color: color.withAlpha(30), offsetY: l * 0.5, blur: 10.0 + l * 4.5),
            Shadow(color: color.withAlpha(52), offsetY: l * 1.4, blur: 3.0 + l * 2.2)
        ]
    }
}

/*
 * Paints a configurable soft drop shadow behind a `radius`-rounded surface. Like `drawSoftShadow` it
 * lays two gradient halos for a banding-free ramp, but honours the shadow's own offset, blur, and
 * spread instead of deriving them from the corner radius. The wide layer is the ambient penumbra, the
 * tight one the contact darkening; the widget is painted on top afterwards, leaving only the halo.
 */
protected func drawConfigurableShadow(ctx: UiContext, rect: Rect, radius: Float32, shadow: Shadow): Unit {
    let alpha = Int64(shadow.color.a)
    if (alpha <= 0) {
        return
    }
    let feather = max(1.0, shadow.blur)
    let base = rect.shift(shadow.offsetX, shadow.offsetY).inset(-shadow.spread)
    let spreadRadius = max(0.0, radius + shadow.spread)
    ctx
        .renderer
        .fillRoundedRectSoft(base.inset(-feather * 0.25), spreadRadius + feather * 0.25, shadow
            .color
            .withAlpha(alpha * 3 / 5), feather: feather)
    ctx
        .renderer
        .fillRoundedRectSoft(base, spreadRadius, shadow.color.withAlpha(alpha / 2), feather: feather * 0.55)
}

/*
 * A small down chevron drawn as two strokes near the right edge of `frame` — the shared
 * open-popup affordance for dropdown-style fields (Dropdown, ComboBox). Stroke-drawn so
 * it never depends on a font glyph.
 */
protected func drawFieldChevron(ctx: UiContext, frame: Rect): Unit {
    let cx = frame.right() - 18.0
    let cy = frame.centerY()
    let pen = Pen(width: 1.6, color: ctx.theme.mutedText)
    ctx.renderer.strokeLine(cx - 4.0, cy - 2.0, cx, cy + 2.5, pen)
    ctx.renderer.strokeLine(cx, cy + 2.5, cx + 4.0, cy - 2.0, pen)
}
