package cui.media

private class CacheProbe {
    var closed = false

    func close(): Unit {
        closed = true
    }
}

private func probeCache(entryLimit: Int64, byteLimit: UInt64): BoundedResourceCache<CacheProbe> {
    BoundedResourceCache<CacheProbe>(entryLimit, byteLimit, {probe => probe.close()})
}

@Test
func boundedResourceCacheEvictsLeastRecentlyUsedAndClosesValues(): Unit {
    let cache = probeCache(2, UInt64(100))
    let first = CacheProbe()
    let second = CacheProbe()
    let third = CacheProbe()
    cache.put("first", Some(first), UInt64(40))
    cache.put("second", Some(second), UInt64(40))

    let secondEntry = cache.lookup("second").getOrThrow() // the entry was inserted immediately above
    @Expect(cache.lookup("first").isSome())
    cache.put("third", Some(third), UInt64(40))

    @Expect(!first.closed)
    @Expect(second.closed)
    @Expect(!secondEntry.active)
    @Expect(!third.closed)
    @Expect(cache.lookup("second").isNone())
    @Expect(cache.size(), Int64(2))
    @Expect(cache.estimatedBytes(), UInt64(80))
    @Expect(cache.evictionCount(), UInt64(1))

    cache.clear()
    @Expect(first.closed)
    @Expect(third.closed)
    @Expect(cache.size(), Int64(0))
    @Expect(cache.estimatedBytes(), UInt64(0))
}

@Test
func boundedResourceCacheGivesFastHitOneEvictionSecondChance(): Unit {
    let cache = probeCache(2, UInt64(100))
    let first = CacheProbe()
    let second = CacheProbe()
    let third = CacheProbe()
    cache.put("first", Some(first), UInt64(40))
    let firstEntry = cache.lookup("first").getOrThrow() // the entry was inserted immediately above
    cache.put("second", Some(second), UInt64(40))
    firstEntry.recentlyUsed = true

    cache.put("third", Some(third), UInt64(40))

    @Expect(!first.closed)
    @Expect(second.closed)
    @Expect(!third.closed)
    @Expect(cache.lookup("first").isSome())
    @Expect(cache.lookup("second").isNone())
}

@Test
func boundedResourceCacheEnforcesByteBudgetAndKeepsOneOversizedValue(): Unit {
    let cache = probeCache(4, UInt64(100))
    let first = CacheProbe()
    let second = CacheProbe()
    let oversized = CacheProbe()
    let small = CacheProbe()

    cache.put("first", Some(first), UInt64(60))
    cache.put("second", Some(second), UInt64(60))
    @Expect(first.closed)
    @Expect(!second.closed)

    cache.put("oversized", Some(oversized), UInt64(200))
    @Expect(second.closed)
    @Expect(cache.size(), Int64(1))
    @Expect(cache.estimatedBytes(), UInt64(200))
    @Expect(cache.oversizedAdmissionCount(), UInt64(1))

    cache.put("small", Some(small), UInt64(10))
    @Expect(oversized.closed)
    @Expect(!small.closed)
    @Expect(cache.size(), Int64(1))
    @Expect(cache.estimatedBytes(), UInt64(10))
    @Expect(cache.evictionCount(), UInt64(3))
}

@Test
func boundedResourceCacheRecalculatesBytesAfterSaturatedEntryLeaves(): Unit {
    let cache = probeCache(2, UInt64(100))
    let saturated = CacheProbe()
    let small = CacheProbe()
    cache.put("saturated", Some(saturated), UInt64.Max)

    cache.put("small", Some(small), UInt64(10))

    @Expect(saturated.closed)
    @Expect(!small.closed)
    @Expect(cache.size(), Int64(1))
    @Expect(cache.estimatedBytes(), UInt64(10))
}

@Test
func boundedResourceCacheBoundsCachedFailuresByEntryCount(): Unit {
    let cache = probeCache(2, UInt64(1000))
    cache.put("missing-a", None, UInt64(140))
    cache.put("missing-b", None, UInt64(140))
    cache.put("missing-c", None, UInt64(140))

    @Expect(cache.lookup("missing-a").isNone())
    let retainedFailure = cache.lookup("missing-c")
    @Assert(retainedFailure.isSome())
    @Expect(retainedFailure.getOrThrow().cached.isNone()) // lookup above proves the entry exists
    @Expect(cache.size(), Int64(2))
    @Expect(cache.evictionCount(), UInt64(1))
}
