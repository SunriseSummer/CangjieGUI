package cui.controls

import std.collection.ArrayList
import std.math.{cos, sin}
import sdl.{FontSizes, Pen, Point, Rect, Size, UiEvent}
import cui.core.{UiContext, Widget, emit}

private let RING_PI: Float64 = 3.141592653589793
private let RING_TAU: Float64 = 6.283185307179586
// Segment count for a full ring; a partial arc uses proportionally fewer.
private let RING_SEGMENTS: Int64 = 64

/*
 * A circular progress indicator — a track ring with a foreground arc sweeping clockwise from the top to
 * `value` (a 0…1 fraction, clamped), optionally with a centered percentage. Pure display; the arc is a
 * round-capped polyline so it reads smoothly at any size. It complements the linear `ProgressBar`.
 */
public class ProgressRing <: Widget {
    private let value: Float32
    private let diameter: Float32
    private let thickness: Float32
    private let showLabel: Bool
    private var frame = Rect.zero()

    public init(value: Float32, diameter!: Float32 = 72.0, thickness!: Float32 = 8.0, showLabel!: Bool = true) {
        this.value = value
        this.diameter = max(24.0, diameter)
        this.thickness = max(2.0, thickness)
        this.showLabel = showLabel
        emit(this)
    }

    public func measure(_: UiContext, _: Size): Size {
        Size(diameter, diameter)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func isFlexible(): Bool {
        false
    }

    public func draw(ctx: UiContext): Unit {
        let frac = clampFraction(value)
        let cx = frame.centerX()
        let cy = frame.centerY()
        let radius = (min(frame.w, frame.h) - thickness) / 2.0
        // Track: a faint full ring behind the progress arc.
        ctx.renderer.strokeCircle(cx, cy, radius, Pen(width: thickness, color: ctx.theme.mutedText.withAlpha(42)))
        drawArc(ctx, cx, cy, radius, frac)
        if (showLabel) {
            // Round to the nearest percent — truncation would show 69% for an exact 0.7 (whose nearest
            // Float32 sits just below it).
            let text = "${Int64(frac * 100.0 + 0.5)}%"
            let tw = ctx.renderer.textWidth(text, pointSize: FontSizes.CONTROL)
            let ty = cy - ctx.renderer.textHeight(pointSize: FontSizes.CONTROL) / 2.0
            ctx.renderer.text(text, cx - tw / 2.0, ty, ctx.theme.text, pointSize: FontSizes.CONTROL)
        }
    }

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }

    private func drawArc(ctx: UiContext, cx: Float32, cy: Float32, radius: Float32, fraction: Float32): Unit {
        if (fraction <= 0.0) {
            return
        }
        let points = ringArcPoints(cx, cy, radius, fraction)
        let pen = Pen(width: thickness, color: ctx.theme.accent)
        var i = 1
        while (i < points.size) {
            ctx.renderer.strokeLine(points[i - 1].x, points[i - 1].y, points[i].x, points[i].y, pen)
            i += 1
        }
    }
}

internal func clampFraction(value: Float32): Float32 {
    if (value < 0.0) {
        0.0
    } else if (value > 1.0) {
        1.0
    } else {
        value
    }
}

/*
 * The polyline points of a progress arc: sweeping clockwise from the 12-o'clock top through
 * `fraction` of a full turn. `fraction` 0.25 ends at 3 o'clock, 0.5 at the bottom, 1.0 back at the top.
 * The segment count scales with the fraction so short arcs are not over-tessellated.
 */
internal func ringArcPoints(cx: Float32, cy: Float32, radius: Float32, fraction: Float32): Array<Point> {
    let f = clampFraction(fraction)
    let segments = max(2, Int64(Float32(RING_SEGMENTS) * f + 0.5))
    let points = ArrayList<Point>()
    var i = 0
    while (i <= segments) {
        let t = Float64(i) / Float64(segments) // 0…1 along the arc
        let angle = -RING_PI / 2.0 + RING_TAU * Float64(f) * t // from the top, clockwise
        points.add(Point(cx + Float32(cos(angle)) * radius, cy + Float32(sin(angle)) * radius))
        i += 1
    }
    points.toArray()
}
