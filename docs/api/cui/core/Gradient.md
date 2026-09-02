[cui](../../index.md) › [cui.core](index.md) › Gradient

# Gradient

位于 `cui.core` 包的公开结构体

圆角背景用的双色线性渐变填充，默认自上而下、`vertical` 为 false 时自左向右。经 [`Widget.gradientBackground`](Widget.md#gradientbackground) 修饰器应用在任意组件背后；它复用纯色填充的同一套缓存几何，不增加细分成本。

## 声明

```cangjie
public struct Gradient
```

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let dusk = Gradient(start: Color.rgb(255, 94, 98), end: Color.rgb(143, 148, 251))
    println("默认垂直: ${dusk.vertical}")
    // 输出: 默认垂直: true

    let flipped = dusk.reversed()
    println("翻转后起点红通道 ${Int64(flipped.start.r)}")
    // 输出: 翻转后起点红通道 143

    // 声明式用法：给卡片铺一层 12 vp 圆角的渐变背景
    let _ = VStack {
        Label("黄昏").foregroundColor(Color.rgb(255, 255, 255))
    }.gradientBackground(dusk, 12.0)
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init(start!: Color, end!: Color, vertical!: Bool)`](#init) | 以命名参数构造双色渐变。 |

**方法**

| 成员 | 说明 |
|---|---|
| [`reversed()`](#reversed) | 返回两端互换（start ↔ end）的副本，方向不变。 |

**字段**

| 成员 | 说明 |
|---|---|
| [`start`](#start) | 渐变起点色：垂直时的顶部、水平时的左侧。 |
| [`end`](#end) | 渐变终点色：垂直时的底部、水平时的右侧。 |
| [`vertical`](#vertical) | 渐变方向：`true` 自上而下，`false` 自左向右。 |

## 构造函数

### init

以命名参数构造双色渐变。

```cangjie
public init(start!: Color, end!: Color, vertical!: Bool = true)
```

**参数**

- `start!`: `Color` — 起点色。
- `end!`: `Color` — 终点色。
- `vertical!`: `Bool` — 方向；默认 `true`（自上而下），`false` 时自左向右。

## 方法

### reversed

返回两端互换（start ↔ end）的副本，方向不变。适合悬停或按下时把同一渐变翻个面。

```cangjie
public func reversed(): Gradient
```

**返回值** `Gradient` — 互换后的新值；原值不变。

## 字段

### start

渐变起点色：垂直时的顶部、水平时的左侧。只读（`let`），构造后不可变。

```cangjie
public let start: Color
```

### end

渐变终点色：垂直时的底部、水平时的右侧。只读（`let`），构造后不可变。

```cangjie
public let end: Color
```

### vertical

渐变方向：`true` 自上而下，`false` 自左向右。只读（`let`），构造后不可变。

```cangjie
public let vertical: Bool
```

## 另请参阅

- [Widget](Widget.md) — `gradientBackground` 修饰器所在的组件协议。
- [Corners](Corners.md) / [Shadow](Shadow.md) — 同一组背景装饰值类型。
