[CUI 指南](../index.md) › 动画与帧预算

# 动画状态与帧预算

## 核心结论

动画把跨帧进度保存在稳定对象中，并且只在尚未到达目标或本来就要循环时请求下一帧。

先理解[构建生命周期](composition-and-lifecycle.md)和[资源所有权](resources-and-media.md)。控件树会重建，动画器若每次构建都重新创建，就会不断回到起点；帧循环若无条件持续，则静止窗口仍消耗 CPU/GPU。

## 为什么重要

桌面动画需要同时满足流畅和空闲低开销。按钮滑块到达终点后不再需要帧，骨架屏的 Pulse 却必须持续循环，文件对话框轮询只在请求未完成期间需要 FrameHandler。把三者都写成永久每帧回调，会让“声明式”错误地等于持续刷新。

CUI 提供三种不同的动画方式。`Spring` 根据当前位置、速度和物理参数逐渐到达目标；`Animator` 在指定时长内按 Easing 从当前值走到目标；`Pulse` 没有终点，适合呼吸灯或骨架屏。`FrameHandler` 只是每帧调用一次的入口，动画状态和“是否已经稳定”仍应交给相应动画器。

## 工作模型

每个动画都回答四个问题：状态由谁持有、目标从哪来、哪段代码推进时间、何时停止请求帧。

`Animator.animate(ctx, target:)` 与 `Spring.animate(ctx, target:)` 会读取帧间隔、推进状态，并在尚未稳定时请求下一帧。到达目标后它们不再请求，因此静止控件可以回到按需绘制。`Pulse.animate(ctx)` 每次都会请求下一帧，因为循环本身就是目标。

并非所有时间变化都需要连续帧。光标闪烁与 Tooltip 驻留只在下一个相位边界改变像素，它们使用帧截止
时间，让循环在中间休眠；只有弹簧、补间和 Pulse 这类每个刷新点都会改变画面的动画才立即续帧。
开启垂直同步时，呈现本身负责节奏，循环不会再叠加固定 16ms 延时。

动画对象必须跨构建保留。可以放进应用模型，或在固定声明中用 `remember<Animator> { ... }` 保留；动态列表中的动画对象使用显式 key/`Keyed`。不要在 draw 中创建新 Animator，也不要在构建函数中按墙钟直接计算并写 State；构建只描述目标，draw 或 FrameHandler 推进当前值。

## 选择与取舍

- 明确时长、需要与产品动效规范一致：Animator + Easing。
- 目标可能在中途改变、希望有自然追随：Spring。
- 永续加载/呼吸：Pulse，并在内容就绪后卸载使用它的控件。
- 倒计时、异步请求轮询：条件挂载 FrameHandler；完成后移除。
- 只想让高度展开/收起：优先用 Reveal 等成品容器，不必自建动画器。

性能判断不能只看 FPS。垂直同步会把结果量化到刷新周期，真正的瓶颈要看构建、布局、绘树、降采样和呈现各阶段。先用 `--profile` 取证，再减少可见节点、复杂几何或不必要续帧。

## 应用这个模型

确定时长的淡入使用 `Animator`，目标会临时改变的位移使用 `Spring`。两个动画对象都应由模型或 `remember` 持有；每帧只调用 `animate(ctx, target: ...)` 读取当前值。

计时器只在运行时声明 `FrameHandler`，暂停后改为直接声明静态内容。仅让回调什么都不做并不能停止续帧：只要 `FrameHandler` 仍在组件树中，它就会继续请求下一帧。

可编译的完整动画程序见[驱动会停止的逐帧动画](../how-to/animate-with-frames.md)。

## 常见误解

- **“Animator 放在构建闭包里也会继续。”** 若对象随重建重新创建，进度会重置。
- **“所有动画都应该用 FrameHandler。”** 动画器已经包含推进和稳定判断，FrameHandler 适合通用时钟或轮询。
- **“动画停住是 Easing 错了。”** 先检查对象是否稳定保留、是否调用带 UiContext 的 animate、是否还有续帧请求。
- **“Pulse 到达 1 就结束。”** Pulse 是循环时间线，没有 settled 终点。
- **“帧率低就关闭超采样。”** 默认 Auto 已按物理后备密度在 1x/2x 间选择；先读阶段剖析中的 build/layout/tree/resolve/present，只有 present/resolve 主导时才用显式 `supersample: 1`/`2` 做受控对照。可见节点、文本成形或几何仍可能才是主要耗时。

## 相关 API

- [`Animator`](../../api/cui/core/Animator.md) 与 [`Easing`](../../api/cui/core/Easing.md) — 确定时长动效。
- [`Spring`](../../api/cui/core/Spring.md) — 物理追随。
- [`Pulse`](../../api/cui/core/Pulse.md) — 循环时间线。
- [`FrameHandler`](../../api/cui/core/FrameHandler.md) — 条件帧钩子。

## 下一步

在[驱动动画](../how-to/animate-with-frames.md)中运行确定性动画程序，再用[快照与帧剖析](../how-to/snapshot-and-profile.md)区分视觉结果和性能证据。
