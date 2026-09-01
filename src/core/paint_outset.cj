package cui.core

import sdl.{Rect, SurfaceStyle, clampF32}

private let CONFIGURABLE_SHADOW_WIDE_EXPANSION: Float32 = 0.25
private let SOFT_EDGE_OUTER_FEATHER: Float32 = 0.5
private let SURFACE_SHADOW_RADIUS_BASE: Float32 = 4.0
private let SURFACE_SHADOW_RADIUS_FACTOR: Float32 = 0.5
private let SURFACE_SHADOW_MIN_SPREAD: Float32 = 5.0
private let SURFACE_SHADOW_MAX_SPREAD: Float32 = 13.0
private let SURFACE_SHADOW_WIDE_EXPANSION: Float32 = 0.3

/**
 * Conservative logical-pixel paint overflow outside a Widget's assigned layout rectangle.
 * Component-wise `join` is associative, commutative and idempotent, so wrappers and containers
 * can aggregate independent effects without depending on traversal order.
 */
public struct PaintOutset {
    public let left: Float32
    public let top: Float32
    public let right: Float32
    public let bottom: Float32

    /** Creates an asymmetric non-negative paint overflow declaration. */
    public init(left!: Float32 = 0.0, top!: Float32 = 0.0, right!: Float32 = 0.0, bottom!: Float32 = 0.0) {
        this.left = max(0.0, left)
        this.top = max(0.0, top)
        this.right = max(0.0, right)
        this.bottom = max(0.0, bottom)
    }

    /** Creates equal overflow on all four edges. */
    public static func all(value: Float32): PaintOutset {
        PaintOutset(left: value, top: value, right: value, bottom: value)
    }

    /** Returns the least conservative declaration containing both operands. */
    public func join(other: PaintOutset): PaintOutset {
        PaintOutset(left: max(left, other.left), top: max(top, other.top), right: max(right, other.right),
            bottom: max(bottom, other.bottom))
    }

    /** Expands `bounds` by this asymmetric overflow. */
    public func expand(bounds: Rect): Rect {
        Rect(bounds.x - left, bounds.y - top, bounds.w + left + right, bounds.h + top + bottom)
    }

    func horizontalOnly(): PaintOutset {
        PaintOutset(left: left, right: right)
    }

    func verticalOnly(): PaintOutset {
        PaintOutset(top: top, bottom: bottom)
    }
}

func aggregatePaintOutsets(children: Array<Widget>): PaintOutset {
    var result = PaintOutset()
    for (child in children) {
        if (child.participatesInLayout()) {
            result = result.join(child.paintOutset())
        }
    }
    result
}

func configurableShadowPaintOutset(shadow: Shadow): PaintOutset {
    if (Int64(shadow.color.a) <= 0) {
        return PaintOutset()
    }
    // fillRoundedRectSoft contributes half its feather outside the supplied rectangle; the wide
    // layer has already expanded that rectangle by another quarter feather.
    let halo = shadow.spread + max(1.0, shadow.blur) * (CONFIGURABLE_SHADOW_WIDE_EXPANSION + SOFT_EDGE_OUTER_FEATHER)
    PaintOutset(left: halo - shadow.offsetX, top: halo - shadow.offsetY, right: halo + shadow.offsetX,
        bottom: halo + shadow.offsetY)
}

func surfacePaintOutset(style: SurfaceStyle): PaintOutset {
    if (Int64(style.shadow.a) <= 0) {
        return PaintOutset()
    }
    let spread = clampF32(SURFACE_SHADOW_RADIUS_BASE + style.radius * SURFACE_SHADOW_RADIUS_FACTOR,
        SURFACE_SHADOW_MIN_SPREAD, SURFACE_SHADOW_MAX_SPREAD)
    // The ambient layer expands by 0.3 * spread and its zero-alpha fringe by another 0.5.
    let halo = spread * (SURFACE_SHADOW_WIDE_EXPANSION + SOFT_EDGE_OUTER_FEATHER)
    PaintOutset(left: halo, top: halo - style.shadowOffsetY, right: halo, bottom: halo + style.shadowOffsetY)
}
