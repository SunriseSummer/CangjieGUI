[cui](../../index.md) › cui.media

# cui.media

```cangjie
import cui.media.*
```

图像与自绘包：文件图像视图 [`ImageView`](ImageView.md)（解码纹理进入按 UI 线程/渲染器隔离的有界路径缓存，可内联声明）、自由绘制表面 [`CanvasWidget`](CanvasWidget.md)（把原始渲染器交给回调），以及缓存刷新与诊断函数。

## 类型

**类**

| 类型 | 说明 |
|---|---|
| [`CanvasWidget`](CanvasWidget.md) | 自由绘制表面：弹性填满分得的空间、画主题输入底色、裁剪到框，然后把原始 `Renderer` 与框矩形交给 `onDraw`——坐标是绝对的，绘制方从矩形偏移、不从零点起。 |
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
