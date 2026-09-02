[cui](../../index.md) › [cui.core](index.md) › Spacing

# Spacing

位于 `cui.core` 包的公开类

4 像素栅格上的间距尺度：七档命名间隔，以虚拟像素的 [`Length`](Length.md) 值表达。按命名档位而非临时数字取间距能保持界面节奏一致——Material、Fluent 与 iOS HIG 共用的设计令牌做法。每档都参与单位系统，如 `.padding(Spacing.md)` 或 `VStack {}.spacing(Spacing.sm)`。全静态字段，不可实例化。

## 声明

```cangjie
public class Spacing
```

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    println(Int64(Spacing.md.value)) // 中档间距的数值
    println(Spacing.md.unit.symbol()) // 单位是虚拟像素
    println(Int64(Spacing.xxl.value - Spacing.xs.value))
    // 输出: 12
    // vp
    // 28
}
```

## 成员概览

**字段**

| 成员 | 说明 |
|---|---|
| [`static none`](#none) | 零间距，0 虚拟像素。 |
| [`static xs`](#xs) | 特小间距，4 虚拟像素。 |
| [`static sm`](#sm) | 小间距，8 虚拟像素。 |
| [`static md`](#md) | 中间距，12 虚拟像素。 |
| [`static lg`](#lg) | 大间距，16 虚拟像素。 |
| [`static xl`](#xl) | 特大间距，24 虚拟像素。 |
| [`static xxl`](#xxl) | 超大间距，32 虚拟像素。 |

## 字段

### none

零间距，0 虚拟像素。显式声明“无间隔”，比字面 `0.vp` 更能表达意图。

```cangjie
public static let none: Length = Length(0.0, LengthUnit.Vp)
```

### xs

特小间距，4 虚拟像素。图标与文字之间、紧凑标签内的缝隙。

```cangjie
public static let xs: Length = Length(4.0, LengthUnit.Vp)
```

### sm

小间距，8 虚拟像素。同组控件之间的默认缝隙。

```cangjie
public static let sm: Length = Length(8.0, LengthUnit.Vp)
```

### md

中间距，12 虚拟像素。卡片内边距与表单行距的常用档。

```cangjie
public static let md: Length = Length(12.0, LengthUnit.Vp)
```

### lg

大间距，16 虚拟像素。区块之间的分隔。

```cangjie
public static let lg: Length = Length(16.0, LengthUnit.Vp)
```

### xl

特大间距，24 虚拟像素。页面级留白。

```cangjie
public static let xl: Length = Length(24.0, LengthUnit.Vp)
```

### xxl

超大间距，32 虚拟像素。大区块与页面边缘的留白。

```cangjie
public static let xxl: Length = Length(32.0, LengthUnit.Vp)
```

## 另请参阅

- [Length](Length.md) / [LengthUnits](LengthUnits.md) — 间距值背后的单位系统。
- [Radii](Radii.md) / [Motion](Motion.md) / [Theme](Theme.md) — 其余设计令牌。
