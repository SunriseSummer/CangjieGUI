[cui](../../index.md) › [cui.core](index.md) › LengthUnit

# LengthUnit

位于 `cui.core` 包的公开枚举

长度值的单位：物理像素 `Px`、虚拟像素 `Vp` 或随用户字体缩放的字体像素 `Fp`。[`Length`](Length.md) 携带它，[`UiContext.resolve`](UiContext.md#resolve) 在布局时据此把数值换算为逻辑像素。

## 声明

```cangjie
public enum LengthUnit
```

## 说明

CUI 在逻辑坐标空间中布局，三种单位描述数值如何映射进这个空间：`Vp` 就是逻辑坐标单位本身，解析即原值；`Px` 是物理设备像素，解析时除以窗口显示缩放；`Fp` 是虚拟像素再乘以用户字体缩放，专供文字尺寸跟随系统无障碍设置。

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    ctx.displayScale = 2.0 // 2 倍 HiDPI 屏
    ctx.fontScale = 1.25 // 用户把字体放大 25%
    let px = ctx.resolve(Length(100.0, LengthUnit.Px))
    let vp = ctx.resolve(Length(100.0, LengthUnit.Vp))
    let fp = ctx.resolve(Length(100.0, LengthUnit.Fp))
    println("100px→${Int64(px)}，100vp→${Int64(vp)}，100fp→${Int64(fp)}（逻辑像素）")
    // 输出: 100px→50，100vp→100，100fp→125（逻辑像素）
}
```

## 成员概览

**方法**

| 成员 | 说明 |
|---|---|
| [`symbol()`](#symbol) | 返回单位的小写符号：`"px"`、`"vp"` 或 `"fp"`。 |

**枚举值**

| 成员 | 说明 |
|---|---|
| `Px` | 物理设备像素；解析时除以窗口显示缩放。 |
| `Vp` | 虚拟（密度无关）像素——逻辑坐标单位本身，解析即原值。 |
| `Fp` | 字体像素——虚拟像素再乘以用户字体缩放，供文字尺寸跟随无障碍设置。 |

## 方法

### symbol

返回单位的小写符号：`"px"`、`"vp"` 或 `"fp"`。[`Length.toString`](Length.md#tostring) 用它拼出 `16.0vp` 这样的表示。

```cangjie
public func symbol(): String
```

**返回值** `String` — 对应单位的两字母符号。

## 另请参阅

- [Length](Length.md) — 携带本单位的一维尺寸。
- [LengthUnits](LengthUnits.md) — `100.px` / `24.vp` / `15.fp` 字面量后缀。
- [UiContext.resolve](UiContext.md#resolve) — 按单位换算到逻辑像素。
