/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package sdl

import std.collection.ArrayList
import std.math.cos
import std.math.sin
import std.math.sqrt

/*
 * GPU mesh painter with analytic anti-aliasing.
 *
 * Shapes are tessellated into triangle meshes whose silhouette carries a thin fringe of
 * vertices faded to alpha zero (the classic feathered-edge technique used by Dear ImGui
 * and vector UI rasterizers). The GPU interpolates that alpha across the fringe, which
 * anti-aliases the exact float outline — no scanline quantization, no seams between
 * overlapping primitives, and translucent colours stay uniform because each shape is a
 * single non-overlapping mesh drawn in one SDL_RenderGeometry call.
 */
private let GEOM_PI: Float64 = 3.141592653589793
private let GEOM_TAU: Float64 = 6.283185307179586

// Width of the anti-aliasing fringe in logical pixels. The fringe straddles the outline
// (half in, half out), so edges stay visually crisp while the gradient kills the stairs.
private let AA_FEATHER: Float32 = 0.7

// Target chord length of one arc segment in logical pixels; shorter chords on larger
// radii keep curve error well under a device pixel once the render scale is applied.
private let ARC_CHORD: Float64 = 1.1

internal class GeometryBatch {
    private var target = CPointer<Unit>()
    private var verts = CPointer<SdlVertex>()
    private var vertCap: Int64 = 0
    private var idxs = CPointer<Int32>()
    private var idxCap: Int64 = 0
    private var vertCount: Int64 = 0
    private var idxCount: Int64 = 0
    private var colR: Float32 = 0.0
    private var colG: Float32 = 0.0
    private var colB: Float32 = 0.0
    private var colA: Float32 = 0.0
    private let pathX = ArrayList<Float32>()
    private let pathY = ArrayList<Float32>()
    private let normX = ArrayList<Float32>()
    private let normY = ArrayList<Float32>()

    func fillRoundedRect(renderer: CPointer<Unit>, rect: Rect, radius: Float32, color: Color): Unit {
        fillRoundedRectSoft(renderer, rect, radius, color, AA_FEATHER)
    }

    /**
     * A rounded rectangle whose edge fades out across `feather` pixels. With the default
     * feather this is a crisp anti-aliased fill; with a wide feather it becomes a smooth
     * gradient halo, which is how soft drop shadows and focus glows are drawn in one pass.
     */
    func fillRoundedRectSoft(
        renderer: CPointer<Unit>,
        rect: Rect,
        radius: Float32,
        color: Color,
        feather: Float32
    ): Unit {
        if (renderer.isNull() || rect.w <= 0.0 || rect.h <= 0.0) {
            return
        }
        buildRoundedRectPath(rect, radius)
        fillPath(renderer, color, clampFeather(feather, min(rect.w, rect.h)))
    }

    func strokeRoundedRect(renderer: CPointer<Unit>, rect: Rect, radius: Float32, pen: Pen): Unit {
        if (renderer.isNull() || rect.w <= 0.0 || rect.h <= 0.0 || pen.width <= 0.0) {
            return
        }
        buildRoundedRectPath(rect, radius)
        strokePath(renderer, pen)
    }

    func fillCircle(renderer: CPointer<Unit>, center: Point, radius: Float32, color: Color): Unit {
        if (renderer.isNull() || radius <= 0.0) {
            return
        }
        buildCirclePath(center, radius, 0)
        fillPath(renderer, color, clampFeather(AA_FEATHER, radius * 2.0))
    }

    func strokeCircle(renderer: CPointer<Unit>, center: Point, radius: Float32, pen: Pen, minSegments: Int64): Unit {
        if (renderer.isNull() || radius <= 0.0 || pen.width <= 0.0) {
            return
        }
        buildCirclePath(center, radius, minSegments)
        strokePath(renderer, pen)
    }

    /**
     * A thick line with round caps, built as a single stadium-shaped fill so consecutive
     * segments of a polyline join without notches or ripple.
     */
    func strokeSegment(renderer: CPointer<Unit>, from: Point, to: Point, pen: Pen): Unit {
        if (renderer.isNull() || pen.width <= 0.0) {
            return
        }
        let radius = pen.width / 2.0
        buildStadiumPath(from, to, radius)
        fillPath(renderer, pen.color, clampFeather(AA_FEATHER, pen.width))
    }

    /**
     * Frees the native vertex/index buffers. Safe to call repeatedly; the batch simply
     * reallocates on next use, so this is called when the owning renderer shuts down.
     */
    func dispose(): Unit {
        if (verts.isNotNull()) {
            unsafe { LibC.free(verts) }
            verts = CPointer<SdlVertex>()
            vertCap = 0
        }
        if (idxs.isNotNull()) {
            unsafe { LibC.free(idxs) }
            idxs = CPointer<Int32>()
            idxCap = 0
        }
    }

    // --- mesh emission ---

    // Fan-fills the current path with a feathered silhouette: an inner ring at full alpha
    // triangulated from its first vertex, and an outer ring at alpha zero joined by a strip.
    private func fillPath(renderer: CPointer<Unit>, color: Color, feather: Float32): Unit {
        let n = pathX.size
        if (n < 3) {
            return
        }
        computeNormals()
        begin(renderer, color, 2 * n, 3 * (n - 2) + 6 * n)
        let half = feather / 2.0
        var i: Int64 = 0
        while (i < n) {
            pushVertex(pathX[i] - normX[i] * half, pathY[i] - normY[i] * half, 1.0)
            i += 1
        }
        i = 0
        while (i < n) {
            pushVertex(pathX[i] + normX[i] * half, pathY[i] + normY[i] * half, 0.0)
            i += 1
        }
        var k: Int64 = 1
        while (k < n - 1) {
            pushTriangle(0, k, k + 1)
            k += 1
        }
        i = 0
        while (i < n) {
            let j = (i + 1) % n
            pushTriangle(i, j, n + j)
            pushTriangle(i, n + j, n + i)
            i += 1
        }
        flush()
    }

    // Strokes the current closed path as a band of four concentric rings: feather-out,
    // solid edge, solid edge, feather-in. Strokes thinner than the feather collapse the
    // solid band and scale peak alpha by coverage, so hairlines stay light instead of lumpy.
    private func strokePath(renderer: CPointer<Unit>, pen: Pen): Unit {
        let n = pathX.size
        if (n < 3) {
            return
        }
        computeNormals()
        let feather = AA_FEATHER
        let solid = max(0.0, (pen.width - feather) / 2.0)
        let peak = min(1.0, pen.width / feather)
        begin(renderer, pen.color, 4 * n, 18 * n)
        pushRing(solid + feather, 0.0)
        pushRing(solid, peak)
        pushRing(-solid, peak)
        pushRing(-(solid + feather), 0.0)
        var ring: Int64 = 0
        while (ring < 3) {
            var i: Int64 = 0
            while (i < n) {
                let j = (i + 1) % n
                let a = ring * n + i
                let b = ring * n + j
                let c = (ring + 1) * n + j
                let d = (ring + 1) * n + i
                pushTriangle(a, b, c)
                pushTriangle(a, c, d)
                i += 1
            }
            ring += 1
        }
        flush()
    }

    private func pushRing(offset: Float32, alpha: Float32): Unit {
        var i: Int64 = 0
        let n = pathX.size
        while (i < n) {
            pushVertex(pathX[i] + normX[i] * offset, pathY[i] + normY[i] * offset, alpha)
            i += 1
        }
    }

    // --- path construction (clockwise in screen coordinates) ---

    private func buildRoundedRectPath(rect: Rect, radius: Float32): Unit {
        pathX.clear()
        pathY.clear()
        let r = min(radius, min(rect.w, rect.h) / 2.0)
        if (r < 0.75) {
            pathAdd(rect.x, rect.y)
            pathAdd(rect.right(), rect.y)
            pathAdd(rect.right(), rect.bottom())
            pathAdd(rect.x, rect.bottom())
            return
        }
        let half = GEOM_PI / 2.0
        pathArc(rect.right() - r, rect.y + r, r, -half, 0.0)
        pathArc(rect.right() - r, rect.bottom() - r, r, 0.0, half)
        pathArc(rect.x + r, rect.bottom() - r, r, half, GEOM_PI)
        pathArc(rect.x + r, rect.y + r, r, GEOM_PI, GEOM_PI + half)
    }

    private func buildCirclePath(center: Point, radius: Float32, minSegments: Int64): Unit {
        pathX.clear()
        pathY.clear()
        let steps = max(arcSteps(radius, GEOM_TAU), minSegments)
        var i: Int64 = 0
        while (i < steps) {
            let t = GEOM_TAU * Float64(i) / Float64(steps)
            pathAdd(center.x + Float32(cos(t)) * radius, center.y + Float32(sin(t)) * radius)
            i += 1
        }
    }

    private func buildStadiumPath(from: Point, to: Point, radius: Float32): Unit {
        let dx = to.x - from.x
        let dy = to.y - from.y
        let length = Float32(sqrt(Float64(dx * dx + dy * dy)))
        if (length < 0.0001) {
            buildCirclePath(from, radius, 0)
            return
        }
        pathX.clear()
        pathY.clear()
        let nx = dy / length
        let ny = -dx / length
        halfCapArc(to, nx, ny, radius)
        halfCapArc(from, -nx, -ny, radius)
    }

    // Appends the half circle that caps a stadium end, rotating the start normal through
    // the segment direction; the straight sides fall out implicitly between the two caps.
    private func halfCapArc(center: Point, startX: Float32, startY: Float32, radius: Float32): Unit {
        let steps = arcSteps(radius, GEOM_PI)
        var i: Int64 = 0
        while (i <= steps) {
            let t = GEOM_PI * Float64(i) / Float64(steps)
            let c = Float32(cos(t))
            let s = Float32(sin(t))
            let vx = startX * c - startY * s
            let vy = startX * s + startY * c
            pathAdd(center.x + vx * radius, center.y + vy * radius)
            i += 1
        }
    }

    private func pathArc(cx: Float32, cy: Float32, radius: Float32, a0: Float64, a1: Float64): Unit {
        let steps = arcSteps(radius, a1 - a0)
        var i: Int64 = 0
        while (i <= steps) {
            let t = a0 + (a1 - a0) * Float64(i) / Float64(steps)
            pathAdd(cx + Float32(cos(t)) * radius, cy + Float32(sin(t)) * radius)
            i += 1
        }
    }

    private func pathAdd(x: Float32, y: Float32): Unit {
        pathX.add(x)
        pathY.add(y)
    }

    private func arcSteps(radius: Float32, sweep: Float64): Int64 {
        let magnitude = if (sweep < 0.0) {
            -sweep
        } else {
            sweep
        }
        let steps = Int64(Float64(max(radius, 0.0)) * magnitude / ARC_CHORD) + 2
        min(max(steps, 3), 64)
    }

    // Per-vertex outward normals: the normalized average of the two adjacent edge normals,
    // oriented outward via the path's signed area so builders need not fix a winding.
    private func computeNormals(): Unit {
        normX.clear()
        normY.clear()
        let n = pathX.size
        var area: Float32 = 0.0
        var i: Int64 = 0
        while (i < n) {
            let j = (i + 1) % n
            area += pathX[i] * pathY[j] - pathX[j] * pathY[i]
            i += 1
        }
        let sign: Float32 = if (area >= 0.0) {
            1.0
        } else {
            -1.0
        }
        i = 0
        while (i < n) {
            let prev = (i + n - 1) % n
            let next = (i + 1) % n
            var mx = edgeNormalX(prev, i) + edgeNormalX(i, next)
            var my = edgeNormalY(prev, i) + edgeNormalY(i, next)
            let length = Float32(sqrt(Float64(mx * mx + my * my)))
            if (length < 0.0001) {
                mx = edgeNormalX(i, next)
                my = edgeNormalY(i, next)
                normX.add(sign * mx)
                normY.add(sign * my)
            } else {
                normX.add(sign * mx / length)
                normY.add(sign * my / length)
            }
            i += 1
        }
    }

    private func edgeNormalX(a: Int64, b: Int64): Float32 {
        let dx = pathX[b] - pathX[a]
        let dy = pathY[b] - pathY[a]
        let length = Float32(sqrt(Float64(dx * dx + dy * dy)))
        if (length < 0.0001) {
            0.0
        } else {
            dy / length
        }
    }

    private func edgeNormalY(a: Int64, b: Int64): Float32 {
        let dx = pathX[b] - pathX[a]
        let dy = pathY[b] - pathY[a]
        let length = Float32(sqrt(Float64(dx * dx + dy * dy)))
        if (length < 0.0001) {
            0.0
        } else {
            -dx / length
        }
    }

    // --- vertex/index buffers ---

    private func begin(renderer: CPointer<Unit>, color: Color, vertNeed: Int64, idxNeed: Int64): Unit {
        target = renderer
        vertCount = 0
        idxCount = 0
        colR = Float32(Int64(color.r)) / 255.0
        colG = Float32(Int64(color.g)) / 255.0
        colB = Float32(Int64(color.b)) / 255.0
        colA = Float32(Int64(color.a)) / 255.0
        ensureCapacity(vertNeed, idxNeed)
    }

    private func ensureCapacity(vertNeed: Int64, idxNeed: Int64): Unit {
        if (vertNeed > vertCap) {
            if (verts.isNotNull()) {
                unsafe { LibC.free(verts) }
            }
            vertCap = max(vertNeed, max(vertCap * 2, 256))
            verts = unsafe { LibC.malloc<SdlVertex>(count: vertCap) }
            if (verts.isNull()) {
                vertCap = 0
            }
        }
        if (idxNeed > idxCap) {
            if (idxs.isNotNull()) {
                unsafe { LibC.free(idxs) }
            }
            idxCap = max(idxNeed, max(idxCap * 2, 1024))
            idxs = unsafe { LibC.malloc<Int32>(count: idxCap) }
            if (idxs.isNull()) {
                idxCap = 0
            }
        }
    }

    private func pushVertex(x: Float32, y: Float32, alpha: Float32): Unit {
        if (vertCount >= vertCap) {
            return
        }
        var vertex = SdlVertex()
        vertex.px = x
        vertex.py = y
        vertex.colR = colR
        vertex.colG = colG
        vertex.colB = colB
        vertex.colA = colA * alpha
        unsafe { verts.write(vertCount, vertex) }
        vertCount += 1
    }

    private func pushTriangle(a: Int64, b: Int64, c: Int64): Unit {
        if (idxCount + 3 > idxCap) {
            return
        }
        unsafe {
            idxs.write(idxCount, Int32(a))
            idxs.write(idxCount + 1, Int32(b))
            idxs.write(idxCount + 2, Int32(c))
        }
        idxCount += 3
    }

    private func flush(): Unit {
        if (idxCount == 0 || target.isNull() || verts.isNull() || idxs.isNull()) {
            return
        }
        let _ = unsafe {
            SDL_RenderGeometry(target, CPointer<Unit>(), verts, Int32(vertCount), idxs, Int32(idxCount))
        }
    }
}

private func clampFeather(feather: Float32, minDimension: Float32): Float32 {
    max(0.1, min(feather, minDimension * 0.9))
}
