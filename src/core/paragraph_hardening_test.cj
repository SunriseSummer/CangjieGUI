package cui.core

import sdl.FontStyle

@Test
func paragraphHardeningAccountsForEmptyLineStorage(): Unit {
    let cache = ParagraphLayoutCache(byteBudget: 1024)
    let input = StringBuilder()
    for (_ in 0..499) { input.append("\n") }
    let key = ParagraphCacheKey(input.toString(), 100.0, 12.0, FontStyle.regular, None, 500, UiEnvironmentKey(UInt64(0)))
    let _ = cache.getOrCompute(key, {=> ParagraphLayout(Array<String>(500, repeat: ""), 0.0)})
    @Expect(cache.stats().entries, Int64(0))
    @Expect(cache.stats().bytes, Int64(0))
}
