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
