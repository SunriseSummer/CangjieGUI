[cui](../../index.md) › [cui.core](index.md) › ParagraphCacheStats

# ParagraphCacheStats

[`UiContext`](UiContext.md) 内段落布局 LRU 的诊断快照。

```cangjie
public struct ParagraphCacheStats {
    public let hits: UInt64
    public let misses: UInt64
    public let entries: Int64
    public let bytes: Int64
    public let evictions: UInt64
}
```

- `hits` / `misses`：按文本、精确宽度、字号、样式、字体、字体注册表代数和行数上限查询的累计结果。
- `entries` / `bytes`：当前缓存项数与保守字节权重；默认总预算 4 MiB。
- `evictions`：因字节预算触发的真 LRU 淘汰数。

计数面向 UI 线程诊断；[`UiContext.resetParagraphCacheStats`](UiContext.md#resetparagraphcachestats) 只清计数，不清内容。
