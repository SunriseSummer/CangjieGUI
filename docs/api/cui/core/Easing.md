[cui](../../index.md) › [cui.core](index.md) › Easing

# Easing

位于 `cui.core` 包的公开枚举

把 `[0, 1]` 内的动画进度映射为缓动后进度的时序曲线。标准曲线严格从 0 起、到 1 止；`EaseOutBack` 会先冲过 1 再回落；`CubicBezier` 表达任意 CSS 式曲线。交给 [`Animator`](Animator.md) 使用，或直接调 [`ease`](#ease) 塑形任何归一化进度。

## 声明

```cangjie
public enum Easing
```

## 说明

`In`/`Out`/`InOut` 命名遵循通行惯例：`In` 从静止加速、`Out` 减速到静止、`InOut` 两者兼有；`Quad`/`Cubic`/`Sine` 是底层多项式。[`Motion`](Motion.md) 设计令牌预置了常用曲线（`standard`、`decelerate`、`accelerate`、`emphasized`）。

## 示例

```cangjie verify
package docexample

import cui.core.Easing

main(): Unit {
    let half: Float32 = 0.5
    println("线性 ${Int64(Easing.Linear.ease(half) * 100.0)}")
    println("二次入 ${Int64(Easing.EaseInQuad.ease(half) * 100.0)}")
    println("二次出 ${Int64(Easing.EaseOutQuad.ease(half) * 100.0)}")
    // 越界进度被限制
    println("限制 ${Int64(Easing.Linear.ease(2.0) * 100.0)}")
    // 输出: 线性 50
    // 二次入 25
    // 二次出 75
    // 限制 100
}
```

## 成员概览

**枚举值**

| 成员 | 说明 |
|---|---|
| `Linear` | 恒速直线。 |
| `EaseInQuad` | 二次方加速起步。 |
| `EaseOutQuad` | 二次方减速收尾。 |
| `EaseInOutQuad` | 二次方先加速后减速。 |
| `EaseInCubic` | 三次方加速起步（比 Quad 更陡）。 |
| `EaseOutCubic` | 三次方减速收尾。 |
| `EaseInOutCubic` | 三次方先加速后减速。 |
| `EaseInSine` | 正弦加速起步（最柔和）。 |
| `EaseOutSine` | 正弦减速收尾。 |
| `EaseInOutSine` | 正弦先加速后减速。 |

**方法**

| 成员 | 说明 |
|---|---|
| [`ease(...)`](#ease) | 把进度 `t`（限制在 `[0, 1]`）映射为缓动后进度。 |

## 枚举值

### EaseOutBack

冲过目标约 10%（经典 1.70158 常数）再回落到 1，适合需要一点"弹"感的强调动效——[`Motion.emphasized`](Motion.md#emphasized) 即它。

```cangjie
EaseOutBack
```

### CubicBezier

CSS 式 cubic-bezier 时序函数，端点固定为 (0,0) 与 (1,1)，四个值表示两个控制点 `(x1, y1)`、`(x2, y2)`。求值采用 WebKit UnitBezier 算法：通常使用 Newton-Raphson 迭代，曲线斜率过小时改用二分法。

```cangjie
CubicBezier(Float32, Float32, Float32, Float32)
```

## 方法

### ease

把进度 `t`（限制在 `[0, 1]`）映射为缓动后进度。

```cangjie
public func ease(t: Float32): Float32
```

**参数**

- `t`: `Float32` — 归一化进度；越界值先限制再求值。

**返回值** `Float32` — 缓动后进度；标准曲线在 `[0, 1]` 内，`EaseOutBack` 可短暂超过 1。

## 另请参阅

- [`Animator`](Animator.md) — 按时长与缓动曲线补间的动画器。
- [`Motion`](Motion.md) — 预置时长与曲线的设计令牌。
