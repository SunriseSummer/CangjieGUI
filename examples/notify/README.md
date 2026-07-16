# notify：通知（Toast）

一个通知演示，集中展示 `Toaster` + `ToastLayer` 瞬态通知：从任意处弹出一条通知，右下角自底向上堆叠，
滑入、停留数秒后淡出。关键在于时间动画由帧循环驱动。

## 演示要点

- `Toaster` 是应用级控制器，`show(message, kind, durationMs)` 从任意处弹出一条通知
- `ToastLayer(toaster)` 负责渲染与计时：右下角自底向上堆叠、滑入（前 150ms）、到期前 300ms 淡出
- `ToastKind` 四类（成功/信息/警告/错误）决定通知左侧强调条的颜色
- `ToastLayer` 不占布局空间、不吞事件，故放在根 `ZStack` 末层浮于内容之上，下方按钮点击照常
- 时间动画：每帧按 `FrameInfo.deltaMs` 老化通知；有通知时调用 `ctx.requestFrame()` 驱动下一帧，否则空闲的脏帧
  循环会冻住动画
- 初始化先弹两条通知，使应用打开即有可见通知

## 文件结构

| 文件 | 职责 |
|---|---|
| [main.cj](src/main.cj) | 入口 |
| [data.cj](src/data.cj) | 按类型与序号生成通知文案 |
| [model.cj](src/model.cj) | `NotifyModel`：`Toaster` 控制器、已弹计数、`notify` |
| [views.cj](src/views.cj) | 内容层（抬头 + 四个触发按钮）与 `ToastLayer` 叠放 |
| [theme.cj](src/theme.cj) | 深色主题，衬托浮起的通知卡片 |

## 关键实现

### 控制器 + 渲染层分离

`Toaster` 只管“有哪些通知、各自还剩多久”，与视图无关；`ToastLayer` 把它画出来并推进时钟：

```cangjie
// 任意处
model.toaster.show("已保存更改", kind: ToastKind.Success)

// 视图根部
ZStack {
    appContent()
    ToastLayer(model.toaster) // 渲染 + 计时 + 动画
}
```

### 时间动画需要主动请求帧

框架有脏帧跳过（空闲不渲染），所以纯靠时间推进的动画必须在每帧主动请求下一帧，否则会被冻住：

```cangjie
// ToastLayer.handle 处理 Frame 事件时
toaster.tick(info.deltaMs)          // 按真实帧间隔老化通知
if (!toaster.isEmpty()) {
    ctx.requestFrame()              // 有通知就驱动下一帧，动画才会继续
}
```

## 运行

```powershell
cd examples/notify
cjpm run
```

点四个按钮弹出不同类型的通知，观察它们在右下角堆叠、滑入、几秒后淡出。支持视觉回归快照：

```powershell
cjpm run --run-args "--snapshot notify.bmp"
```
