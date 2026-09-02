[cui](../../index.md) › [cui.core](index.md) › Pulse

# Pulse

位于 `cui.core` 包的公开类

永动的循环时间线——骨架屏微光、呼吸状态点、加载脉冲。[`Spring`](Spring.md) 与 [`Animator`](Animator.md) 朝目标运动后稳定；Pulse 没有目标，会持续循环：值在 `period` 毫秒内从 0 变到 1，然后要么反向回到 0（`autoreverse: true`，适合呼吸效果），要么立即从 0 开始下一轮（适合不定进度条）。

## 声明

```cangjie
public class Pulse
```

## 说明

组件在 `draw` 里调 [`animate(ctx)`](#animate) 读值；脉冲永动，`animate` 无条件请求下一帧——可见的脉冲让按需渲染循环持续出帧（无尽动画的固有代价），没有脉冲的界面仍然零帧闲置。多个组件可共享一个 Pulse（整块骨架屏同步呼吸）：`animate` 按帧戳去重，同一帧只有第一个调用推进时钟，共享不会加速。经过整周期即回绕，长时间运行不丢精度。放进模型或 `localState` 里跨帧存活。

## 示例

```cangjie verify
package docexample

import cui.core.{Pulse, Easing}

main(): Unit {
    // 线性地从 0 变到 1，然后立即从 0 开始下一轮
    let sweep = Pulse(period: 1000, autoreverse: false, easing: Easing.Linear)
    sweep.tick(250)
    println("四分之一 ${Int64(sweep.value * 100.0)}")
    sweep.tick(750)
    // 满周期回绕到 0
    println("整周期 ${Int64(sweep.value * 100.0)}")
    // 输出: 四分之一 25
    // 整周期 0
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init(...)`](#init) | 指定周期、是否反向播放与缓动曲线，创建循环动画。 |

**属性**

| 成员 | 说明 |
|---|---|
| [`value`](#value) | 当前周期位置经缓动后的 `[0, 1]` 值。 |

**方法**

| 成员 | 说明 |
|---|---|
| [`tick(...)`](#tick) | 把周期推进 deltaMs 毫秒，整周期回绕（autoreverse 的一个周期是一去一回）。 |
| [`animate(...)`](#animate) | 组件 draw 中的一步：推进（按帧戳去重）、无条件请求下一帧、读值。 |

## 构造函数

### init

指定周期、是否反向播放与缓动曲线，创建循环动画。

```cangjie
public init(period!: UInt64 = 1200, autoreverse!: Bool = true, easing!: Easing = Easing.EaseInOutSine)
```

**参数**

- `period!`: `UInt64` — 单程毫秒数（0→1 一趟）；内部下限 1ms。默认 `1200`。
- `autoreverse!`: `Bool` — `true` 到 1 后原路返回（呼吸）；`false` 跳回 0（锯齿）。默认 `true`。
- `easing!`: [`Easing`](Easing.md) — 施加在周期位置上的缓动。默认 `Easing.EaseInOutSine`。

## 属性

### value

当前周期位置经缓动后的 `[0, 1]` 值。

```cangjie
public prop value: Float32
```

**返回值** `Float32` — 缓动后的周期位置。

## 方法

### tick

把周期推进 `deltaMs` 毫秒，整周期回绕（autoreverse 的一个周期是一去一回）。

```cangjie
public func tick(deltaMs: UInt64): Unit
```

**参数**

- `deltaMs`: `UInt64` — 距上次推进的毫秒数。

### animate

组件 `draw` 中的一步：推进（按帧戳去重）、无条件请求下一帧、读值。多组件共享一个 Pulse 时同一帧只有第一个调用推进时钟。

```cangjie
public func animate(ctx: UiContext): Float32
```

**参数**

- `ctx`: [`UiContext`](UiContext.md) — 当前帧上下文。

**返回值** `Float32` — 推进后的缓动值。

## 另请参阅

- [`Spring`](Spring.md) / [`Animator`](Animator.md) — 朝目标运动并最终稳定的动画类型。
