package cui.core

import sdl.{FontStyle, Fonts}

/*
 * maxRunesFitting 的 gallop 定界与旧的全范围二分同属一个单调谓词上的最大 k 求解，
 * 结果必须逐值一致；参照度量函数取「宽度=字符数」，让每个断言精确到边界。
 */

@Test
func maxRunesFittingGallopMatchesReference(): Unit {
    let runes = Array<Rune>(5000, repeat: r'字')
    let measure = {s: String => Float32(s.toRuneArray().size)}
    // 横跨 gallop 种子（32）、各级探针（128/512）与阈值（512）的目标值，逐一验证最大性。
    for (want in [1, 31, 32, 33, 127, 128, 129, 511, 512, 513, 2048, 4999]) {
        @Expect(maxRunesFitting(runes, 0, Float32(want), measure), want)
    }
    // 整段可容纳、以及一个字符都放不下。
    @Expect(maxRunesFitting(runes, 0, 5000.0, measure), 5000)
    @Expect(maxRunesFitting(runes, 0, 0.5, measure), 0)
    // start 偏移后按剩余长度走短路径。
    @Expect(maxRunesFitting(runes, 4990, 100.0, measure), 10)
}

@Test
func wrapTextLongDocumentReconstructs(): Unit {
    let ctx = testContext()
    let builder = StringBuilder()
    for (_ in 0..2000) {
        builder.append(r'资')
    }
    let text = builder.toString()
    let lines = wrapText(ctx, text, 300.0, 15.0, Int64.Max)
    // 无空格 CJK 文本走逐字符断行：多行、不丢字、每行都在宽度内。
    @Expect(lines.size > 1)
    let joined = StringBuilder()
    for (line in lines) {
        joined.append(line)
        @Expect(ctx.renderer.textWidth(line, pointSize: 15.0) <= 300.0)
    }
    @Expect(joined.toString(), text)
}

@Test
func textFittingPreservesExtendedGraphemeClusters(): Unit {
    let ctx = testContext()
    // The available width can hold the base letter but not its combining mark plus the ellipsis;
    // truncation must drop the whole user-perceived character, never emit a dangling mark.
    @Expect(ellipsize(ctx, "e\u{0301}x", 20.0, 10.0), "…")
    // ZWJ emoji and regional-indicator pairs are indivisible emergency-wrap units.
    @Expect(ellipsize(ctx, "👩‍💻x", 60.0, 10.0), "…")
    @Expect(ellipsize(ctx, "🇨🇳x", 45.0, 10.0), "…")

    let wrapped = wrapText(ctx, "👩‍💻x", 20.0, 10.0, Int64.Max)
    @Expect(wrapped.size, 2)
    @Expect(wrapped[0], "👩‍💻")
    @Expect(wrapped[1], "x")
}

@Test
func paragraphBreaksHonorHardLinesNonBreakingSpaceAndCjkPunctuation(): Unit {
    let ctx = testContext()
    let hardLines = wrapText(ctx, "甲\n乙\r\n丙\n", 200.0, 10.0, Int64.Max)
    @Expect(hardLines, ["甲", "乙", "丙", ""])

    // The NBSP keeps the short phrase together when it fits as a unit; the following ordinary
    // space remains the preferred break.
    let nbsp = wrapText(ctx, "a\u{00A0}b c", 25.0, 10.0, Int64.Max)
    @Expect(nbsp[0], "a\u{00A0}b")
    @Expect(nbsp[1], "c")

    // Never leave an opening CJK bracket at the end of a line when an earlier legal break exists.
    let cjk = wrapText(ctx, "甲（乙）丙", 33.0, 10.0, Int64.Max)
    @Expect(cjk[0], "甲")
    @Expect(!cjk[0].endsWith("（"))
}

@Test
func paragraphLayoutCacheSurvivesImmediateWidgetRebuilds(): Unit {
    let ctx = testContext()
    ctx.resetParagraphCacheStats()
    let text = "跨帧重建的长文本 paragraph cache 看护"
    let first = wrapText(ctx, text, 120.0, 15.0, Int64.Max)
    let second = wrapText(ctx, text, 120.0, 15.0, Int64.Max)
    @Expect(second, first)
    let warm = ctx.paragraphCacheStats()
    @Expect(warm.misses, UInt64(1))
    @Expect(warm.hits, UInt64(1))
    @Expect(warm.entries >= 1)
    @Expect(warm.bytes > 0)

    let _ = wrapText(ctx, text, 121.0, 15.0, Int64.Max)
    @Expect(ctx.paragraphCacheStats().misses, UInt64(2))
}

@Test
func paragraphLayoutCacheEvictsByByteBudget(): Unit {
    let cache = ParagraphLayoutCache(byteBudget: 300)
    let first = cache.getOrCompute("first text payload", 100.0, 15.0, 2, FontStyle.regular, None,
        {=> ParagraphLayout(["first text payload"], 50.0)})
    let _ = cache.getOrCompute("second text payload", 100.0, 15.0, 2, FontStyle.regular, None,
        {=> ParagraphLayout(["second text payload"], 50.0)})
    let _ = cache.getOrCompute("third text payload", 100.0, 15.0, 2, FontStyle.regular, None,
        {=> ParagraphLayout(["third text payload"], 50.0)})
    @Expect(first.lines[0], "first text payload")
    let stats = cache.stats()
    @Expect(stats.evictions > UInt64(0))
    @Expect(stats.bytes <= 300)
}

@Test
func paragraphCacheUsesExactWidthAndFontRegistryRevision(): Unit {
    let ctx = testContext()
    ctx.resetParagraphCacheStats()
    let text = "精确缓存键 precision"
    let _ = wrapText(ctx, text, 120.001, 15.0, 3)
    let _ = wrapText(ctx, text, 120.002, 15.0, 3)
    @Expect(ctx.paragraphCacheStats().misses, UInt64(2))

    Fonts.register("paragraph-cache-font", "Z:\\missing-a.ttf")
    try {
        let _ = wrapText(ctx, text, 120.0, 15.0, 3, font: Some("paragraph-cache-font"))
        Fonts.register("paragraph-cache-font", "Z:\\missing-b.ttf")
        let _ = wrapText(ctx, text, 120.0, 15.0, 3, font: Some("paragraph-cache-font"))
        @Expect(ctx.paragraphCacheStats().misses, UInt64(4))
    } finally {
        Fonts.unregister("paragraph-cache-font")
    }
}
