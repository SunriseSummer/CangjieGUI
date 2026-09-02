[cui](../../index.md) › [cui.media](index.md) › ImageView

# ImageView

位于 `cui.media` 包的公开类

显示从文件加载的图像。解码后的纹理放在按 UI 线程和渲染器隔离、按路径键控的有界加权 LRU 中（逐帧快命中有二次机会），ImageView 像普通组件一样内联声明——每帧重建只查缓存、不碰磁盘；同一实例重复绘制还会复用已解析结果。覆盖写过图像文件后调用 [`invalidateImage`](functions.md#invalidateimage) 刷新。

## 声明

```cangjie
public class ImageView <: Widget & Resource
```

## 继承

- 实现 [`Widget`](../core/Widget.md) 与标准库 `Resource`。

## 说明

`Resource` 实现用于兼容早期“先在外部创建，再交给 `manage`”的写法：[close()](#close) 只停用这个图像视图，纹理由线程缓存管理。缓存默认限制为 256 项和估算 128 MiB，淘汰会确定关闭纹理；单张超过预算的纹理可作为唯一条目保留，避免逐帧重新解码。图像不存在或解码失败时不绘制内容，也不会中断帧循环；失败结果同样受条目上限约束。未设置 `preferredWidth` 时占满可用宽度；设置后按指定宽度显示，可以和其他控件排在同一行。

## 示例

```cangjie verify
package docexample

import cui.*

let IMAGE_PATH = "cui-doc-cover.bmp"

func writeSampleImage(): Unit {
    try (surface = Surface.create(160, 90)) {
        surface.clear(Color.rgb(52, 120, 246))
        var y: Int32 = 0
        while (y < 90) {
            var x: Int32 = 0
            while (x < 48) {
                surface.writePixel(x, y, Color.rgb(246, 179, 52))
                x += 1
            }
            y += 1
        }
        surface.saveBmp(IMAGE_PATH)
    }
}

main(): Unit {
    try {
        writeSampleImage()
        let app = DesktopApp(WindowSpec("ImageView", 420, 260))
        app.run {
            VStack(spacing: 10.vp) {
                ImageView(
                    IMAGE_PATH,
                    fit: ImageFit.Cover,
                    preferredWidth: Some(240.vp),
                    preferredHeight: 150.vp
                )
                Label("程序生成的 160×90 BMP，以 Cover 填满 240×150 区域").muted()
            }.padding(24.0)
            // 运行时：图像按 Cover 填满 240×150 区域，左右边缘会被等量裁去。
        }
    } finally {
        if (FileSystem.exists(IMAGE_PATH)) {
            FileSystem.remove(IMAGE_PATH)
        }
    }
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init(...)`](#init) | 以文件路径、适配方式与首选尺寸创建图像视图。 |

**方法**

| 成员 | 说明 |
|---|---|
| [`fit(...)`](#fit) | 选择图像像素装进分配框的方式。 |
| [`measure(...)`](#measure) | 未指定首选宽度时填满可用宽度；否则采用首选尺寸，但不超过可用空间。 |
| [`layout(...)`](#layout) | 记住分配的矩形。 |
| [`draw(...)`](#draw) | 从共享缓存取纹理并按适配方式绘制（`Cover` 裁剪到框）。 |
| [`handle(...)`](#handle) | 不处理任何事件，恒返回 `false`。 |
| [`isClosed()`](#isclosed) | 本视图是否已退役。 |
| [`close()`](#close) | 退役本视图（纹理归缓存所有，不随之销毁）。 |

## 构造函数

### init

以文件路径、适配方式与首选尺寸创建图像视图。

```cangjie
public init(
    path: String,
    fit!: ImageFit = ImageFit.Contain,
    preferredWidth!: ?Length = None,
    preferredHeight!: Length = Length(96.0, LengthUnit.Vp)
)
```

**参数**

- `path`: `String` — 图像文件路径，同时是缓存键。
- `fit!`: [`ImageFit`](ImageFit.md) — 适配方式；默认值为 `ImageFit.Contain`。
- `preferredWidth!`: `?Length` — 首选宽；默认 `None`（填满可用宽）。
- `preferredHeight!`: [`Length`](../core/Length.md) — 首选高；默认值为 `Length(96.0, LengthUnit.Vp)`，即 96 虚拟像素。

## 方法

### fit

选择图像像素装进分配框的方式。

```cangjie
public func fit(value: ImageFit): ImageView
```

**参数**

- `value`: [`ImageFit`](ImageFit.md) — 适配方式。

**返回值** [`ImageView`](ImageView.md) — 自身，供链式调用。

### measure

未指定首选宽度时填满可用宽度；否则采用首选尺寸，但不超过可用空间。

```cangjie
public func measure(ctx: UiContext, available: Size): Size
```

**参数**

- `ctx`: [`UiContext`](../core/UiContext.md) — 本轮测量使用的 UI 上下文。
- `available`: `Size` — 父级给出的可用尺寸约束。

**返回值** `Size` — 首选尺寸。

### layout

记住分配的矩形。

```cangjie
public func layout(_: UiContext, rect: Rect): Unit
```

**参数**

- `rect`: `Rect` — 父级最终分配给组件的矩形。

### draw

从共享缓存取纹理并按适配方式绘制（`Cover` 裁剪到框）。缺失/解码失败画空白。

```cangjie
public func draw(ctx: UiContext): Unit
```

**参数**

- `ctx`: [`UiContext`](../core/UiContext.md) — 本轮绘制使用的 UI 上下文。

### handle

不处理任何事件，恒返回 `false`。

```cangjie
public func handle(_: UiContext, _: UiEvent): Bool
```

**返回值** `Bool` — 恒为 `false`。

### isClosed

本视图是否已退役。

```cangjie
public func isClosed(): Bool
```

**返回值** `Bool` — 已调用过 `close()` 即 `true`。

### close

退役本视图（纹理归缓存所有，不随之销毁）。退役后 `draw` 不再绘制。

```cangjie
public func close(): Unit
```

## 另请参阅

- [`ImageFit`](ImageFit.md) — 适配方式。
- [`invalidateImage`](functions.md#invalidateimage) / [`clearImageCache`](functions.md#clearimagecache) — 缓存刷新入口。
- [`ImageCacheStats`](ImageCacheStats.md) / [`imageCacheStats`](functions.md#imagecachestats) — 缓存容量与运行统计。
- [`CanvasWidget`](CanvasWidget.md) — 自由绘制表面。
