# motion：缓动实验室（Easing 曲线 + Animator）

一个缓动曲线对比台，集中演示缓动曲线库 `Easing` 与时长动画原语 `Animator`：七条轨道各绑一种缓动曲线、
共享同一时长，点“播放”让标记点并排推进——同一时刻各标记位置不同，直观呈现每条曲线如何分配运动，
回弹曲线会略微越过终点再回落。自定义 `Widget` 逐帧推进各轨道并在未静止时请求下一帧，声明式构建下驱动连续动画。

## 演示要点

- `Easing` 枚举：`Linear`、`EaseIn/Out/InOut` 的 `Quad`/`Cubic`/`Sine`、`EaseOutBack`（回弹）、`CubicBezier`（CSS ease）
- `Animator(duration, easing)`：确定时长内按曲线从当前值缓动到目标，与物理 `Spring` 互补
- 自定义 `Widget` 在 `draw` 里对每条轨道 `animator.animate(ctx, target:)`——推进一帧 + 未停住则 `ctx.requestFrame()`，
  是声明式构建 + 脏帧跳过下驱动连续动画的正路（与 `ProgressRing`/`Toaster` 同）
- 播放/复位翻转目标，所有轨道同时朝 0 或 1 缓动；标记横坐标 `markerX` 是纯函数，便于单测

## 文件结构

| 文件 | 职责 |
|---|---|
| [main.cj](src/main.cj) | 入口 |
| [data.cj](src/data.cj) | `EasingTrack`（曲线 + Animator）、轨道列表、标记坐标（纯函数） |
| [model.cj](src/model.cj) | `MotionModel`：持久轨道 + 播放开关 |
| [motion_lab.cj](src/motion_lab.cj) | 自定义 `Widget`：逐帧推进各轨道并绘制标记 |
| [views.cj](src/views.cj) | 标题、轨道面板、播放/复位按钮 |
| [theme.cj](src/theme.cj) | 深色主题（青蓝强调） |

## 关键实现

### 自定义 Widget 驱动连续动画

声明式构建下动画状态跨帧保留（`Animator` 存于模型），自定义 Widget 在 `draw` 里推进并续帧：

```cangjie
public func draw(ctx: UiContext): Unit {
    let goal: Float32 = if (playing) { 1.0 } else { 0.0 }
    for (track in tracks) {
        let value = track.animator.animate(ctx, target: goal) // 推进一帧 + 未停住则请求下一帧
        // ... 在 markerX(value, x0, x1) 处画标记
    }
}
```

### 缓动曲线塑形

同一时长下，不同 `Easing` 让标记在同一时刻处于不同位置——ease-in 起步慢而落后、ease-out 起步快而领先、
back 越过终点再回落，一眼看清曲线差异。

## 运行

```powershell
cd examples/motion
cjpm run
```

点“播放”并排推进各轨道，再点“复位”缓动回起点。支持视觉回归快照（快照落在动画中途）：

```powershell
cjpm run --run-args "--snapshot motion.bmp"
```

## 练习与验收

为一条轨道更换缓动曲线，比较相同时刻的位置与停止条件。

[返回示例学习路线](../README.md) · [运行准备](../README.md#运行准备) · [API 参考](../../docs/api/index.md)
