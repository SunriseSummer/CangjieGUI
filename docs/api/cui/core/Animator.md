[cui](../../index.md) › [cui.core](index.md) › Animator

# Animator

位于 `cui.core` 包的公开类

按固定时长与 [`Easing`](Easing.md) 曲线把数值从当前位置补间到目标的动画器——CSS transition 与 SwiftUI/Compose `.animation(...)` 背后的模型。[`Spring`](Spring.md) 是物理驱动、时长自然涌现；Animator 则在精确的时长内以选定曲线到达。

## 声明

```cangjie
public class Animator
```

## 说明

用法与 [`Spring`](Spring.md) 相同：组件在 `draw` 里调 [`animate(ctx, target:)`](#animate) 并读 [`value`](#value)，运动中自动请求下一帧。中途重定目标会从当前值重新起步。`delay` 在每次重定目标后先按住不动若干毫秒再开始缓动（CSS `transition-delay` 模型）；给列表每项按下标成比例的 delay 即得级联入场，且每次切换都会重播级联。长卡顿（拖窗口、GC 停顿）落到时间线末端即钉在终点——补间"完成"而不是"拉长"，与 CSS transition 行为一致。在目标值上创建的动画器立即稳定，闲置时不请求后续帧。

## 示例

```cangjie verify
package docexample

import cui.core.{Animator, Easing}

main(): Unit {
    let fade = Animator(0.0, duration: 250, easing: Easing.EaseInOutQuad)
    // 显式推进一半时长
    let mid = fade.animate(target: 100.0, deltaMs: 125)
    println("半程 ${Int64(mid)} 目标 ${Int64(fade.goal)}")
    let done = fade.animate(target: 100.0, deltaMs: 125)
    println("到达 ${Int64(done)} 已稳定 ${fade.settled()}")
    // 输出: 半程 50 目标 100
    // 到达 100 已稳定 true
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init(...)`](#init) | 在 `value` 处创建立即稳定的动画器，指定时长、曲线与延迟。 |

**属性**

| 成员 | 说明 |
|---|---|
| [`value`](#value) | 当前动画值。 |
| [`goal`](#goal) | 正在逼近的目标值。 |

**方法**

| 成员 | 说明 |
|---|---|
| [`target(...)`](#target) | 重定目标，从当前值重新起步缓动；目标未变时是无操作。 |
| [`reset(...)`](#reset) | 无动画地立刻跳到 `value`（初始摆放或硬重置）。 |
| [`settled()`](#settled) | 动画是否已到达目标并停止（延迟等待期间算未稳定）。 |
| [`animate(...)`](#animate) | 一步完成重定目标、推进一帧并读新值。 |
| [`tick(...)`](#tick) | 把动画推进 `deltaMs` 毫秒。 |

## 构造函数

### init

在 `value` 处创建立即稳定的动画器，指定时长、曲线与延迟。

```cangjie
public init(
    value: Float32,
    duration!: UInt64 = 250,
    easing!: Easing = Easing.EaseInOutQuad,
    delay!: UInt64 = 0
)
```

**参数**

- `value`: `Float32` — 初始值，同时成为初始目标（立即稳定）。
- `duration!`: `UInt64` — 缓动时长，毫秒；内部下限 1ms。默认 `250`。
- `easing!`: [`Easing`](Easing.md) — 时序曲线。默认 `Easing.EaseInOutQuad`。
- `delay!`: `UInt64` — 每次重定目标后先按住的毫秒数；每次重定目标都重新计延迟。默认 `0`。

## 属性

### value

当前动画值。

```cangjie
public prop value: Float32
```

**返回值** `Float32` — 当前值；延迟期间保持起点值。

### goal

正在逼近的目标值。

```cangjie
public prop goal: Float32
```

**返回值** `Float32` — 最近一次设置的目标。

## 方法

### target

重定目标，从当前值重新起步缓动；目标未变时是无操作。

```cangjie
public func target(value: Float32): Unit
```

**参数**

- `value`: `Float32` — 新目标；与当前目标相同时不重启时间线。

### reset

无动画地立刻跳到 `value`（初始摆放或硬重置）。

```cangjie
public func reset(value: Float32): Unit
```

**参数**

- `value`: `Float32` — 要立即设为当前值和目标值的数值。

### settled

动画是否已到达目标并停止（延迟等待期间算未稳定）。

```cangjie
public func settled(): Bool
```

**返回值** `Bool` — 起终点相同或时间线走完后为 `true`。

### animate

一步完成重定目标、推进一帧并读新值。`ctx` 形态是组件在 `draw` 中的用法：运动未结束时调用 `ctx.requestFrame()`，稳定后零帧开销；`deltaMs` 形态显式驱动时间（测试、非绘制调用方），不请求帧。

```cangjie
public func animate(ctx: UiContext, target!: Float32): Float32
```

```cangjie
public func animate(target!: Float32, deltaMs!: UInt64): Float32
```

**参数**

- `ctx`: [`UiContext`](UiContext.md) — 当前帧上下文。
- `target!`: `Float32` — 本次的目标值。
- `deltaMs!`: `UInt64` — 显式时间步长，毫秒。

**返回值** `Float32` — 推进后的当前值。

### tick

把动画推进 `deltaMs` 毫秒。越过时间线末端即钉在终点；延迟未消耗完时值保持起点。

```cangjie
public func tick(deltaMs: UInt64): Unit
```

**参数**

- `deltaMs`: `UInt64` — 距上次推进的毫秒数。

## 另请参阅

- [`Spring`](Spring.md) — 物理驱动的弹性过渡。
- [`Easing`](Easing.md) — 可用的时序曲线。
- [`Motion`](Motion.md) — 预置时长与曲线的设计令牌。
