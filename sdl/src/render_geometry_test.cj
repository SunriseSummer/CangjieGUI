package sdl

import std.collection.ArrayList

// A mesh with null native buffers: the two-generation eviction bookkeeping — including the
// promote-safety hazard where a hit in the retired generation must not be freed by the rotation its
// own re-insert triggers — is what is under test, not the buffers themselves.
private func fakeMesh(): CachedMesh {
    CachedMesh(CPointer<SdlVertex>(), CPointer<Int32>(), 0, 0)
}

// A mesh key field must never carry a bit into the adjacent field at a budget boundary. Rounding
// (the earlier +0.5) turned radius 511.9 into 2048, overflowing the 11-bit radius field into `extra`
// and aliasing a nearly-round rect onto a sharp-cornered one; truncation keeps every field in budget.
@Test
func meshKeyFieldsStayWithinBudgetAtBoundaries(): Unit {
    // Largest in-budget length per field must fit: radius 11 bits (<=2047), w/h 15 bits (<=32767),
    // extra 8 bits (<=255).
    @Expect(quantizeLength(511.9) <= 2047, true)
    @Expect(quantizeLength(8191.9) <= 32767, true)
    @Expect(quantizeLength(63.9) <= 255, true)
    // The two shapes the overflow previously aliased must now key distinctly: a near-512 radius vs a
    // sharp corner whose feather is one quarter-pixel larger.
    let roundedBig = meshKey(MESH_KIND_FILL, 1024.0, 1024.0, 511.9, 4.0)
    let sharpCorner = meshKey(MESH_KIND_FILL, 1024.0, 1024.0, 0.1, 4.25)
    @Expect(roundedBig != sharpCorner, true)
}

@Test
func meshCachePromotesHotKeyPastRotation(): Unit {
    let destroyed = ArrayList<CachedMesh>()
    let cache = MeshCache(2) {mesh => destroyed.add(mesh)}
    let a = fakeMesh()
    let b = fakeMesh()
    let c = fakeMesh()
    let d = fakeMesh()
    cache.put(1, a)
    cache.put(2, b)
    cache.put(3, c) // rotate: {1,2} -> retired, active {3}; nothing destroyed yet
    @Expect(destroyed.size, 0)

    // Promote key 1 out of the retired generation.
    match (cache.get(1)) {
        case Some(mesh) => @Expect(refEq(mesh, a), true)
        case None => @Expect(false, true)
    }
    cache.put(4, d) // rotate: frees the still-cold retired {2} only; the promoted 1 survived in active
    @Expect(destroyed.size, 1)
    @Expect(refEq(destroyed[0], b), true)

    var aFreed = false
    for (mesh in destroyed) {
        if (refEq(mesh, a)) {
            aFreed = true
        }
    }
    @Expect(aFreed, false)
}

@Test
func meshCacheDestroysEveryMeshExactlyOnce(): Unit {
    let destroyed = ArrayList<CachedMesh>()
    let cache = MeshCache(2) {mesh => destroyed.add(mesh)}
    let meshes = ArrayList<CachedMesh>()
    var i = 1
    while (i <= 7) {
        let mesh = fakeMesh()
        meshes.add(mesh)
        cache.put(Int64(i), mesh)
        i += 1
    }
    cache.freeAll()
    // All seven created, each destroyed exactly once — no leak (a missing mesh) and no double free.
    @Expect(destroyed.size, 7)
    for (mesh in meshes) {
        var count = 0
        for (freed in destroyed) {
            if (refEq(freed, mesh)) {
                count += 1
            }
        }
        @Expect(count, 1)
    }
    @Expect(cache.size(), 0)
}
