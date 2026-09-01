package cui.media

@Test
func imageCacheStatsConstructorPreservesEveryCounter(): Unit {
    let stats = ImageCacheStats(
        UInt64(1), UInt64(2), UInt64(3), UInt64(4), Int64(5), UInt64(6),
        Int64(7), UInt64(8), UInt64(9), UInt64(10)
    )

    @Expect(stats.hits, UInt64(1))
    @Expect(stats.misses, UInt64(2))
    @Expect(stats.loadFailures, UInt64(3))
    @Expect(stats.evictions, UInt64(4))
    @Expect(stats.entries, Int64(5))
    @Expect(stats.estimatedBytes, UInt64(6))
    @Expect(stats.maxEntries, Int64(7))
    @Expect(stats.maxBytes, UInt64(8))
    @Expect(stats.rendererChanges, UInt64(9))
    @Expect(stats.oversizedAdmissions, UInt64(10))
}
