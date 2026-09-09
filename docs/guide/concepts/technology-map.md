[CUI 指南](../index.md) › 技术体系

# CangjieGUI 与 CangjieSDL 的技术体系

CangjieGUI 的包名是 `cui`，负责声明式界面；CangjieSDL 的包名是 `sdl`，负责窗口、输入、绘制与平台服务。开发普通桌面应用可从 CUI 开始；需要游戏循环、直接渲染或理解资源边界时再深入 SDL。

## 从应用到平台

| 层次 | 职责 | 主要入口 |
|---|---|---|
| 应用模型 | 保存业务事实，执行校验、动作和持久化 | `State`、`Binding`、Store 与应用自己的模型 |
| 声明式界面 | 根据状态构建组件，安排布局，处理焦点、事件和浮层 | `cui.core`、`cui.controls`、`cui.text` |
| 媒体与自绘 | 显示图片和图标，提供自定义绘制区域 | `cui.media`、`cui.symbols.<name>` |
| 桌面宿主 | 驱动按需帧循环、后台投递、关闭确认和清理 | `cui.desktop.DesktopApp` |
| 图形与平台 | 创建窗口，消费事件，绘制图形和文字，管理原生资源 | `sdl` 及其输入、对话框、显示器、系统子包 |
| 原生运行库 | 执行窗口系统、字体和图像操作 | SDL3、SDL3_ttf、SDL3_image |

CUI 的常见数据流是“事件 → 修改状态 → 重建受影响声明 → 必要的布局与绘制”。直接使用 SDL 时，这些步骤由应用在事件循环中组织。两种方式共享逻辑坐标、字体和原生资源规则。

## 分阶段学习

| 阶段 | 阅读与实践 | 完成后应能做到 |
|---|---|---|
| 1. 运行与状态 | [第一个窗口](../getting-started/first-window.md)、[构建与生命周期](composition-and-lifecycle.md)、[状态与绑定](state-and-binding.md) | 解释一次按钮点击怎样更新画面，避免状态在重建时丢失 |
| 2. 布局与输入 | [布局与滚动](layout-and-scrolling.md)、[尺寸与修饰器](modifiers-and-units.md)、[设置表单](../tutorials/settings-form.md) | 组合表单并在小窗口、字体放大和键盘操作下保持可用 |
| 3. 应用结构 | [模型与动作](app-architecture.md)、[任务工作台](../tutorials/task-workbench.md)、[后台任务](../how-to/desktop-files-and-background.md) | 分离模型、视图与 I/O，维护稳定项目身份和后台结果顺序 |
| 4. 媒体与桌面 | [资源所有权](resources-and-media.md)、[字体](../how-to/fonts-and-typography.md)、[图片](../how-to/images.md)、[关闭确认](../how-to/desktop-lifecycle.md) | 处理资源失败、缓存刷新与未保存数据 |
| 5. 扩展与验证 | [自绘画布](../how-to/custom-canvas.md)、[自定义 Widget](../how-to/custom-widget.md)、[帧测试](../how-to/retain-and-test.md)、[打包](../how-to/package-desktop-app.md) | 扩展控件、验证状态与交互，并交付独立运行目录 |

每阶段先运行一个完整程序，再改变一个可观察行为。示例的[学习路线](../../../examples/README.md)提供对应工程；API 参考用于核对签名、默认值与边界。

## 何时深入 SDL

- 自绘控件：先读 [SDL 坐标与 DPI](../../../../CangjieSDL/docs/guide/concepts/render-scene-coordinates.md)，再查 [`Renderer`](../../../../CangjieSDL/docs/api/sdl/Renderer.md)。
- 纹理、字体或截图：读 [SDL 资源所有权](../../../../CangjieSDL/docs/guide/concepts/resource-ownership.md)，理解创建线程、关闭顺序与资源失效。
- 游戏或持续动画：从 [SDL 第一个窗口](../../../../CangjieSDL/docs/guide/getting-started/first-window.md)开始，继续学习输入状态和时间步长。

这些跨仓库链接采用入门教程的同级目录布局。通常只依赖 `cui` 并使用其重导出即可；若源码直接 `import sdl.*` 或 `sdl.text`，还应在应用的 `[dependencies]` 中显式添加 `sdl` 路径依赖。

## 常用术语

| 术语 | 在本体系中的含义 |
|---|---|
| 构建函数（builder） | 根据当前状态声明组件的函数，可重复执行 |
| 稳定键（key） | 在指定作用域内识别声明、状态或数据项的身份，不等同于显示文字或数组下标 |
| 绑定（Binding） | 对已有事实的读写入口，本身不必再保存一份数据 |
| 帧 | 一次事件处理、状态稳定、布局与绘制的调度周期；不要求每步每次都执行 |
| 逻辑像素 | 布局、命中与绘制共享的坐标单位，由运行时映射到设备像素 |
| 字素 | 用户通常视为一个字符的序列；编辑偏移使用 UTF-8 字节，移动和删除按字素边界处理 |
| 失效（invalidation） | 声明缓存或渲染结果需要重新计算，不等于立即完成加载或显示 |
