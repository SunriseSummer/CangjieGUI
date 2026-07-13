package sdl.text

import std.collection.ArrayList

// A stand-in for a resource-owning cache value, so the two-generation eviction — including the
// promote-safety hazard, where a hit in the retired generation must not be freed by the rotation
// that same insert triggers — can be verified without a GPU or SDL_ttf.
class Probe {
    let id: Int64

    init(id: Int64) {
        this.id = id
    }
}

private func has(freed: ArrayList<Int64>, id: Int64): Bool {
    for (x in freed) {
        if (x == id) {
            return true
        }
    }
    false
}

@Test
func generationCacheReturnsMissThenHit(): Unit {
    let freed = ArrayList<Int64>()
    let cache = GenerationCache<Probe>(4) {p => freed.add(p.id)}
    @Expect(cache.get("a").isNone())
    cache.put("a", Probe(1))
    @Expect(cache.get("a").getOrThrow().id, 1)
    // A hit frees nothing.
    @Expect(freed.size, 0)
}

/*
 * A key promoted out of the retired generation must survive the very rotation its re-insert
 * triggers. With capacity 2: filling past 2 rotates {a,b} into retired; touching "a" promotes it
 * back to active; the next rotation must free the still-cold "b" but NOT the promoted "a".
 */
@Test
func generationCachePromotesHotKeyPastRotation(): Unit {
    let freed = ArrayList<Int64>()
    let cache = GenerationCache<Probe>(2) {p => freed.add(p.id)}
    cache.put("a", Probe(1))
    cache.put("b", Probe(2))
    cache.put("c", Probe(3)) // rotate: active {a,b} -> retired, active {c}; nothing freed yet
    @Expect(freed.size, 0)

    @Expect(cache.get("a").getOrThrow().id, 1) // promote a: retired {b}, active {c,a}
    cache.put("d", Probe(4)) // rotate: frees retired {b} only; a survived in active
    @Expect(has(freed, 2), true)
    @Expect(has(freed, 1), false)
    @Expect(freed.size, 1)
}

/*
 * Every value is freed exactly once across a churn of rotations plus a final clear — no leak (missing
 * id) and no double free (a count above the number created).
 */
@Test
func generationCacheFreesEveryValueExactlyOnce(): Unit {
    let freed = ArrayList<Int64>()
    let cache = GenerationCache<Probe>(2) {p => freed.add(p.id)}
    var id = 1
    while (id <= 7) {
        cache.put("k${id}", Probe(id))
        id += 1
    }
    cache.clear()
    // All seven created, each freed once: total frees == 7 and every id present.
    @Expect(freed.size, 7)
    var check = 1
    while (check <= 7) {
        @Expect(has(freed, check), true)
        check += 1
    }
    @Expect(cache.size(), 0)
}
