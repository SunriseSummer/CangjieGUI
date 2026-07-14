package sdl

import std.collection.ArrayList
import std.collection.HashMap
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

// Distinct mesh kinds so shapes of the same size but different construction cache separately. Packed
// into the low 2 bits of the mesh key, so up to four kinds.
internal let MESH_KIND_FILL: Int64 = 0
private let MESH_KIND_STROKE: Int64 = 1
private let MESH_KIND_CIRCLE_FILL: Int64 = 2
private let MESH_KIND_CIRCLE_STROKE: Int64 = 3

// How many distinct shape meshes to retain before the older generation is dropped. A UI reuses a
// small set of shapes (a few panel/card/chip sizes, each with a fill, a border and two shadow
// layers), so this is ample; a churning shape (an animated size) simply misses and re-tessellates
// as before, bounded by the two-generation eviction.
private let MESH_CACHE_CAP: Int64 = 256

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
    // Tessellated shape meshes in local coordinates (origin at 0,0), keyed by shape and size. A
    // scrolling panel keeps the same shape and only changes position, so its mesh is built once and
    // thereafter merely translated and coloured — turning per-frame arc/normal tessellation (the CPU
    // cost that dominates a content page) into a cheap vertex copy.
    private let meshCache = MeshCache(MESH_CACHE_CAP) {mesh => mesh.free()}

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
        let f = clampFeather(feather, min(rect.w, rect.h))
        // A cached mesh is built in local coordinates and reused across frames and across same-size
        // shapes; only extreme sizes (outside the key budget) fall back to per-call tessellation.
        if (withinKeyBudget(rect.w, rect.h, radius, f)) {
            let key = meshKey(MESH_KIND_FILL, rect.w, rect.h, radius, f)
            let mesh = match (meshCache.get(key)) {
                case Some(existing) => existing
                case None =>
                    buildRoundedRectPath(Rect(0.0, 0.0, rect.w, rect.h), radius)
                    let built = buildFillMesh(f)
                    meshCache.put(key, built)
                    built
            }
            emitMesh(renderer, mesh, rect.x, rect.y, color)
        } else {
            buildRoundedRectPath(rect, radius)
            fillPath(renderer, color, f)
        }
    }

    func strokeRoundedRect(renderer: CPointer<Unit>, rect: Rect, radius: Float32, pen: Pen): Unit {
        if (renderer.isNull() || rect.w <= 0.0 || rect.h <= 0.0 || pen.width <= 0.0) {
            return
        }
        if (withinKeyBudget(rect.w, rect.h, radius, pen.width)) {
            let key = meshKey(MESH_KIND_STROKE, rect.w, rect.h, radius, pen.width)
            let mesh = match (meshCache.get(key)) {
                case Some(existing) => existing
                case None =>
                    buildRoundedRectPath(Rect(0.0, 0.0, rect.w, rect.h), radius)
                    let built = buildStrokeMesh(pen)
                    meshCache.put(key, built)
                    built
            }
            emitMesh(renderer, mesh, rect.x, rect.y, pen.color)
        } else {
            buildRoundedRectPath(rect, radius)
            strokePath(renderer, pen)
        }
    }

    func fillCircle(renderer: CPointer<Unit>, center: Point, radius: Float32, color: Color): Unit {
        if (renderer.isNull() || radius <= 0.0) {
            return
        }
        let feather = clampFeather(AA_FEATHER, radius * 2.0)
        // Cache the circle mesh in local coordinates (centre at origin) and translate to `center` on
        // emit — knobs, dots and thumbs are the same handful of radii, so this is nearly all hits.
        if (withinKeyBudget(radius, 0.0, 0.0, feather)) {
            let key = meshKey(MESH_KIND_CIRCLE_FILL, radius, 0.0, 0.0, feather)
            let mesh = match (meshCache.get(key)) {
                case Some(existing) => existing
                case None =>
                    buildCirclePath(Point(0.0, 0.0), radius, 0)
                    let built = buildFillMesh(feather)
                    meshCache.put(key, built)
                    built
            }
            emitMesh(renderer, mesh, center.x, center.y, color)
        } else {
            buildCirclePath(center, radius, 0)
            fillPath(renderer, color, feather)
        }
    }

    func strokeCircle(renderer: CPointer<Unit>, center: Point, radius: Float32, pen: Pen, minSegments: Int64): Unit {
        if (renderer.isNull() || radius <= 0.0 || pen.width <= 0.0) {
            return
        }
        // The segment count changes the mesh, so it is part of the key (packed as the height field).
        if (withinKeyBudget(radius, Float32(minSegments), 0.0, pen.width)) {
            let key = meshKey(MESH_KIND_CIRCLE_STROKE, radius, Float32(minSegments), 0.0, pen.width)
            let mesh = match (meshCache.get(key)) {
                case Some(existing) => existing
                case None =>
                    buildCirclePath(Point(0.0, 0.0), radius, minSegments)
                    let built = buildStrokeMesh(pen)
                    meshCache.put(key, built)
                    built
            }
            emitMesh(renderer, mesh, center.x, center.y, pen.color)
        } else {
            buildCirclePath(center, radius, minSegments)
            strokePath(renderer, pen)
        }
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
     * Draws a textured triangle strip. `points` holds consecutive (left, right) vertex
     * pairs along the strip; `texPoints` holds matching texture coordinates in source
     * pixels, normalized here against the texture size. `alphas` optionally fades each
     * vertex (used to cross-fade overlapping skinned parts); vertex colours stay white so
     * the texture is otherwise sampled unmodified. Invalid sizes draw nothing.
     */
    func texturedStrip(
        renderer: CPointer<Unit>,
        texture: CPointer<Unit>,
        points: ArrayList<Point>,
        texPoints: ArrayList<Point>,
        alphas: ?ArrayList<Float32>,
        texWidth: Float32,
        texHeight: Float32
    ): Unit {
        let count = points.size
        var isStrip = count >= 4 && count % 2 == 0 && texPoints.size == count
        if (let Some(values) <- alphas) {
            isStrip = isStrip && values.size == count
        }
        if (renderer.isNull() || texture.isNull() || !isStrip || texWidth <= 0.0 || texHeight <= 0.0) {
            return
        }
        let rungs = count / 2
        begin(renderer, Color.rgb(255, 255, 255), count, 6 * (rungs - 1))
        var i: Int64 = 0
        while (i < count) {
            let alpha: Float32 = match (alphas) {
                case Some(values) => values[i]
                case None => Float32(1.0)
            }
            pushTexturedVertex(points[i].x, points[i].y, texPoints[i].x / texWidth, texPoints[i].y / texHeight, alpha)
            i += 1
        }
        var rung: Int64 = 0
        while (rung < rungs - 1) {
            let a = rung * 2
            pushTriangle(a, a + 1, a + 3)
            pushTriangle(a, a + 3, a + 2)
            rung += 1
        }
        flushWith(texture)
    }

    /**
     * Frees the native vertex/index buffers. Safe to call repeatedly; the batch simply
     * reallocates on next use, so this is called when the owning renderer shuts down.
     */
    func dispose(): Unit {
        meshCache.freeAll()
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

    // --- cached-mesh emission ---
    //
    // The build* methods below produce a CachedMesh from the CURRENT path (in local coordinates,
    // built at the origin) with the identical topology as fillPath/strokePath, but storing relative
    // positions and per-vertex alpha instead of writing straight to the GPU buffer. emitMesh then
    // translates and colours the stored mesh into the buffer. Splitting build from emit is what lets
    // the expensive tessellation be memoized while position and colour still vary per call.

    // Builds the feathered fill mesh (inner ring at full alpha, outer fringe at alpha zero) for the
    // current path. Mirrors fillPath's topology exactly.
    private func buildFillMesh(feather: Float32): CachedMesh {
        computeNormals()
        let n = pathX.size
        let half = feather / 2.0
        let mpx = ArrayList<Float32>()
        let mpy = ArrayList<Float32>()
        let malpha = ArrayList<Float32>()
        var i: Int64 = 0
        while (i < n) {
            mpx.add(pathX[i] - normX[i] * half)
            mpy.add(pathY[i] - normY[i] * half)
            malpha.add(1.0)
            i += 1
        }
        i = 0
        while (i < n) {
            mpx.add(pathX[i] + normX[i] * half)
            mpy.add(pathY[i] + normY[i] * half)
            malpha.add(0.0)
            i += 1
        }
        let mi = ArrayList<Int32>()
        var k: Int64 = 1
        while (k < n - 1) {
            addTri(mi, 0, k, k + 1)
            k += 1
        }
        i = 0
        while (i < n) {
            let j = (i + 1) % n
            addTri(mi, i, j, n + j)
            addTri(mi, i, n + j, n + i)
            i += 1
        }
        materializeMesh(mpx, mpy, malpha, mi)
    }

    // Builds the four-ring stroke mesh (feather-out, solid, solid, feather-in) for the current path.
    // Mirrors strokePath's topology exactly.
    private func buildStrokeMesh(pen: Pen): CachedMesh {
        computeNormals()
        let n = pathX.size
        let feather = AA_FEATHER
        let solid = max(0.0, (pen.width - feather) / 2.0)
        let peak = min(1.0, pen.width / feather)
        let mpx = ArrayList<Float32>()
        let mpy = ArrayList<Float32>()
        let malpha = ArrayList<Float32>()
        appendRing(mpx, mpy, malpha, solid + feather, 0.0)
        appendRing(mpx, mpy, malpha, solid, peak)
        appendRing(mpx, mpy, malpha, -solid, peak)
        appendRing(mpx, mpy, malpha, -(solid + feather), 0.0)
        let mi = ArrayList<Int32>()
        var ring: Int64 = 0
        while (ring < 3) {
            var i: Int64 = 0
            while (i < n) {
                let j = (i + 1) % n
                let a = ring * n + i
                let b = ring * n + j
                let c = (ring + 1) * n + j
                let d = (ring + 1) * n + i
                addTri(mi, a, b, c)
                addTri(mi, a, c, d)
                i += 1
            }
            ring += 1
        }
        materializeMesh(mpx, mpy, malpha, mi)
    }

    // Copies a freshly tessellated mesh (built in the local ArrayLists) into native vertex and index
    // buffers owned by the CachedMesh. Relative position goes in px/py and coverage in colA; the RGB
    // is filled per draw in emitMesh. Runs only on a cache miss, so the copy cost is paid once.
    private func materializeMesh(
        mpx: ArrayList<Float32>,
        mpy: ArrayList<Float32>,
        malpha: ArrayList<Float32>,
        mi: ArrayList<Int32>
    ): CachedMesh {
        let vc = mpx.size
        let ic = mi.size
        let nativeVerts = unsafe { LibC.malloc<SdlVertex>(count: max(1, vc)) }
        let nativeIdx = unsafe { LibC.malloc<Int32>(count: max(1, ic)) }
        if (nativeVerts.isNull() || nativeIdx.isNull()) {
            if (nativeVerts.isNotNull()) {
                unsafe { LibC.free(nativeVerts) }
            }
            if (nativeIdx.isNotNull()) {
                unsafe { LibC.free(nativeIdx) }
            }
            return CachedMesh(CPointer<SdlVertex>(), CPointer<Int32>(), 0, 0)
        }
        var i: Int64 = 0
        while (i < vc) {
            var vertex = SdlVertex()
            vertex.px = mpx[i]
            vertex.py = mpy[i]
            vertex.colA = malpha[i]
            unsafe { nativeVerts.write(i, vertex) }
            i += 1
        }
        i = 0
        while (i < ic) {
            unsafe { nativeIdx.write(i, mi[i]) }
            i += 1
        }
        CachedMesh(nativeVerts, nativeIdx, vc, ic)
    }

    // Appends one offset ring of the current path (positions + a flat alpha) to a mesh under build.
    private func appendRing(
        mpx: ArrayList<Float32>,
        mpy: ArrayList<Float32>,
        malpha: ArrayList<Float32>,
        offset: Float32,
        alpha: Float32
    ): Unit {
        var i: Int64 = 0
        let n = pathX.size
        while (i < n) {
            mpx.add(pathX[i] + normX[i] * offset)
            mpy.add(pathY[i] + normY[i] * offset)
            malpha.add(alpha)
            i += 1
        }
    }

    // Emits a cached mesh translated by (dx, dy) and tinted `color`: the cheap per-frame path that
    // replaces re-tessellation. Colour is applied here (via begin), so one mesh serves every colour.
    private func emitMesh(renderer: CPointer<Unit>, mesh: CachedMesh, dx: Float32, dy: Float32, color: Color): Unit {
        let vc = mesh.vertCount
        let ic = mesh.idxCount
        if (vc == 0 || ic == 0 || renderer.isNull() || mesh.relVerts.isNull() || mesh.indices.isNull()) {
            return
        }
        // Grow the shared output buffer, then translate + colour the cached relative vertices into it
        // with a tight native loop (no bounds checks, no per-vertex allocation). The index buffer is
        // invariant, so it is handed to SDL straight from the cached mesh — no per-frame index copy.
        ensureCapacity(vc, 0)
        if (verts.isNull()) {
            return
        }
        let cr = Float32(Int64(color.r)) / 255.0
        let cg = Float32(Int64(color.g)) / 255.0
        let cb = Float32(Int64(color.b)) / 255.0
        let ca = Float32(Int64(color.a)) / 255.0
        var i: Int64 = 0
        while (i < vc) {
            var vertex = unsafe { mesh.relVerts.read(i) }
            vertex.px = vertex.px + dx
            vertex.py = vertex.py + dy
            // The mesh stores per-vertex coverage (0..1 feather alpha) in colA; fold in the draw colour.
            vertex.colA = ca * vertex.colA
            vertex.colR = cr
            vertex.colG = cg
            vertex.colB = cb
            unsafe { verts.write(i, vertex) }
            i += 1
        }
        let _ = unsafe {
            SDL_RenderGeometry(renderer, CPointer<Unit>(), verts, Int32(vc), mesh.indices, Int32(ic))
        }
    }

    private func addTri(indices: ArrayList<Int32>, a: Int64, b: Int64, c: Int64): Unit {
        indices.add(Int32(a))
        indices.add(Int32(b))
        indices.add(Int32(c))
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

    private func pushTexturedVertex(x: Float32, y: Float32, u: Float32, v: Float32, alpha: Float32): Unit {
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
        vertex.tu = u
        vertex.tv = v
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
        flushWith(CPointer<Unit>())
    }

    private func flushWith(texture: CPointer<Unit>): Unit {
        if (idxCount == 0 || target.isNull() || verts.isNull() || idxs.isNull()) {
            return
        }
        let _ = unsafe {
            SDL_RenderGeometry(target, texture, verts, Int32(vertCount), idxs, Int32(idxCount))
        }
    }
}

private func clampFeather(feather: Float32, minDimension: Float32): Float32 {
    max(0.1, min(feather, minDimension * 0.9))
}

// Quantizes a length to quarter-pixel units for mesh keying, TRUNCATING rather than rounding. The
// truncation is deliberate: withinKeyBudget bounds each field with an exclusive upper limit at a
// power of two, and floor keeps the largest in-budget value at exactly 2^bits - 1, so a boundary
// value can never carry a bit into the adjacent packed field (rounding with +0.5 would turn, say,
// radius 511.9 into 2048 and overflow the 11-bit radius field into `extra`). Sub-quarter-pixel size
// differences share a mesh — an imperceptible size rounding, while the draw position stays exact.
internal func quantizeLength(value: Float32): Int64 {
    Int64(value * 4.0)
}

// True when a shape's dimensions fit the packed key's bit budget. An out-of-range shape bypasses the
// cache and tessellates directly, so an extreme size can never alias onto another shape's mesh.
private func withinKeyBudget(w: Float32, h: Float32, radius: Float32, extra: Float32): Bool {
    w >= 0.0 && w < 8192.0 && h >= 0.0 && h < 8192.0 && radius >= 0.0 && radius < 512.0 && extra >= 0.0 && extra < 64.0
}

// Packs (kind, width, height, radius, extra) into one Int64 cache key. Field widths: kind 2 bits,
// width/height 15 bits each (quarter-pixel, < 8192px), radius 11 bits (< 512px), extra 8 bits
// (< 64px) — 51 bits total. withinKeyBudget bounds each length and quantizeLength truncates, so every
// field stays at or below 2^width - 1 and distinct shapes never collide onto one key.
internal func meshKey(kind: Int64, w: Float32, h: Float32, radius: Float32, extra: Float32): Int64 {
    let qw = quantizeLength(w)
    let qh = quantizeLength(h)
    let qr = quantizeLength(radius)
    let qe = quantizeLength(extra)
    kind | (qw << 2) | (qh << 17) | (qr << 32) | (qe << 43)
}

// A tessellated shape in local coordinates, held in native buffers so per-frame emit is a tight
// unsafe loop: relative positions live in each vertex's px/py and the feather coverage in its colA
// (the draw colour is folded in at emit); the index buffer is invariant and handed straight to SDL.
internal class CachedMesh {
    let relVerts: CPointer<SdlVertex>
    let indices: CPointer<Int32>
    let vertCount: Int64
    let idxCount: Int64

    init(relVerts: CPointer<SdlVertex>, indices: CPointer<Int32>, vertCount: Int64, idxCount: Int64) {
        this.relVerts = relVerts
        this.indices = indices
        this.vertCount = vertCount
        this.idxCount = idxCount
    }

    // Frees the native buffers. Called when the mesh is evicted from the cache or the batch disposes.
    func free(): Unit {
        if (relVerts.isNotNull()) {
            unsafe { LibC.free(relVerts) }
        }
        if (indices.isNotNull()) {
            unsafe { LibC.free(indices) }
        }
    }
}

// A bounded, two-generation cache of shape meshes. When the active generation fills, the older
// (retired) generation is dropped whole — running `destroy` on each mesh — and the current one
// becomes retired; a hit in the retired generation is promoted back so a hot shape survives a
// rotation. Because the meshes own native buffers, the promote path removes the mesh from the retired
// generation BEFORE re-inserting it, so the rotation that insert may trigger cannot destroy the mesh
// being returned — the same native-lifetime safeguard as the shaped-text cache. `destroy` is injected
// (production frees the native buffers) so the eviction bookkeeping is unit-testable without a GPU.
internal class MeshCache {
    private let capacity: Int64
    private let destroy: (CachedMesh) -> Unit
    private var active = HashMap<Int64, CachedMesh>()
    private var retired = HashMap<Int64, CachedMesh>()

    init(capacity: Int64, destroy: (CachedMesh) -> Unit) {
        this.capacity = max(1, capacity)
        this.destroy = destroy
    }

    func get(key: Int64): ?CachedMesh {
        match (active.get(key)) {
            case Some(mesh) => return Some(mesh)
            case None => ()
        }
        match (retired.get(key)) {
            case Some(mesh) =>
                let _ = retired.remove(key)
                insert(key, mesh)
                Some(mesh)
            case None => None
        }
    }

    func put(key: Int64, mesh: CachedMesh): Unit {
        insert(key, mesh)
    }

    // Destroys every cached mesh across both generations. Called when the owning batch is disposed.
    func freeAll(): Unit {
        destroyGeneration(active)
        active.clear()
        destroyGeneration(retired)
        retired.clear()
    }

    // Live entries across both generations — for tests and diagnostics.
    func size(): Int64 {
        active.size + retired.size
    }

    private func insert(key: Int64, mesh: CachedMesh): Unit {
        if (active.size >= capacity) {
            destroyGeneration(retired)
            retired.clear()
            let recycled = retired
            retired = active
            active = recycled
        }
        active[key] = mesh
    }

    private func destroyGeneration(generation: HashMap<Int64, CachedMesh>): Unit {
        for ((_, mesh) in generation) {
            destroy(mesh)
        }
    }
}
