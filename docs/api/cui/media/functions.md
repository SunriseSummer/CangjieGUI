[cui](../../index.md) › [cui.media](index.md) › 函数

# 函数 — cui.media

`cui.media` 的包级函数：图像纹理缓存的刷新与诊断入口。缓存按 UI 线程和渲染器隔离、按文件路径键控，并以 256 项和估算 128 MiB 的双上限执行带快命中二次机会的加权 LRU；加载失败也会被缓存（不每帧重试磁盘）。

### invalidateImage

丢弃调用线程中 `path` 的缓存纹理（并关闭它），同时发布跨线程失效版本；其他 UI 线程下一次查询会丢弃旧集合。下一次绘制从磁盘重载。覆盖写过图像文件后调用——包括先前加载失败的文件。

```cangjie
public func invalidateImage(path: String): Unit
```

**参数**

- `path`: `String` — 图像文件路径（缓存键）。

### clearImageCache

清空调用线程的图像缓存、关闭每个缓存纹理并重置该线程的统计，同时发布跨线程失效版本；图像在下一次绘制时重载。

```cangjie
public func clearImageCache(): Unit
```

### imageCacheStats

返回调用 UI 线程的缓存命中、失败、容量和淘汰快照。尚未创建缓存或刚调用过 `clearImageCache` 时，计数和占用为零，配置上限仍可读取。

```cangjie
public func imageCacheStats(): ImageCacheStats
```

**返回值** [`ImageCacheStats`](ImageCacheStats.md) — 当前线程的缓存诊断快照。

## 另请参阅

- [`ImageView`](ImageView.md) — 缓存的消费者。
- [`ImageCacheStats`](ImageCacheStats.md) — 统计字段与容量语义。
