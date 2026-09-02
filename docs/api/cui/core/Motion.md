[cui](../../index.md) › [cui.core](index.md) › Motion

# Motion

位于 `cui.core` 包的公开类

动效令牌：三档标准动画时长（毫秒）与四条角色化缓动曲线，与 [`Animator`](Animator.md)、[`Spring`](Spring.md) 搭配使用。`fast` 适合小开关，`normal` 适合多数过渡，`slow` 适合大幅或强调性移动；缓动按标准/减速/加速的通行角色划分，`emphasized` 额外带轻微过冲。全静态字段，不可实例化。

## 声明

```cangjie
public class Motion
```

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    println(Motion.fast)
    println(Motion.normal)
    // 标准曲线是对称缓动，中点恰为一半
    println(Int64(Motion.standard.ease(0.5) * 100.0))
    // 输出: 120
    // 220
    // 50
}
```

## 成员概览

**字段**

| 成员 | 说明 |
|---|---|
| [`static fast`](#fast) | 快速过渡时长，120 毫秒——小型开关与即时反馈。 |
| [`static normal`](#normal) | 常规过渡时长，220 毫秒——多数过渡的默认档。 |
| [`static slow`](#slow) | 慢速过渡时长，360 毫秒——大幅或强调性移动。 |
| [`static standard`](#standard) | 标准对称缓动（`Easing.EaseInOutCubic`），双向常规过渡。 |
| [`static decelerate`](#decelerate) | 减速缓动（`Easing.EaseOutCubic`），元素入场。 |
| [`static accelerate`](#accelerate) | 加速缓动（`Easing.EaseInCubic`），元素退场。 |
| [`static emphasized`](#emphasized) | 强调缓动（`Easing.EaseOutBack`），带轻微过冲的活泼入场。 |

## 字段

### fast

快速过渡时长，120 毫秒——小型开关与即时反馈。

```cangjie
public static let fast: UInt64 = 120
```

### normal

常规过渡时长，220 毫秒——多数过渡的默认档。

```cangjie
public static let normal: UInt64 = 220
```

### slow

慢速过渡时长，360 毫秒——大幅或强调性移动。

```cangjie
public static let slow: UInt64 = 360
```

### standard

标准对称缓动（[`Easing`](Easing.md)`.EaseInOutCubic`），双向常规过渡。用法如 `Animator(0.0, duration: Motion.normal, easing: Motion.standard)`。

```cangjie
public static let standard: Easing = Easing.EaseInOutCubic
```

### decelerate

减速缓动（`Easing.EaseOutCubic`），元素入场。

```cangjie
public static let decelerate: Easing = Easing.EaseOutCubic
```

### accelerate

加速缓动（`Easing.EaseInCubic`），元素退场。

```cangjie
public static let accelerate: Easing = Easing.EaseInCubic
```

### emphasized

强调缓动（`Easing.EaseOutBack`），带轻微过冲的活泼入场。

```cangjie
public static let emphasized: Easing = Easing.EaseOutBack
```

## 另请参阅

- [Easing](Easing.md) — 曲线本体与逐条说明。
- [Animator](Animator.md) / [Spring](Spring.md) — 使用这些令牌的动画类型。
- [Spacing](Spacing.md) / [Radii](Radii.md) / [Theme](Theme.md) — 其余设计令牌。
