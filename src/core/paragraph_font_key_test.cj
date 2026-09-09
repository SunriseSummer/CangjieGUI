package cui.core

import sdl.{FontStyle, FontWeight, FontVariation, FontVariations}
import std.runtime.gc

@Test
func equivalentParagraphKeysStillHitAfterCollection(): Unit {
    let cache = ParagraphLayoutCache()
    let style = FontStyle(weight: FontWeight(625), variations: FontVariations([FontVariation("wdth", 90.0)]))
    let key = ParagraphCacheKey("同一行 🎉", 300.0, 20.0, style, Some("Family"), 4, UiEnvironmentKey(UInt64(0)))
    let _ = cache.getOrCompute(key, {=> ParagraphLayout(["cached"], 50.0)})
    for (_ in 0..64) {
        let text = String.fromUtf8(Array<UInt8>("同一行 🎉".size, { i => "同一行 🎉"[i] }))
        let family = String.fromUtf8(Array<UInt8>("Family".size, { i => "Family"[i] }))
        let equivalent = ParagraphCacheKey(text, 300.0, 20.0, style, Some(family), 4, UiEnvironmentKey(UInt64(0)))
        gc(heavy: true)
        let hit = cache.getOrCompute(equivalent, {=> throw IllegalStateException("Equivalent key lost its cached layout")})
        @Expect(hit.lines[0], "cached")
        @Expect(hit.widest, 50.0)
    }
    @Expect(cache.stats().entries, Int64(1))
    @Expect(cache.stats().misses, UInt64(1))
    @Expect(cache.stats().hits, UInt64(64))
}

@Test
func textQualityParagraphCacheIncludesExplicitWeightAndAxes(): Unit {
    let ctx = testContext()
    let light = FontStyle(weight: FontWeight(350))
    let regular = FontStyle(weight: FontWeight(400))
    let narrow = FontStyle(variations: FontVariations([FontVariation("wdth", 90.0)]))
    let a = ctx.cachedParagraphLayout("same", 100.0, 15.0, 0, light, None,
        {=> ParagraphLayout(["light"], 50.0)})
    let b = ctx.cachedParagraphLayout("same", 100.0, 15.0, 0, regular, None,
        {=> ParagraphLayout(["regular"], 60.0)})
    let c = ctx.cachedParagraphLayout("same", 100.0, 15.0, 0, narrow, None,
        {=> ParagraphLayout(["narrow"], 40.0)})
    @Expect(a.lines[0], "light")
    @Expect(b.lines[0], "regular")
    @Expect(c.lines[0], "narrow")
    @Expect(ctx.paragraphCacheStats().misses, UInt64(3))
}
