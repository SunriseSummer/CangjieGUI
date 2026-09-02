[cui](../../index.md) › [cui.core](index.md) › Radii

# Radii

位于 `cui.core` 包的公开类

圆角半径尺度，虚拟像素：小档给标签与输入框、中档给卡片、大档给醒目表面，`pill` 收成全圆头。传给 `background(color, radius)`、`border(...)`、`shadow(...)`、`gradientBackground(...)` 等修饰器，让整个界面的圆角保持一致。渲染器会把半径限制为较短边的一半，因此超大值自然呈现为胶囊形或圆形。全静态字段，不可实例化。

## 声明

```cangjie
public class Radii
```

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    println(Int64(Radii.md)) // 卡片档
    println(Int64(Radii.pill)) // 超大值，渲染时限制为短边一半，即全圆头
    // 输出: 10
    // 9999
}
```

## 成员概览

**字段**

| 成员 | 说明 |
|---|---|
| [`static none`](#none) | 直角，0 虚拟像素。 |
| [`static sm`](#sm) | 小圆角，6 虚拟像素——标签、输入框等小元素。 |
| [`static md`](#md) | 中圆角，10 虚拟像素——卡片的常用档。 |
| [`static lg`](#lg) | 大圆角，16 虚拟像素——醒目表面。 |
| [`static xl`](#xl) | 特大圆角，24 虚拟像素——大幅面板与浮层。 |
| [`static pill`](#pill) | 全圆头档，9999 虚拟像素——渲染时限制为短边一半，两端呈半圆。 |

## 字段

### none

直角，0 虚拟像素。

```cangjie
public static let none: Float32 = 0.0
```

### sm

小圆角，6 虚拟像素——标签、输入框等小元素。

```cangjie
public static let sm: Float32 = 6.0
```

### md

中圆角，10 虚拟像素——卡片的常用档。

```cangjie
public static let md: Float32 = 10.0
```

### lg

大圆角，16 虚拟像素——醒目表面。

```cangjie
public static let lg: Float32 = 16.0
```

### xl

特大圆角，24 虚拟像素——大幅面板与浮层。

```cangjie
public static let xl: Float32 = 24.0
```

### pill

全圆头档，9999 虚拟像素——渲染时限制为短边一半，两端呈半圆。徽标、过滤标签与胶囊按钮用它。

```cangjie
public static let pill: Float32 = 9999.0
```

## 另请参阅

- [Spacing](Spacing.md) / [Motion](Motion.md) / [Theme](Theme.md) — 其余设计令牌。
- [Corners](Corners.md) — 四角各自独立的圆角配置。
