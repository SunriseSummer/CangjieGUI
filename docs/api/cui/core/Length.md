[cui](../../index.md) › [cui.core](index.md) › Length

# Length

位于 `cui.core` 包的公开结构体

带显式单位的一维尺寸，写作 `100.px`、`24.vp` 或 `15.fp`。单位随类型携带，公共尺寸 API 因此不产生"这个数是什么单位"的歧义；数值到逻辑像素的换算推迟到拿着活动缩放的 [`UiContext.resolve`](UiContext.md#resolve)，从不在构造时发生。

## 声明

```cangjie
public struct Length <: ToString
```

## 继承

- `Length <: ToString`

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let base: Length = 16.vp
    let doubled = base * 2.0
    let half = base / 2.0
    println("倍增 ${Int64(doubled.value)}${doubled.unit.symbol()}，减半 ${Int64(half.value)}${half.unit.symbol()}")
    // 输出: 倍增 32vp，减半 8vp
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init(value: Float32, unit: LengthUnit)`](#init) | 以数值与单位构造一个长度。 |

**方法**

| 成员 | 说明 |
|---|---|
| [`static zero()`](#zero) | 返回零长度（`0.0` 虚拟像素）。 |
| [`toString()`](#tostring) | 返回数值紧跟单位符号的字符串表示。 |

**字段**

| 成员 | 说明 |
|---|---|
| [`value`](#value) | 数值部分，含义由 `unit` 决定。 |
| [`unit`](#unit) | 单位部分，决定数值如何映射到逻辑像素。 |

**运算符**

| 成员 | 说明 |
|---|---|
| [`operator *`](#operator) | 缩放数值并保留单位。 |
| [`operator /`](#operator-1) | 除数值并保留单位。 |

## 构造函数

### init

以数值与单位构造一个长度。日常代码更常用 [`LengthUnits`](LengthUnits.md) 后缀（`16.vp`），显式构造用于单位本身是变量的场合。

```cangjie
public init(value: Float32, unit: LengthUnit)
```

**参数**

- `value`: `Float32` — 数值部分，不做范围检查。
- `unit`: [`LengthUnit`](LengthUnit.md) — 数值的单位。

## 方法

### zero

返回零长度（`0.0` 虚拟像素）。任何单位下零都解析为零，选 `Vp` 只是规范形。

```cangjie
public static func zero(): Length
```

**返回值** `Length` — `Length(0.0, LengthUnit.Vp)`。

### toString

返回数值紧跟单位符号的字符串表示。数值按 `Float32` 的默认格式打印，后接 [`LengthUnit.symbol`](LengthUnit.md#symbol)（如 `px`）。

```cangjie
public func toString(): String
```

**返回值** `String` — 形如 `16.000000vp` 的表示，用于日志与调试。

## 字段

### value

数值部分，含义由 `unit` 决定。

```cangjie
public let value: Float32
```

### unit

单位部分，决定数值如何映射到逻辑像素。

```cangjie
public let unit: LengthUnit
```

## 运算符

### operator*

缩放数值并保留单位。适合从基准尺寸派生变体，例如 `16.vp * 2.0`。

```cangjie
public operator func *(factor: Float32): Length
```

**参数**

- `factor`: `Float32` — 缩放因子，不做检查，负因子产生负长度。

**返回值** `Length` — 数值缩放后的新长度，单位不变。

### operator/

除数值并保留单位。

```cangjie
public operator func /(divisor: Float32): Length
```

**参数**

- `divisor`: `Float32` — 除数，不做除零检查。

**返回值** `Length` — 数值相除后的新长度，单位不变。

## 另请参阅

- [LengthUnit](LengthUnit.md) — 三种单位的语义。
- [LengthUnits](LengthUnits.md) — `100.px` / `24.vp` / `15.fp` 字面量后缀。
- [LengthInsets](LengthInsets.md) — 四边各自携带单位的间距。
- [UiContext.resolve](UiContext.md#resolve) — 布局时的单位换算。
