[cui](../../index.md) › [cui.core](index.md) › Corners

# Corners

位于 `cui.core` 包的公开结构体

背景四角的独立圆角半径，即 CSS 四值 `border-radius` 模型，按左上、右上、右下、左下排列。配合 [`Widget.background`](Widget.md#background) 的 `corners!:` 形式构建聊天气泡（三角圆、尾角方）、顶部圆角的标签页或贴边面板；绘制时每个半径被限制在短边的一半。常见形状用静态工厂 [`all`](#all)（四角同值）与 [`top`](#top) / [`bottom`](#bottom) / [`left`](#left) / [`right`](#right)（只圆一侧），任意组合用完整构造器。

## 声明

```cangjie
public struct Corners
```

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    // 聊天气泡：尾角（左下）保持直角
    let bubble = Corners(topLeft: 12.0, topRight: 12.0, bottomRight: 12.0, bottomLeft: 0.0)
    println("左下 ${Int64(bubble.bottomLeft)}，右下 ${Int64(bubble.bottomRight)}")
    // 输出: 左下 0，右下 12

    let tab = Corners.top(8.0)
    println("顶部 ${Int64(tab.topLeft)}/${Int64(tab.topRight)}，底部 ${Int64(tab.bottomLeft)}")
    // 输出: 顶部 8/8，底部 0

    // 声明式用法：把气泡角交给 background 修饰器
    let _ = VStack {
        Label("你好！")
    }.background(Color.rgb(220, 240, 255), corners: bubble)
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init(...)`](#init) | 以命名参数逐角构造，未给出的角保持直角（0）。 |

**方法**

| 成员 | 说明 |
|---|---|
| [`static all(radius: Float32)`](#all) | 四角同半径，等价于统一圆角背景。 |
| [`static top(radius: Float32)`](#top) | 只圆上方两角：顶部标签页、自底部升起的面板。 |
| [`static bottom(radius: Float32)`](#bottom) | 只圆下方两角：下拉列表、自顶部垂下的面板。 |
| [`static left(radius: Float32)`](#left) | 只圆左侧两角。 |
| [`static right(radius: Float32)`](#right) | 只圆右侧两角。 |

**字段**

| 成员 | 说明 |
|---|---|
| [`topLeft`](#topleft) | 左上角半径，逻辑像素。 |
| [`topRight`](#topright) | 右上角半径，逻辑像素。 |
| [`bottomRight`](#bottomright) | 右下角半径，逻辑像素。 |
| [`bottomLeft`](#bottomleft) | 左下角半径，逻辑像素。 |

## 构造函数

### init

以命名参数逐角构造，未给出的角保持直角（0）。

```cangjie
public init(
    topLeft!: Float32 = 0.0,
    topRight!: Float32 = 0.0,
    bottomRight!: Float32 = 0.0,
    bottomLeft!: Float32 = 0.0
)
```

**参数**

- `topLeft!`: `Float32` — 左上角半径，逻辑像素；默认 `0.0`（直角）。
- `topRight!`: `Float32` — 右上角半径；默认 `0.0`。
- `bottomRight!`: `Float32` — 右下角半径；默认 `0.0`。
- `bottomLeft!`: `Float32` — 左下角半径；默认 `0.0`。

## 方法

### all

四角同半径，等价于统一圆角背景。

```cangjie
public static func all(radius: Float32): Corners
```

**参数**

- `radius`: `Float32` — 四个角共用的半径，逻辑像素。

**返回值** `Corners` — 四角同值的实例。

### top

只圆上方两角：顶部标签页、自底部升起的面板。

```cangjie
public static func top(radius: Float32): Corners
```

**参数**

- `radius`: `Float32` — 上方两角的半径，逻辑像素。

**返回值** `Corners` — 下方两角为 0 的实例。

### bottom

只圆下方两角：下拉列表、自顶部垂下的面板。

```cangjie
public static func bottom(radius: Float32): Corners
```

**参数**

- `radius`: `Float32` — 下方两角的半径，逻辑像素。

**返回值** `Corners` — 上方两角为 0 的实例。

### left

只圆左侧两角。

```cangjie
public static func left(radius: Float32): Corners
```

**参数**

- `radius`: `Float32` — 左侧两角的半径，逻辑像素。

**返回值** `Corners` — 右侧两角为 0 的实例。

### right

只圆右侧两角。

```cangjie
public static func right(radius: Float32): Corners
```

**参数**

- `radius`: `Float32` — 右侧两角的半径，逻辑像素。

**返回值** `Corners` — 左侧两角为 0 的实例。

## 字段

### topLeft

左上角半径，逻辑像素。只读（`let`），构造后不可变。

```cangjie
public let topLeft: Float32
```

### topRight

右上角半径，逻辑像素。只读（`let`），构造后不可变。

```cangjie
public let topRight: Float32
```

### bottomRight

右下角半径，逻辑像素。只读（`let`），构造后不可变。

```cangjie
public let bottomRight: Float32
```

### bottomLeft

左下角半径，逻辑像素。只读（`let`），构造后不可变。

```cangjie
public let bottomLeft: Float32
```

## 另请参阅

- [Widget](Widget.md) — `background(color, corners!:)` 修饰器所在的组件协议。
- [Gradient](Gradient.md) / [Shadow](Shadow.md) — 同一组背景装饰值类型。
- [Radii](Radii.md) — 主题的圆角设计令牌。
