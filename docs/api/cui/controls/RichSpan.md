[cui](../../index.md) › [cui.controls](index.md) › RichSpan

# RichSpan

位于 `cui.controls` 包的公开结构体

[`RichText`](RichText.md) 中的一段带样式行内片段：一段文本或一枚行内图标，可逐段配色、加粗、斜体、加装饰线、换字体、调字号、垫高亮底或挂点击动作。用工厂起步（[`text`](#text)、[`muted`](#muted)、[`icon`](#icon)），再链式调用样式方法逐项配置。

## 声明

```cangjie
public struct RichSpan
```

## 说明

`RichSpan` 是纯值：每个链式方法都返回应用该配置后的新片段，原值不变，可放心复用与组合。未调用 `fontSize` 的片段继承宿主 [`RichText`](RichText.md) 的基准字号；同一行内不同字号的片段相互居中，行高随最高者增长。

[`highlight`](#highlight) 在片段身后垫一块 `<mark>` 式圆角底色，恰好覆盖片段的各个绘制盒——相邻两个各自加高亮的片段会在接缝处各自倒圆角，应当连成一体的标记要写进同一个片段。[`onTap`](#ontap) 把片段变成可点击链接：指针悬停变交互形状、可经 Tab 聚焦，命中与激活由宿主 `RichText` 处理。

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let app = DesktopApp(WindowSpec("RichSpan", 640, 420))
    app.run {
        let spans = [
            RichSpan.text("128").bold().fontSize(30.0),
            RichSpan.muted(" MB/s").fontSize(13.0),
            RichSpan.text(" 峰值", color: Color.rgb(220, 120, 40)).italic().highlight(Color.rgb(255, 240, 210))
        ]
        let stat = RichText(spans)
        let plain = RichText([RichSpan.text("128 MB/s 峰值")])
        // 运行时：窗口显示由不同字号、颜色和粗细 RichSpan 组成的一行富文本。
    }
}
```

## 成员概览

**方法**

| 成员 | 说明 |
|---|---|
| [`static text(text: String, color!: ?Color = None)`](#text) | 一段按默认文本色（或显式 `color`）绘制的文本片段。 |
| [`static muted(text: String)`](#muted) | 一段按主题次要（弱化）文本色绘制的文本片段。 |
| [`static icon(icon: IconName, color!: ?Color = None)`](#icon) | 一枚随行高取尺寸的行内图标，可选着色。 |
| [`bold(value!: Bool = true)`](#bold) | 本片段以粗体绘制（或把粗体设为 `value`）。 |
| [`italic(value!: Bool = true)`](#italic) | 本片段以斜体绘制（或把斜体设为 `value`）。 |
| [`underline(value!: Bool = true)`](#underline) | 本片段加下划线（或把下划线设为 `value`）。 |
| [`strikethrough(value!: Bool = true)`](#strikethrough) | 本片段加删除线（或把删除线设为 `value`）。 |
| [`fontStyle(value: FontStyle)`](#fontstyle) | 整体替换本片段的文本样式。 |
| [`fontFamily(name: String)`](#fontfamily) | 本片段改用已注册的应用字体绘制。 |
| [`fontSize(...)`](#fontsize) | 本片段以自有字号绘制，覆盖宿主 `RichText` 的基准字号。 |
| [`onTap(action: () -> Unit)`](#ontap) | 把本片段变成可点击链接：点中即运行 `action`，指针悬停变为交互形状。 |
| [`highlight(background: Color)`](#highlight) | 在本片段身后垫一块 `<mark>` 式圆角高亮底，画在文字或图标之下。 |

## 方法

### text

一段按默认文本色（或显式 `color`）绘制的文本片段。

```cangjie
public static func text(text: String, color!: ?Color = None): RichSpan
```

**参数**

- `text`: `String` — 片段文字。
- `color!`: `?Color` — 显式文字颜色；默认 `None` 用主题文本色。

**返回值** `RichSpan` — 新的文本片段。

### muted

一段按主题次要（弱化）文本色绘制的文本片段。适合单位、注释等辅助文字。

```cangjie
public static func muted(text: String): RichSpan
```

**参数**

- `text`: `String` — 片段文字。

**返回值** `RichSpan` — 新的弱化文本片段。

### icon

一枚随行高取尺寸的行内图标，可选着色。图标与文字同行排布、相互居中。

```cangjie
public static func icon(icon: IconName, color!: ?Color = None): RichSpan
```

**参数**

- `icon`: `IconName` — 内置矢量图标名。
- `color!`: `?Color` — 显式颜色；默认 `None` 用主题文本色。

**返回值** `RichSpan` — 新的图标片段。

### bold

本片段以粗体绘制（或把粗体设为 `value`）。

```cangjie
public func bold(value!: Bool = true): RichSpan
```

**参数**

- `value!`: `Bool` — 默认 `true` 打开粗体；传 `false` 显式关闭。

**返回值** `RichSpan` — 应用该配置后的新片段，原值不变。

### italic

本片段以斜体绘制（或把斜体设为 `value`）。

```cangjie
public func italic(value!: Bool = true): RichSpan
```

**参数**

- `value!`: `Bool` — 默认 `true` 打开斜体；传 `false` 显式关闭。

**返回值** `RichSpan` — 应用该配置后的新片段，原值不变。

### underline

本片段加下划线（或把下划线设为 `value`）。

```cangjie
public func underline(value!: Bool = true): RichSpan
```

**参数**

- `value!`: `Bool` — 默认 `true` 打开下划线；传 `false` 显式关闭。

**返回值** `RichSpan` — 应用该配置后的新片段，原值不变。

### strikethrough

本片段加删除线（或把删除线设为 `value`）。

```cangjie
public func strikethrough(value!: Bool = true): RichSpan
```

**参数**

- `value!`: `Bool` — 默认 `true` 打开删除线；传 `false` 显式关闭。

**返回值** `RichSpan` — 应用该配置后的新片段，原值不变。

### fontStyle

整体替换本片段的文本样式。一次给齐粗体/斜体/下划线/删除线时比逐项链式更直接。

```cangjie
public func fontStyle(value: FontStyle): RichSpan
```

**参数**

- `value`: `FontStyle` — 新的完整文本样式（sdl 模块类型）。

**返回值** `RichSpan` — 应用该配置后的新片段，原值不变。

### fontFamily

本片段改用已注册的应用字体绘制。字体须先经 `Fonts.register`（sdl 模块）注册。

```cangjie
public func fontFamily(name: String): RichSpan
```

**参数**

- `name`: `String` — 注册时使用的字体名。

**返回值** `RichSpan` — 应用该配置后的新片段，原值不变。

### fontSize

本片段以自有字号绘制，覆盖宿主 `RichText` 的基准字号。两个重载分别接受带单位的 [`Length`](../core/Length.md) 与字体像素（fp）数值。

```cangjie
public func fontSize(value: Length): RichSpan
```

```cangjie
public func fontSize(value: Float32): RichSpan
```

**参数**

- `value`: [`Length`](../core/Length.md) — `Length` 重载接收带单位的字号；`Float32` 重载接收字体像素（fp）数值，随用户字体缩放。

**返回值** `RichSpan` — 应用该配置后的新片段，原值不变。

### onTap

把本片段变成可点击链接：点中即运行 `action`，指针悬停变为交互形状。链接片段还会成为键盘焦点项——Tab 聚焦、Enter/Space 激活，由宿主 `RichText` 登记与分发。

```cangjie
public func onTap(action: () -> Unit): RichSpan
```

**参数**

- `action`: `() -> Unit` — 点中任一属于本片段的绘制盒时运行的动作。

**返回值** `RichSpan` — 应用该配置后的新片段，原值不变。

### highlight

在本片段身后垫一块 `<mark>` 式圆角高亮底，画在文字或图标之下。文字颜色不变——需要可读对比时配合 `text(color:)` 显式设色；底盒恰好覆盖本片段的绘制盒，相邻片段各自高亮会在接缝处各倒圆角，连续标记应写进同一片段。

```cangjie
public func highlight(background: Color): RichSpan
```

**参数**

- `background`: `Color` — 高亮底色。

**返回值** `RichSpan` — 应用该配置后的新片段，原值不变。

## 另请参阅

- [RichText](RichText.md) — 排布并绘制片段序列的宿主组件。
- [Length](../core/Length.md) — 带单位的字号表达。
