[CUI 指南](../index.md) › 媒体与资源

# 媒体缓存与资源所有权

界面声明可以反复构建，原生资源却需要明确的创建和关闭边界。图片由框架缓存复用；应用自行创建的长期资源由应用所有者关闭；短期资源在使用点关闭。

## 先判断谁拥有资源

| 对象 | 所有者与使用规则 |
|---|---|
| `ImageSource`／`IconSource` | 不可变来源描述，不持有 GPU 对象；内存来源应创建一次并跨重建复用 |
| `ImageView`／`Icon` 使用的纹理 | 框架缓存持有；关闭视图只停用该视图，不销毁共享纹理 |
| 应用创建的 `Surface`、`Texture`、`Cursor` | 应用负责关闭；短期用 `try (...)`，应用期资源可交给 `DesktopApp.manage` |
| 与声明位置同寿命的资源 | 用 `mountEffect` 或 `lifecycleEffect` 建立和清理 |
| `CanvasWidget` 回调中的 Renderer | 从宿主借用，在所属 UI 线程及有效绘制阶段使用 |

`SdlWindow` 拥有 Renderer，Texture 依赖创建它的 Renderer。若 B 依赖 A，就先登记 `manage(A)`，再登记 `manage(B)`；退出时 B 先关闭。`DesktopApp.run` 先关闭登记资源，再完成其他清理，最后关闭窗口。

## 加载、失败与刷新

文件图片按来源与解码参数共享缓存；重复声明 `ImageView(path)` 不意味着每帧解码。首次加载同步执行，需要预热时在所属 UI 线程调用 `preloadImage`／`preloadIcon`。默认 ImageView 测量不读取磁盘，只有显式 `intrinsicSize()` 才允许在测量中加载。

失败也会缓存，以免每帧访问损坏文件。覆盖文件后调用 `invalidateImage(path)`；内存来源使用对应来源重载，多规格图标使用 `invalidateIcon(source)`。刷新会使相关保留绘制失效，下次需要资源时重新加载。`clearImageCache()` 适合确实要丢弃全部缓存的场景。

后台工作只生成普通数据或文件，随后通过 `DesktopApp.post` 在 UI 线程刷新缓存与状态。不要跨线程使用或销毁 Renderer 和 Texture，也不要由后台直接修改 UI State。

## 选择合适的层次

- 展示照片：使用 `ImageView`，分别设置布局尺寸、适配方式和解码尺寸。
- 展示操作图标：使用 `Icon`／`IconButton`，按模板或原色模式表达颜色意图。
- 生成或修改像素：使用 SDL `Surface`，保存后显示，或上传为应用持有的 Texture。
- 自绘折线或笔迹：使用 `CanvasWidget`；需要完整测量、布局、事件和语义协议时实现 Widget。

Canvas 的绘制和事件回调使用同一个绝对矩形。命中测试先检查该矩形；保存局部笔迹时再减去矩形原点，避免假设画布位于窗口 `(0, 0)`。

## 后续实践

在[媒体预览面板](../tutorials/media-dashboard.md)中生成并显示图片；再阅读[静态图像](../how-to/images.md)、[图标](../how-to/icons.md)与 [SDL 资源所有权](../../../../CangjieSDL/docs/guide/concepts/resource-ownership.md)。接口见 [`DesktopApp`](../../api/cui/desktop/DesktopApp.md)、[`ImageView`](../../api/cui/media/ImageView.md) 及[媒体函数](../../api/cui/media/functions.md)。
