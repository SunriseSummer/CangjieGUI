[CUI 指南](../index.md) › 媒体与资源

# 媒体缓存与资源所有权

## 核心结论

可重复声明的媒体由共享缓存复用，独占的长期资源交给应用所有者关闭，短期资源在使用点及时关闭。

这套模型建立在[应用结构](app-architecture.md)之上。界面可以反复构建，因此不能把“每次出现一张图”误解为“每帧重新解码文件”；也不能假设所有原生资源都会被垃圾回收安全释放。

## 为什么重要

图片、纹理、光标、表面和窗口背后都有操作系统或 SDL 资源。管理过早会让正在绘制的对象失效，管理太晚会累积原生内存。CUI 对常见图片提供按路径和渲染器作用域共享的缓存，使 `ImageView(path)` 可以像 Label 一样内联声明；自建的长期 `Resource` 则需要清楚的所有者。

媒体还带来失败缓存。若路径不存在，框架不会在每次构建都重新访问磁盘；修复或覆盖文件后要主动失效相应路径。这个行为保护帧循环，却意味着“文件已经换了但画面不变”通常需要缓存失效，而不是重复创建 ImageView。

## 工作模型

先按所有权把对象分三类：

1. **声明式缓存媒体**：`ImageView` 描述路径和 fit，纹理由共享缓存持有。相同路径的重建只是查表。
2. **应用期长期资源**：自建 Cursor、Surface、Texture 或其他 `Resource` 在多帧使用，交给 `DesktopApp.manage`，应用退出时按逆序关闭。
3. **短期资源**：只为生成文件或转换格式而创建的 Surface，在函数内用资源语法或 `finally` 关闭。

### 为什么长期资源要反过来关闭

后创建的资源经常要使用先创建的资源。以窗口、Renderer 和 Texture 为例：应用先创建窗口及其 Renderer，随后才由这个 Renderer 创建 Texture。Texture 要依靠仍然有效的 Renderer 才能绘制和完成底层清理，所以关闭顺序应当反过来：先关 Texture，再关窗口及其 Renderer。

`DesktopApp.run` 正是这样处理：它先从后往前关闭 `manage` 登记的资源，最后关闭窗口。若多个自建资源也有依赖，先登记提供能力的资源，再登记使用它的资源。例如 B 使用 A，就依次调用 `manage(A)`、`manage(B)`；退出时 B 先关，A 后关。

错误顺序不是单纯的“先后风格”问题。窗口先关闭会释放 Renderer，此时仍持有的 Texture 已失去它所依赖的绘制环境；之后继续绘制或清理，可能遇到调用失败、无效句柄或清理不完整。不要因为某台机器上暂时没有报错，就把这个顺序当成可交换。

CanvasWidget 不拥有传入的 Renderer。绘制回调只能在当前帧使用它，不应保存到模型、后台线程或下一帧。事件回调收到与绘制相同的绝对矩形；判断指针是否落在画布内时应使用这个矩形，不要假设画布从 `(0, 0)` 开始。

## 选择与取舍

- 普通文件图片用 `ImageView`；需要逐像素生成时先创建 Surface 并保存，再显示结果。
- 文件被外部覆盖后用 `invalidateImage(path)`；只有确实要丢弃全部图片时才用 `clearImageCache()`。
- 画折线、自由笔迹或特殊控件时用 CanvasWidget；需要复用完整 measure/layout/draw/handle 协议时实现 Widget。
- 长期原生资源由一个应用所有者管理，不要让每个构建分支各自“顺便”关闭。
- 有依赖的长期资源按“提供者在前、使用者在后”的顺序交给 `manage`；手动关闭时则反过来。
- 后台线程可以准备普通数据或文件，但 Renderer 和 UI State 留在 UI 线程。

## 应用这个模型

覆盖预览图片时，顺序应是：写入文件，调用 `invalidateImage(path)`，再让下一次构建继续声明 `ImageView(path)`。仅重新创建 ImageView 不会主动丢弃已有缓存。

生成预览所用的 Surface 属于短期资源：在函数内创建、保存并关闭，随后再使图片缓存失效。若文件由后台任务生成，后台只发布“路径已就绪”或错误文本；UI 线程收到结果后再刷新缓存和可见状态。不要在线程之间传递 Surface 或 Renderer。

完整可编译程序见[媒体预览面板](../tutorials/media-dashboard.md)。

长期 Texture 的完整顺序可以记成一条短链：创建应用窗口（内部创建 Renderer）→ 从 Renderer 创建 Texture → `app.manage(texture)`；应用退出时则是 Texture → 窗口（内部释放 Renderer）。这正是“使用者先关、提供者后关”的具体结果。

## 常见误解

- **“声明 ImageView 会每帧解码。”** 纹理由共享缓存复用；重复声明是预期用法。
- **“文件内容改变后缓存会自动发现。”** 当前需要明确调用路径失效函数。
- **“Renderer 可以保存到模型供后台继续画。”** Renderer 属于窗口和 UI 绘制线程，只在回调期间使用。
- **“manage 适合所有临时对象。”** 短期资源应尽早关闭，不必拖到应用退出。
- **“窗口和纹理谁先关都一样。”** Texture 依赖窗口的 Renderer；应先关 Texture，再关窗口。
- **“清空全部缓存总是最安全。”** 它会让所有图片下帧重载，应优先失效单一路径。

## 相关 API

- [`ImageView`](../../api/cui/media/ImageView.md) 与 [`ImageFit`](../../api/cui/media/ImageFit.md) — 文件图片和装入策略。
- [`invalidateImage`](../../api/cui/media/functions.md#invalidateimage) 与 [`clearImageCache`](../../api/cui/media/functions.md#clearimagecache) — 缓存失效。
- [`CanvasWidget`](../../api/cui/media/CanvasWidget.md) — 本帧自绘表面。
- [`DesktopApp`](../../api/cui/desktop/DesktopApp.md) — 长期资源所有者。

## 下一步

在[媒体面板教程](../tutorials/media-dashboard.md)中生成并显示可清理图片，再到[自定义画布](../how-to/custom-canvas.md)处理绘制与指针边界。
