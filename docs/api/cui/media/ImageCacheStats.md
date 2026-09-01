[cui](../../index.md) › [cui.media](index.md) › ImageCacheStats

# ImageCacheStats

调用线程所拥有的图像纹理缓存诊断快照。

```cangjie
public struct ImageCacheStats {
    public let hits: UInt64
    public let misses: UInt64
    public let loadFailures: UInt64
    public let evictions: UInt64
    public let entries: Int64
    public let estimatedBytes: UInt64
    public let maxEntries: Int64
    public let maxBytes: UInt64
    public let rendererChanges: UInt64
    public let oversizedAdmissions: UInt64
}
```

- `hits` / `misses`：对线程缓存执行查询的累计命中与未命中数；同一 `ImageView` 已解析的本地快路不重复计数。
- `loadFailures`：SDL 无法读取、解码或创建纹理的次数；失败结果也进入有界缓存。
- `evictions`：因条目数或估算字节预算触发的淘汰数；普通查询维护精确 LRU，逐帧快命中获得一次二次机会。
- `entries` / `estimatedBytes`：当前条目数与保守内存权重（RGBA 像素估算加路径/条目开销）。
- `maxEntries` / `maxBytes`：默认上限分别为 256 项和 128 MiB。
- `rendererChanges`：调用线程切换活动 `Renderer`、并释放旧纹理集合的次数。
- `oversizedAdmissions`：单张纹理大于总字节预算而作为唯一条目保留的次数；这样可避免逐帧重新解码超大图。

统计与纹理缓存一样按 UI 线程隔离；[`clearImageCache`](functions.md#clearimagecache) 会清空调用线程的缓存并让其统计归零。
