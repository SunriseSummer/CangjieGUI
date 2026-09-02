[cui](../../index.md) › [cui.core](index.md) › Spring

# Spring

位于 `cui.core` 包的公开类

跨帧把数值弹性逼近目标的弹簧-阻尼器。CUI 每帧重绘，组件在 `draw` 里用帧间隔驱动它并读取 [`value`](#value)——无需独立动画计时器就得到平滑的状态过渡。

## 声明

```cangjie
public class Spring
```

## 说明

积分用半隐式欧拉法并限制时间步长（单步至多 40ms），帧卡顿不会注入巨大冲量导致发散。到达目标后精确落位（`settled()` 为真），弹簧闲置时不请求后续帧。默认参数为 UI 开关调校：干脆、几乎察觉不到的回弹。在目标值上初始化的弹簧立即处于稳定态——控件以当前状态起步时只有后续变化才有动画，静态渲染（快照）不受影响。跨帧存活：把弹簧放进模型对象或 [`rememberState`](functions.md#rememberstate) 保存的状态里。

## 示例

```cangjie verify
package docexample

import cui.core.Spring

main(): Unit {
    let knob = Spring(0.0)
    println("初始已稳定 ${knob.settled()}")
    // 显式驱动时间:朝 100 前进一帧(16ms)
    let after = knob.animate(target: 100.0, deltaMs: 16)
    println("一帧后 ${Int64(after)} 已稳定 ${knob.settled()}")
    knob.reset(100.0)
    println("重置后 ${Int64(knob.value)} 已稳定 ${knob.settled()}")
    // 输出: 初始已稳定 true
    // 一帧后 5 已稳定 false
    // 重置后 100 已稳定 true
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init(...)`](#init) | 在 `value` 处创建立即稳定的弹簧，可调刚度与阻尼。 |

**属性**

| 成员 | 说明 |
|---|---|
| [`value`](#value) | 当前动画值。 |

**方法**

| 成员 | 说明 |
|---|---|
| [`target(...)`](#target) | 设置弹簧逼近的目标值。 |
| [`reset(...)`](#reset) | 无动画地立刻跳到 `value`（初始摆放或硬重置）。 |
| [`settled()`](#settled) | 弹簧是否已到达目标并停止。 |
| [`animate(...)`](#animate) | 一步完成重定目标、推进一帧并读新值。 |
| [`tick(...)`](#tick) | 把弹簧向目标推进 `deltaMs` 毫秒。 |

## 构造函数

### init

在 `value` 处创建立即稳定的弹簧，可调刚度与阻尼。

```cangjie
public init(value: Float32, stiffness!: Float32 = 210.0, damping!: Float32 = 24.0)
```

**参数**

- `value`: `Float32` — 初始值，同时成为初始目标（立即稳定）。
- `stiffness!`: `Float32` — 刚度；越大回中越快。默认 `210.0`。
- `damping!`: `Float32` — 阻尼；越大越不易过冲。默认 `24.0`。

## 属性

### value

当前动画值。

```cangjie
public prop value: Float32
```

**返回值** `Float32` — 当前值；稳定后精确等于目标。

## 方法

### target

设置弹簧逼近的目标值。

```cangjie
public func target(value: Float32): Unit
```

**参数**

- `value`: `Float32` — 新目标；下一次 `tick`/`animate` 开始朝它运动。

### reset

无动画地立刻跳到 `value`（初始摆放或硬重置）。速度清零。

```cangjie
public func reset(value: Float32): Unit
```

**参数**

- `value`: `Float32` — 要立即设为当前值和目标值的数值；同时把速度清零。

### settled

弹簧是否已到达目标并停止。

```cangjie
public func settled(): Bool
```

**返回值** `Bool` — 位置与速度都收敛到阈值内后为 `true`。

### animate

一步完成重定目标、推进一帧并读新值。`ctx` 形态是组件在 `draw` 中的用法：运动未结束时调用 `ctx.requestFrame()`，让按需渲染循环持续出帧而不是把过渡冻在半路；稳定后不再请求，闲置控件零帧开销。`deltaMs` 形态是显式驱动时间的原始步进（测试、非绘制调用方），不请求帧。

```cangjie
public func animate(ctx: UiContext, target!: Float32): Float32
```

```cangjie
public func animate(target!: Float32, deltaMs!: UInt64): Float32
```

**参数**

- `ctx`: [`UiContext`](UiContext.md) — 当前帧上下文，提供帧间隔并接收下一帧请求。
- `target!`: `Float32` — 本次的目标值。
- `deltaMs!`: `UInt64` — 显式时间步长，毫秒。

**返回值** `Float32` — 推进后的当前值。

### tick

把弹簧向目标推进 `deltaMs` 毫秒。单步限制在 40ms 以内保证数值稳定；已稳定时直接返回。

```cangjie
public func tick(deltaMs: UInt64): Unit
```

**参数**

- `deltaMs`: `UInt64` — 距上次推进的毫秒数。

## 另请参阅

- [`Animator`](Animator.md) — 固定时长、指定曲线的补间（弹簧是物理驱动、时长自然涌现）。
- [`Pulse`](Pulse.md) — 无目标、永不稳定的循环时间线。
