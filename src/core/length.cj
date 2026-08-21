package cui.core

import sdl.Insets

/**
 * The unit of a UI length. CUI lays widgets out in a logical coordinate space, so the
 * three units describe how a value maps into that space:
 *  - `Px`: physical device pixels; resolved by dividing by the window display scale.
 *  - `Vp`: virtual (density-independent) pixels — the logical coordinate unit itself.
 *  - `Fp`: font pixels — virtual pixels additionally multiplied by the user font scale,
 *    intended for text sizes so typography can follow accessibility settings.
 */
public enum LengthUnit {
    | Px
    | Vp
    | Fp

    /** The unit's suffix as written in source: "px", "vp" or "fp". */
    public func symbol(): String {
        match (this) {
            case Px => "px"
            case Vp => "vp"
            case Fp => "fp"
        }
    }
}

/**
 * A one-dimensional size with an explicit unit, written as `100.px`, `24.vp` or `15.fp`.
 * Carrying the unit in the type keeps public size APIs unambiguous; the value is only
 * converted to logical pixels when a `UiContext` with the active scales is available.
 */
public struct Length <: ToString {
    public let value: Float32
    public let unit: LengthUnit

    public init(value: Float32, unit: LengthUnit) {
        this.value = value
        this.unit = unit
    }

    /** A zero length; the unit (vp) is irrelevant since zero resolves to zero at any scale. */
    public static func zero(): Length {
        Length(0.0, LengthUnit.Vp)
    }

    /** Scales the value while preserving the unit, e.g. `16.vp * 2.0`. */
    public operator func *(factor: Float32): Length {
        Length(value * factor, unit)
    }

    /** Divides the value while preserving the unit. */
    public operator func /(divisor: Float32): Length {
        Length(value / divisor, unit)
    }

    public func toString(): String {
        "${value}${unit.symbol()}"
    }
}

/**
 * Integer and floating literal suffixes for building `Length` values: `100.px`,
 * `24.vp`, `15.fp`, `1.5.vp`. Import `LengthUnits` (re-exported by the `cui` root
 * package) to enable the suffixes on `Int64` and `Float64`.
 */
public interface LengthUnits {
    /** This value in physical device pixels. */
    prop px: Length
    /** This value in virtual (density-independent) pixels. */
    prop vp: Length
    /** This value in font pixels, which follow the user font scale. */
    prop fp: Length
}

extend Int64 <: LengthUnits {
    /** This value in physical device pixels (see `LengthUnits.px`). */
    public prop px: Length {
        get() {
            Length(Float32(this), LengthUnit.Px)
        }
    }

    /** This value in virtual (density-independent) pixels (see `LengthUnits.vp`). */
    public prop vp: Length {
        get() {
            Length(Float32(this), LengthUnit.Vp)
        }
    }

    /** This value in font pixels, following the user font scale (see `LengthUnits.fp`). */
    public prop fp: Length {
        get() {
            Length(Float32(this), LengthUnit.Fp)
        }
    }
}

extend Float64 <: LengthUnits {
    /** This value in physical device pixels (see `LengthUnits.px`). */
    public prop px: Length {
        get() {
            Length(Float32(this), LengthUnit.Px)
        }
    }

    /** This value in virtual (density-independent) pixels (see `LengthUnits.vp`). */
    public prop vp: Length {
        get() {
            Length(Float32(this), LengthUnit.Vp)
        }
    }

    /** This value in font pixels, following the user font scale (see `LengthUnits.fp`). */
    public prop fp: Length {
        get() {
            Length(Float32(this), LengthUnit.Fp)
        }
    }
}

/** Per-edge lengths used by padding APIs, resolved to `Insets` at layout time. */
public struct LengthInsets {
    public let top: Length
    public let right: Length
    public let bottom: Length
    public let left: Length

    public init(all: Length) {
        this.top = all
        this.right = all
        this.bottom = all
        this.left = all
    }

    public init(horizontal: Length, vertical: Length) {
        this.top = vertical
        this.right = horizontal
        this.bottom = vertical
        this.left = horizontal
    }

    public init(top!: Length, right!: Length, bottom!: Length, left!: Length) {
        this.top = top
        this.right = right
        this.bottom = bottom
        this.left = left
    }

    /** Insets of zero on all four edges. */
    public static func zero(): LengthInsets {
        LengthInsets(Length.zero())
    }

    /** Wraps already-resolved logical-pixel insets, treating each edge as `vp`. */
    public static func of(edges: Insets): LengthInsets {
        LengthInsets(
            top: Length(edges.top, LengthUnit.Vp),
            right: Length(edges.right, LengthUnit.Vp),
            bottom: Length(edges.bottom, LengthUnit.Vp),
            left: Length(edges.left, LengthUnit.Vp)
        )
    }
}

/** Interprets a plain float as virtual pixels; the shorthand behind `Float32` overloads. */
internal func vpLength(value: Float32): Length {
    Length(value, LengthUnit.Vp)
}
