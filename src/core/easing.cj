package cui.core

import std.math.{cos, sin}
import sdl.clampF32

private let EASE_PI: Float32 = 3.1415927

// The back-easing overshoot constant (the classic 1.70158, ~10% overshoot).
private let BACK_C1: Float32 = 1.70158

/**
 * A timing curve mapping animation progress in `[0, 1]` to eased progress. Standard curves start and
 * end exactly at 0 and 1; `EaseOutBack` overshoots past 1 before settling back to it, and a
 * `CubicBezier` is any CSS-style curve given by its two control points. Feed a curve to an `Animator`,
 * or call `ease` directly to shape any normalised progress.
 *
 * The `In` / `Out` / `InOut` naming follows the convention: `In` accelerates from rest, `Out`
 * decelerates to rest, `InOut` does both. `Quad`/`Cubic`/`Sine` are the underlying polynomials.
 */
public enum Easing {
    | Linear
    | EaseInQuad
    | EaseOutQuad
    | EaseInOutQuad
    | EaseInCubic
    | EaseOutCubic
    | EaseInOutCubic
    | EaseInSine
    | EaseOutSine
    | EaseInOutSine
    | EaseOutBack
    | CubicBezier(Float32, Float32, Float32, Float32)

    /** Maps progress `t` (clamped to `[0, 1]`) to eased progress. */
    public func ease(t: Float32): Float32 {
        let x = clampF32(t, 0.0, 1.0)
        match (this) {
            case Linear => x
            case EaseInQuad => x * x
            case EaseOutQuad => x * (2.0 - x)
            case EaseInOutQuad =>
                if (x < 0.5) {
                    2.0 * x * x
                } else {
                    let f = -2.0 * x + 2.0
                    1.0 - f * f / 2.0
                }
            case EaseInCubic => x * x * x
            case EaseOutCubic =>
                let f = 1.0 - x
                1.0 - f * f * f
            case EaseInOutCubic =>
                if (x < 0.5) {
                    4.0 * x * x * x
                } else {
                    let f = -2.0 * x + 2.0
                    1.0 - f * f * f / 2.0
                }
            case EaseInSine => 1.0 - trigCos(x * EASE_PI / 2.0)
            case EaseOutSine => trigSin(x * EASE_PI / 2.0)
            case EaseInOutSine => -(trigCos(EASE_PI * x) - 1.0) / 2.0
            case EaseOutBack =>
                let c3 = BACK_C1 + 1.0
                let p = x - 1.0
                1.0 + c3 * p * p * p + BACK_C1 * p * p
            case CubicBezier(x1, y1, x2, y2) => cubicBezierEase(x, x1, y1, x2, y2)
        }
    }
}

private func trigCos(radians: Float32): Float32 {
    Float32(cos(Float64(radians)))
}

private func trigSin(radians: Float32): Float32 {
    Float32(sin(Float64(radians)))
}

/*
 * Evaluates a CSS-style cubic-bezier timing function with control points (x1, y1) and (x2, y2)
 * (endpoints are fixed at (0,0) and (1,1)). Progress is the curve's x; we solve for the bezier
 * parameter u where x(u) equals it (Newton-Raphson, then bisection as a fallback), then return y(u).
 * This is the standard WebKit UnitBezier method.
 */
private func cubicBezierEase(x: Float32, x1: Float32, y1: Float32, x2: Float32, y2: Float32): Float32 {
    // Polynomial coefficients for x(u) = ((ax·u + bx)·u + cx)·u and similarly for y.
    let cx = 3.0 * x1
    let bx = 3.0 * (x2 - x1) - cx
    let ax = 1.0 - cx - bx
    let cy = 3.0 * y1
    let by = 3.0 * (y2 - y1) - cy
    let ay = 1.0 - cy - by
    let u = solveBezierParam(x, ax, bx, cx)
    ((ay * u + by) * u + cy) * u
}

private func sampleBezier(u: Float32, a: Float32, b: Float32, c: Float32): Float32 {
    ((a * u + b) * u + c) * u
}

private func sampleBezierDerivative(u: Float32, a: Float32, b: Float32, c: Float32): Float32 {
    (3.0 * a * u + 2.0 * b) * u + c
}

// The bezier parameter u in [0, 1] whose x(u) equals `x`. Newton-Raphson from x as the initial guess,
// then bisection if the slope is too flat to converge.
private func solveBezierParam(x: Float32, ax: Float32, bx: Float32, cx: Float32): Float32 {
    var u = x
    var i = 0
    while (i < 8) {
        let error = sampleBezier(u, ax, bx, cx) - x
        if (absF32(error) < 0.0005) {
            return u
        }
        let slope = sampleBezierDerivative(u, ax, bx, cx)
        if (absF32(slope) < 0.000001) {
            break
        }
        u -= error / slope
        i += 1
    }
    // Bisection fallback over [0, 1].
    var lo: Float32 = 0.0
    var hi: Float32 = 1.0
    var t = x
    while (lo < hi) {
        let value = sampleBezier(t, ax, bx, cx)
        if (absF32(value - x) < 0.0005) {
            return t
        }
        if (x > value) {
            lo = t
        } else {
            hi = t
        }
        t = (lo + hi) / 2.0
        // Guard against a non-terminating loop from float stalls.
        if (hi - lo < 0.00001) {
            break
        }
    }
    t
}

// The absolute value of a Float32; shared by the animation primitives (no std dependency).
internal func absF32(value: Float32): Float32 {
    if (value < 0.0) {
        -value
    } else {
        value
    }
}
