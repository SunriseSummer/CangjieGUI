package sdl.text

import std.collection.HashMap

// Per-point-size capacity of the shaped-text cache before the older generation is retired. A dense
// screen shows on the order of a hundred distinct strings per size; this leaves ample headroom while
// staying bounded against pathological churn (for example a clock or counter that is unique per frame).
internal let SHAPED_TEXT_CACHE_CAP: Int64 = 512

/*
 * A bounded, two-generation cache from string keys to values that own an external resource.
 *
 * The UI tree is rebuilt every frame, so the same strings are drawn over and over; this keeps their
 * already-shaped values alive across frames rather than rebuilding them. When the active generation
 * fills, the older (retired) generation is dropped in one step — running `destroy` on each value it
 * held — and the current active generation becomes the new retired. That bounds live entries to two
 * generations while letting a hot key survive a rotation: a hit in the retired generation is promoted
 * back into active.
 *
 * `destroy` frees whatever a value owns (a native TTF_Text, say). The promote path removes the value
 * from the retired generation BEFORE re-inserting it, so a rotation triggered by that insert can never
 * destroy the value being handed back — the one native-lifetime hazard the two-generation scheme has.
 */
internal class GenerationCache<T> {
    private let capacity: Int64
    private let destroy: (T) -> Unit
    private var active = HashMap<String, T>()
    private var retired = HashMap<String, T>()

    init(capacity: Int64, destroy: (T) -> Unit) {
        this.capacity = max(1, capacity)
        this.destroy = destroy
    }

    // The value for `key`, or None. A hit in the retired generation is promoted back to active so a
    // hot key is not dropped by the next rotation.
    func get(key: String): ?T {
        match (active.get(key)) {
            case Some(value) => return Some(value)
            case None => ()
        }
        match (retired.get(key)) {
            case Some(value) =>
                // Pull it out of retired first: the insert below may rotate, and rotation frees the
                // retired generation — this value must not be in it when that happens.
                let _ = retired.remove(key)
                insert(key, value)
                Some(value)
            case None => None
        }
    }

    // Inserts a freshly created value. The caller is responsible for only calling this on a miss.
    func put(key: String, value: T): Unit {
        insert(key, value)
    }

    private func insert(key: String, value: T): Unit {
        if (active.size >= capacity) {
            rotate()
        }
        active[key] = value
    }

    // Frees the retired generation and makes the current active generation the new retired, so no
    // more than two generations (each at most `capacity`) of live values are ever held.
    private func rotate(): Unit {
        for ((_, value) in retired) {
            destroy(value)
        }
        retired.clear()
        let recycled = retired
        retired = active
        active = recycled
    }

    // Frees every value and empties the cache. Call before discarding the owner.
    func clear(): Unit {
        for ((_, value) in active) {
            destroy(value)
        }
        for ((_, value) in retired) {
            destroy(value)
        }
        active.clear()
        retired.clear()
    }

    // Total live entries across both generations — for tests and diagnostics.
    func size(): Int64 {
        active.size + retired.size
    }
}
