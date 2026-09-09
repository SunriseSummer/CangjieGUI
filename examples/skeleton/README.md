# skeleton：骨架屏（Pulse 循环动画）

一页加载骨架屏，演示循环/往复动画原语 `Pulse`：内容未到先给结构——头像圆与长短交错的占位条，底色在
基色与亮色间缓慢呼吸；「加载完成」切换为真实文章列表，界面随之回到零帧空闲。骨架屏是商用应用加载态的
标准形态。

## 演示要点

- `Pulse(period!:, autoreverse!:, easing!:)`：无目标、永不静止的重复时间线；`value` 给出当前周期内的缓动位置
- `autoreverse: true` 为往复呼吸（0→1→0），`false` 为锯齿扫掠（0→1 跳回 0，适合不定进度条）
- 共享即同步：全部骨架行共用一个 Pulse，`animate(ctx)` 按帧戳去重——同一帧内只有第一个调用推进时钟，多行共享不会倍速
- 续帧语义：脉冲每帧请求下一帧（永动使然），故只有加载态在耗帧；切到内容态后无人调用 `animate`，脏帧循环回到零帧空闲
- 自定义动画微件：`SkeletonRow <: Widget` 在 draw 里 `pulse.animate(ctx)` 取值、`Color.lerp` 调底色（与 MotionLab/Toaster 同路径）
- 相位以整周期回绕，长时间运行不丢 Float32 精度

## 文件结构

| 文件 | 职责 |
|---|---|
| [main.cj](src/main.cj) | 入口 |
| [data.cj](src/data.cj) | 文章数据、占位条宽度比例（纯函数，长短交错） |
| [model.cj](src/model.cj) | `SkeletonModel`：加载态、共享 Pulse、切换与文案 |
| [skeleton_row.cj](src/skeleton_row.cj) | 自定义骨架行微件：头像圆 + 两条占位条，底色随脉冲呼吸 |
| [views.cj](src/views.cj) | 标题、切换按钮、骨架/文章双态列表、状态条 |
| [theme.cj](src/theme.cj) | 浅色主题；`field`/`fieldActive` 兼作呼吸的基色与亮色 |

## 关键实现

### 一个脉冲，整屏同步

模型持有 Pulse（普通对象即可跨帧存活，同 Spring 的用法），每个骨架行的 draw 都调 `animate(ctx)`：

```cangjie
let t = pulse.animate(ctx)                    // 按帧戳去重：同帧多行共享只推进一次
let shade = base.lerp(glow, t)                // 底色随呼吸插值
ctx.renderer.fillRoundedRect(bar, 6.0, shade)
```

### 呼吸不是补间

`Spring`/`Animator` 是朝目标运动然后静止的原语，骨架呼吸没有目标——`Pulse` 的 `value` 只是周期内的位置，
`animate` 无条件请求下一帧。可见的脉冲会保持渲染循环运转（任何永动动画皆然）；没有脉冲的界面照常零帧空闲。

## 运行

```powershell
cd examples/skeleton
cjpm run
```

观察骨架行同步呼吸，点「加载完成」换真实内容、再点「重新加载」回到骨架态。支持视觉回归快照：

```powershell
cjpm run --run-args "--snapshot skeleton.bmp"
```

## 练习与验收

切换到加载完成，确认动画停止且内容可正常操作。

[返回示例学习路线](../README.md) · [运行准备](../README.md#运行准备) · [API 参考](../../docs/api/index.md)
