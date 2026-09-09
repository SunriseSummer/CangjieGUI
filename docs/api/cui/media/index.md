[cui](../../index.md) › cui.media

# cui.media

```cangjie
import cui.media.*
```

图像与自绘包。[`ImageView`](ImageView.md) 显示文件图片并使用有界纹理缓存；[`CanvasWidget`](CanvasWidget.md) 把渲染器和布局矩形交给绘制回调；包级函数负责刷新和检查图像缓存。

## 类型

**类**

| 类型 | 说明 |
|---|---|
| [`CanvasWidget`](CanvasWidget.md) | 在组件矩形内使用原始 Renderer 自由绘制，并可处理指针事件。 |
| [`ImageView`](ImageView.md) | 显示从文件加载的图像。 |

**结构体**

| 类型 | 说明 |
|---|---|
| [`ImageCacheStats`](ImageCacheStats.md) | 当前 UI 线程的图像缓存命中、失败、容量与淘汰诊断。 |

**枚举**

| 类型 | 说明 |
|---|---|
| [`ImageFit`](ImageFit.md) | 图像像素装进分配框的方式，供 [`ImageView`](ImageView.md) 使用：拉伸填满、等比包含或等比覆盖。 |

## 函数

| 函数 | 说明 |
|---|---|
| [`invalidateImage`](functions.md#invalidateimage) | 丢弃 `path` 的缓存纹理（并关闭它）；下一次绘制从磁盘重载。 |
| [`clearImageCache`](functions.md#clearimagecache) | 清空图像缓存并关闭每个缓存纹理；图像在下一次绘制时重载。 |
| [`imageCacheStats`](functions.md#imagecachestats) | 返回调用 UI 线程的图像缓存诊断快照。 |

| [ImageSource](ImageSource.md) | 文件或内存来源。 |
| [ImageStatus](ImageStatus.md) | 主图解析状态。 |
| [preloadImage](functions.md#preloadimage) | 显示前预热。 |

## 用户图标

| 类型／函数 | 说明 |
|---|---|
| [Icon](Icon.md) | 用户媒体资源构成的非交互图标。 |
| [IconButton](IconButton.md) | 用户媒体图标与可选文字组成的按钮。 |
| [IconSource](IconSource.md) | 不可变的应用图标资源定义，包含 ImageSource、原色／模板意图及可选位图规格表。 |
| [IconVariant](IconVariant.md) | 应用提供的一个正方形位图规格，pixels 为原始画布边长（物理像素），不是 vp。 |
| [IconRenderingMode](IconRenderingMode.md) | Original 保留媒体 RGB，忽略 foregroundColor；Template 以透明度为覆盖范围，使用前景色替换 RGB。 |
| [IconStyle](IconStyle.md) | 不可变的图标样式，可在 Icon 与 IconButton 之间复用。 |
| [paintIcon](functions.md#painticon) | 图标绘制、预热与失效。 |
| [preloadIcon](functions.md#preloadicon) | 图标绘制、预热与失效。 |
| [invalidateIcon](functions.md#invalidateicon) | 图标绘制、预热与失效。 |
