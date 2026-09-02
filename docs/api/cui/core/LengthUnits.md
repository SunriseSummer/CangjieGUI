[cui](../../index.md) › [cui.core](index.md) › LengthUnits

# LengthUnits

位于 `cui.core` 包的公开接口

为数值字面量提供 `.px`/`.vp`/`.fp` 长度后缀的接口。`Int64` 与 `Float64` 的[扩展](extensions.md)实现了它，使 `100.px`、`24.vp`、`1.5.vp`、`15.fp` 直接产出 [`Length`](Length.md)；导入本接口（`cui` 根包已再导出）即启用后缀。

## 声明

```cangjie
public interface LengthUnits
```

## 继承

- 实现者：[`Int64` 与 `Float64` 的扩展](extensions.md)

## 示例

```cangjie verify
package docexample

import cui.*

func asVp(value: LengthUnits): Length {
    value.vp
}

main(): Unit {
    let cardWidth = asVp(320) // Int64 通过 LengthUnits 提供 vp
    let hairline = 1.px // 物理 1 像素，HiDPI 下仍是一根细线
    let bodyText = 15.5.fp // Float64 后缀，随用户字体缩放
    println(
        "${Int64(cardWidth.value)}${cardWidth.unit.symbol()} ${Int64(hairline.value)}${hairline.unit.symbol()} ${bodyText.unit.symbol()}")
    // 输出: 320vp 1px fp
}
```

## 成员概览

**属性**

| 成员 | 说明 |
|---|---|
| [`px`](#px) | 该数值作为物理设备像素的长度。 |
| [`vp`](#vp) | 该数值作为虚拟（密度无关）像素的长度。 |
| [`fp`](#fp) | 该数值作为字体像素的长度，随用户字体缩放。 |

## 属性

### px

该数值作为物理设备像素的长度。解析时除以窗口显示缩放，适合"物理上恰好一像素"的细节。

```cangjie
prop px: Length
```

**返回值** [`Length`](Length.md) — 单位为 `LengthUnit.Px`，只读。

### vp

该数值作为虚拟（密度无关）像素的长度。虚拟像素就是布局用的逻辑坐标单位，是尺寸 API 的常规选择。

```cangjie
prop vp: Length
```

**返回值** [`Length`](Length.md) — 单位为 `LengthUnit.Vp`，只读。

### fp

该数值作为字体像素的长度，随用户字体缩放。专供文字尺寸，让排版跟随系统无障碍设置。

```cangjie
prop fp: Length
```

**返回值** [`Length`](Length.md) — 单位为 `LengthUnit.Fp`，只读。

## 另请参阅

- [扩展成员](extensions.md) — `Int64` / `Float64` 的具体实现。
- [Length](Length.md) — 后缀产出的类型。
- [LengthUnit](LengthUnit.md) — 三种单位的语义。
