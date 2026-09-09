package cui.core

import sdl.FontStyle

extend UiContext {
    /** Paragraph-layout cache counters for diagnostics and performance tests. */
    public func paragraphCacheStats(): ParagraphCacheStats {
        paragraphCache.stats()
    }

    /** Resets paragraph-layout hit/miss/eviction counters without dropping cached layouts. */
    public func resetParagraphCacheStats(): Unit {
        paragraphCache.resetStats()
    }

    internal func cachedParagraphLayout(
        text: String,
        width: Float32,
        pointSize: Float32,
        maxLines: Int64,
        style: FontStyle,
        font: ?String,
        compute: () -> ParagraphLayout
    ): ParagraphLayout {
        paragraphCache.getOrCompute(ParagraphCacheKey(text, width, pointSize, style, font, maxLines, uiEnvironmentKey()),
            compute)
    }
}
