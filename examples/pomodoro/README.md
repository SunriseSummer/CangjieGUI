# pomodoro：番茄钟（ProgressRing + FrameHandler 计时 + Toast）

一只番茄工作法计时器：大进度环内嵌 mm:ss 剩余时间，专注与休息到点自动切换并弹出通知；
时长可在停表时用步进器调整，底部统计已完成的番茄数。

## 演示要点

- 按需驱动帧循环：只在运行中把界面包进 `FrameHandler`（其 Frame 钩子每帧请求下一帧并回调
  `model.tick(deltaMs)`）；暂停后不包裹，渲染循环回到脏帧跳过的阻塞等待的空闲状态
- `ProgressRing(fraction, showLabel: false)` 与 `ZStack` 叠放：环显示剩余占比、中心叠时间与阶段名
  （叠层内上下 `Spacer` 居中，`hug()` 只管主轴弹性、不改变 ZStack 内的拉伸）
- 阶段机全在模型：`tick` 扣减、到零自动切段并 `Toaster.show`；跳过/重置是同一套阶段机的手动入口，
  纯逻辑全部可单测（含单次时间步长超过完整阶段时长的边界）
- `State.observe` 联动：停表且停在阶段起点时修改时长，剩余时间同步跟进（观察句柄需由所有者保留并显式关闭，
  由 `newPomodoroModel` 工厂在构造完成后接线——init 内闭包不得捕获 this）
- 设置卡整卡 `enabled(!running)`：运行中步进器统一置灰

## 文件结构

| 文件 | 职责 |
|---|---|
| [main.cj](src/main.cj) | 入口；运行态条件挂 `FrameHandler` |
| [model.cj](src/model.cj) | 阶段机、tick/跳过/重置、时长观察、`formatClock` 纯函数 |
| [views.cj](src/views.cj) | 计时卡（环 + 按钮）、设置卡、统计条、`ToastLayer` |
| [theme.cj](src/theme.cj) | 暖白底番茄红主题 |

## 运行

```powershell
cd examples/pomodoro
cjpm run
```

点「开始」进入专注段，到点自动休息并弹通知；「跳过阶段」不计数直接切段。支持视觉回归快照：

```powershell
cjpm run --run-args "--snapshot pomodoro.bmp"
```

## 练习与验收

缩短两个阶段并运行完整切换，确认计数、提示和暂停行为。

[返回示例学习路线](../README.md) · [运行准备](../README.md#运行准备) · [API 参考](../../docs/api/index.md)
