package cui.media

import std.collection.HashMap

/* One entry in the media cache's weighted, doubly-linked LRU list. */
internal class BoundedResourceCacheEntry<T> {
    let key: String
    let cached: ?T
    let weight: UInt64
    var previous: ?BoundedResourceCacheEntry<T> = None
    var next: ?BoundedResourceCacheEntry<T> = None
    var active = true
    var recentlyUsed = false

    init(key: String, cached: ?T, weight: UInt64) {
        this.key = key
        this.cached = cached
        this.weight = weight
    }
}

/*
 * An entry- and byte-bounded weighted LRU for resources with deterministic disposal. Ordinary
 * lookup maintains exact order; an external lock-free fast path may mark one-shot second chances.
 * Cached failures use `None` values and still consume entry metadata, so a stream of bad paths
 * cannot grow without bound. One value larger than the byte budget is retained alone: dropping it
 * would force the caller to reload the same large image every frame, which is both slower and more
 * memory-hungry.
 */
internal class BoundedResourceCache<T> {
    private let entryLimit: Int64
    private let byteLimit: UInt64
    private let dispose: (T) -> Unit
    private let entries: HashMap<String, BoundedResourceCacheEntry<T>>
    private var head: ?BoundedResourceCacheEntry<T> = None
    private var tail: ?BoundedResourceCacheEntry<T> = None
    private var last: ?BoundedResourceCacheEntry<T> = None
    private var bytes: UInt64 = UInt64(0)
    private var evictions: UInt64 = UInt64(0)
    private var oversizedAdmissions: UInt64 = UInt64(0)

    init(entryLimit: Int64, byteLimit: UInt64, dispose: (T) -> Unit) {
        this.entryLimit = max(Int64(1), entryLimit)
        this.byteLimit = byteLimit
        this.dispose = dispose
        this.entries = HashMap<String, BoundedResourceCacheEntry<T>>(this.entryLimit)
    }

    func lookup(key: String): ?BoundedResourceCacheEntry<T> {
        match (last) {
            case Some(entry) =>
                if (entry.key == key) {
                    return Some(entry)
                }
            case None => ()
        }
        match (entries.get(key)) {
            case Some(entry) =>
                promote(entry)
                last = Some(entry)
                Some(entry)
            case None => None
        }
    }

    func put(key: String, cached: ?T, weight: UInt64): Unit {
        let _ = remove(key) // cjcheck-ignore: ignore-result # replacement is valid whether or not the key existed
        let entry = BoundedResourceCacheEntry<T>(key, cached, weight)
        entries[key] = entry
        linkFirst(entry)
        last = Some(entry)
        bytes = saturatedMediaAdd(bytes, weight)
        if (weight > byteLimit) {
            oversizedAdmissions += UInt64(1)
        }
        trim(entry)
    }

    func remove(key: String): Bool {
        match (entries.remove(key)) {
            case Some(entry) =>
                unlink(entry)
                release(entry)
                true
            case None => false
        }
    }

    func clear(): Unit {
        for ((_, entry) in entries) {
            entry.active = false
            releaseValue(entry)
        }
        entries.clear()
        head = None
        tail = None
        last = None
        bytes = UInt64(0)
    }

    func size(): Int64 {
        entries.size
    }

    func estimatedBytes(): UInt64 {
        bytes
    }

    func evictionCount(): UInt64 {
        evictions
    }

    func oversizedAdmissionCount(): UInt64 {
        oversizedAdmissions
    }

    func maxEntries(): Int64 {
        entryLimit
    }

    func maxBytes(): UInt64 {
        byteLimit
    }

    private func promote(entry: BoundedResourceCacheEntry<T>): Unit {
        if (!isHead(entry)) {
            unlink(entry)
            linkFirst(entry)
        }
    }

    private func linkFirst(entry: BoundedResourceCacheEntry<T>): Unit {
        let previousHead = head
        entry.previous = None
        entry.next = previousHead
        head = Some(entry)
        match (previousHead) {
            case Some(current) => current.previous = Some(entry)
            case None => tail = Some(entry)
        }
    }

    private func unlink(entry: BoundedResourceCacheEntry<T>): Unit {
        let previous = entry.previous
        let next = entry.next
        reconnectPrevious(previous, next)
        reconnectNext(next, previous)
        entry.previous = None
        entry.next = None
    }

    private func isHead(entry: BoundedResourceCacheEntry<T>): Bool {
        match (head) {
            case Some(current) => refEq(current, entry)
            case None => false
        }
    }

    private func reconnectPrevious(
        previous: ?BoundedResourceCacheEntry<T>,
        next: ?BoundedResourceCacheEntry<T>
    ): Unit {
        match (previous) {
            case Some(value) => value.next = next
            case None => head = next
        }
    }

    private func reconnectNext(
        next: ?BoundedResourceCacheEntry<T>,
        previous: ?BoundedResourceCacheEntry<T>
    ): Unit {
        match (next) {
            case Some(value) => value.previous = previous
            case None => tail = previous
        }
    }

    /* Throws `IllegalStateException` only if the private map/list invariant is corrupted. */
    private func trim(admitted: BoundedResourceCacheEntry<T>): Unit {
        while (entries.size > entryLimit || (bytes > byteLimit && entries.size > Int64(1))) {
            let victim = match (tail) {
                case Some(value) => value
                case None => return
            }
            // A single oversized admission is deliberately retained; while there are other
            // entries, normal LRU order decides what leaves first.
            if (refEq(victim, admitted) && entries.size == Int64(1)) {
                return
            }
            // Lock-free image fast paths cannot relink this list on every frame. They mark the
            // entry instead, and eviction grants that hot entry one promotion before reconsidering
            // it. Ordinary lookup still maintains exact LRU order.
            if (victim.recentlyUsed) {
                victim.recentlyUsed = false
                promote(victim)
                continue
            }
            match (entries.remove(victim.key)) {
                case Some(_) => ()
                case None => throw IllegalStateException("Media cache LRU index lost its tail entry")
            }
            unlink(victim)
            release(victim)
            evictions += UInt64(1)
        }
    }

    private func release(entry: BoundedResourceCacheEntry<T>): Unit {
        entry.active = false
        if (bytes == UInt64.Max) {
            bytes = recalculateBytes()
        } else if (bytes >= entry.weight) {
            bytes -= entry.weight
        } else {
            bytes = UInt64(0)
        }
        match (last) {
            case Some(current) =>
                if (refEq(current, entry)) {
                    last = None
                }
            case None => ()
        }
        releaseValue(entry)
    }

    private func recalculateBytes(): UInt64 {
        var total = UInt64(0)
        for ((_, entry) in entries) {
            total = saturatedMediaAdd(total, entry.weight)
        }
        total
    }

    private func releaseValue(entry: BoundedResourceCacheEntry<T>): Unit {
        match (entry.cached) {
            case Some(value) => dispose(value)
            case None => ()
        }
    }
}

internal func saturatedMediaAdd(left: UInt64, right: UInt64): UInt64 {
    if (left > UInt64.Max - right) {
        UInt64.Max
    } else {
        left + right
    }
}
