[cui](../../index.md) › [cui.media](index.md) › 函数

# 函数 — cui.media

`cui.media` 的包级函数：图像纹理缓存的刷新与诊断入口。缓存按 UI 线程和渲染器隔离、按文件路径键控，并以 256 项和估算 128 MiB 的双上限执行带快命中二次机会的加权 LRU；加载失败也会被缓存（不每帧重试磁盘）。

### invalidateImage

丢弃调用线程中 `path` 的缓存纹理（并关闭它），同时发布跨线程失效版本；其他 UI 线程下一次查询会丢弃旧集合。下一次绘制从磁盘重载，同时使所属 UI 的保留绘制失效。覆盖写过图像文件后调用，包括先前加载失败的文件。即使条目已被容量淘汰，显式刷新仍会通知保留绘制的观察者。

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

```cangjie
public func invalidateImage(source: ImageSource): Unit
```

丢弃来源的全部解码尺寸变体。文件与内存来源均支持；请在所属 UI 线程调用。

### preloadImage

同步预热图像缓存，返回是否成功；失败也被缓存。必须在渲染器所属 UI 线程调用。不会创建 ImageView，也不会发出组件声明。

```cangjie
public func preloadImage(renderer: Renderer, path: String, options!: ImageLoadOptions = ImageLoadOptions()): Bool
public func preloadImage(renderer: Renderer, source: ImageSource, options!: ImageLoadOptions = ImageLoadOptions()): Bool
```

### preloadIcon

```cangjie
public func preloadIcon(renderer: Renderer, source: IconSource, pixels!: Int32): Bool
```

显式指定目标物理像素边长（1..2048）；非法范围抛 IllegalArgumentException。同步完成选择、解码、模板转换和上传，成功返回 true，普通加载失败返回 false。应在 UI 渲染线程调用；颜色不进入缓存键。

### paintIcon

```cangjie
public func paintIcon(ctx: UiContext, source: IconSource, bounds: Rect, color: Color,
    style!: IconStyle = IconStyle()): Unit
```

在用户自绘组件的 bounds 中居中等比绘制，不构造或 emit 子组件。style.size 不参与此显式矩形入口。失败绘制为空，调用方提供语义与裁剪；无效／空矩形不加载。使用所属 UI 线程。

### invalidateIcon

```cangjie
public func invalidateIcon(source: IconSource): Unit
```

失效本来源所有文件／内存规格的原色与模板缓存，通知保留绘制刷新；下一次使用重新加载。应在所属 UI 线程调用。
