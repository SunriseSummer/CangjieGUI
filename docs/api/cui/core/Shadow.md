[cui](../../index.md) › [cui.core](index.md) › Shadow

# Shadow

`cui.core` 包中的 public struct

可配置的组件阴影，包含水平/垂直偏移、模糊、扩散和颜色，作用类似 CSS `box-shadow`。通过 [`Widget.shadow`](Widget.md#shadow) 把阴影画在组件后面；圆角组件通常让阴影使用相同圆角，轮廓才会贴合。

## 声明

```cangjie
public struct Shadow
```

## 说明

阴影越大越伸出组件之外；modifier 会从 offset、blur 与 spread 自动产生非对称 [`PaintOutset`](PaintOutset.md)，滚动容器与 retained damage 因此保留完整 halo，同时仍在滚动轴严格裁剪。需要商业级的立体感时用 [`keyAmbient`](#keyambient)：宽而淡的环境光晕叠上窄而深的主阴影，单层阴影读起来更平。

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let card = Shadow.elevation(3)
    println("三级高度: 模糊 ${Int64(card.blur)}，垂直偏移十倍 ${Int64(card.offsetY * 10.0)}")
    // 输出: 三级高度: 模糊 17，垂直偏移十倍 45

    let layers = Shadow.keyAmbient(2)
    println("双层数量 ${layers.size}，环境层透明度 ${Int64(layers[0].color.a)}")
    // 输出: 双层数量 2，环境层透明度 30

    // 白底卡片，并让阴影与背景使用相同圆角
    let _ = VStack {
        Label("卡片")
    }.background(Color.rgb(255, 255, 255), 12.0).shadow(card, radius: 12.0)
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init(...)`](#init) | 用命名参数构造阴影，只有颜色是必填项。 |

**方法**

| 成员 | 说明 |
|---|---|
| [`static elevation(...)`](#elevation) | Material 风格的高度预设：`level` 越高表面离页面越远——偏移更大、模糊更宽更软。 |
| [`withColor(value: Color)`](#withcolor) | 返回把颜色替换后的副本，几何不变。 |
| [`static keyAmbient(...)`](#keyambient) | Material 双层高度：宽而淡的环境光晕叠上窄而深的主阴影，返回按绘制顺序排列的双层数组。 |

**字段**

| 成员 | 说明 |
|---|---|
| [`offsetX`](#offsetx) | 阴影的水平偏移，逻辑像素，正值向右。 |
| [`offsetY`](#offsety) | 阴影的垂直偏移，逻辑像素，正值向下。 |
| [`blur`](#blur) | 模糊半径：阴影边缘淡出的距离，逻辑像素。 |
| [`spread`](#spread) | 扩散：阴影在淡出前先扩大的距离，逻辑像素。 |
| [`color`](#color) | 阴影颜色，含透明度。 |

## 构造函数

### init

用命名参数构造阴影，只有颜色是必填项。`blur` 为负时按 0 处理。

```cangjie
public init(
    color!: Color,
    offsetY!: Float32 = 2.0,
    offsetX!: Float32 = 0.0,
    blur!: Float32 = 12.0,
    spread!: Float32 = 0.0
)
```

**参数**

- `color!`: `Color` — 阴影颜色，透明度即阴影浓度。
- `offsetY!`: `Float32` — 垂直偏移，正值向下；默认 `2.0`，即轻微下坠。
- `offsetX!`: `Float32` — 水平偏移，正值向右；默认 `0.0`。
- `blur!`: `Float32` — 模糊半径；默认 `12.0`，负值限制在 0。
- `spread!`: `Float32` — 扩散；默认 `0.0`，阴影与组件同大。

## 方法

### elevation

Material 风格的高度预设：`level` 越高表面离页面越远——偏移更大、模糊更宽更软。

```cangjie
public static func elevation(level: Int64, color!: Color = Color.rgba(0, 0, 0, 64)): Shadow
```

**参数**

- `level`: `Int64` — 高度档位，限制在 1..6。
- `color!`: `Color` — 阴影颜色；默认 `Color.rgba(0, 0, 0, 64)`（四分之一透明度的黑）。

**返回值** `Shadow` — 垂直偏移 `level × 1.5`、模糊 `5 + level × 4`、无扩散的投影。

### withColor

返回把颜色替换后的副本，几何不变。用来给 [`elevation`](#elevation) 预设着色。

```cangjie
public func withColor(value: Color): Shadow
```

**参数**

- `value`: `Color` — 新颜色。

**返回值** `Shadow` — 换色后的新值；原值不变。

### keyAmbient

Material 双层高度：宽而淡的环境光晕叠上窄而深的主阴影，返回按绘制顺序排列的双层数组。把结果传给 `shadow(layers)` 修饰器，各层按数组顺序绘制、环境层在前；`level` 与单层 [`elevation`](#elevation) 同刻度。

```cangjie
public static func keyAmbient(level: Int64, color!: Color = Color.rgb(0, 0, 0)): Array<Shadow>
```

**参数**

- `level`: `Int64` — 高度档位，限制在 1..6。
- `color!`: `Color` — 两层共用的基色；默认值为 `Color.rgb(0, 0, 0)`（黑色）。两层的透明度固定为 30（环境层）与 52（主层），保持比例地为双层着色。

**返回值** `Array<Shadow>` — `[环境层, 主层]` 两个投影。

## 字段

### offsetX

阴影的水平偏移，逻辑像素，正值向右。只读（`let`），构造后不可变。

```cangjie
public let offsetX: Float32
```

### offsetY

阴影的垂直偏移，逻辑像素，正值向下。只读（`let`），构造后不可变。

```cangjie
public let offsetY: Float32
```

### blur

模糊半径：阴影边缘淡出的距离，逻辑像素。只读（`let`），构造后不可变；构造时已限制为非负。

```cangjie
public let blur: Float32
```

### spread

扩散：阴影在淡出前先扩大的距离，逻辑像素。只读（`let`），构造后不可变。

```cangjie
public let spread: Float32
```

### color

阴影颜色，含透明度。只读（`let`），构造后不可变；换色用 [`withColor`](#withcolor)。

```cangjie
public let color: Color
```

## 另请参阅

- [Widget](Widget.md) — `shadow(value)` / `shadow(layers)` 修饰器所在的组件协议。
- [Corners](Corners.md) / [Gradient](Gradient.md) — 同一组背景装饰值类型。
