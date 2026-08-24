[cui](../../index.md) › [cui.core](index.md) › Label

# Label

`cui.core` 包中的 public class

单行或多行文本组件：默认单行、溢出以省略号截断，字体样式经链式构建器就地配置。[`maxLines`](#maxlines) 允许换行至 n 行（仍有剩余文本时最后一行加省略号），[`wrap`](#wrap) 取消行数上限。

## 声明

```cangjie
public class Label <: Widget
```

## 继承

Label <: [`Widget`](Widget.md)

## 说明

粗体、斜体、下划线与删除线经 sdl 的 `FontStyle` 在文本渲染层实时合成，对字体覆盖的所有文字（拉丁与中日韩皆同）生效；`fontFamily` 切换到 `Fonts.register` 注册过的应用字体（语义权威：sdl 模块文档）。显式的 `foregroundColor` 优先于 `muted`。

多行排版把字形宽度、Unicode 字素簇和合法断行机会分开处理：组合附加符、ZWJ emoji、旗帜区域指示符与常见 Indic/Hangul 序列不会被截断；硬换行、NBSP/WJ 和 CJK 开闭标点遵循 UAX #14 风格禁则，实在放不下时只在完整字素簇边界紧急换行。冷布局通过 SDL_ttf 有界前缀测量避免反复塑形整段余串；结果进入 `UiContext` 共享、4 MiB 字节预算的真 LRU，因此每帧重建同一 Label 仍可命中。Label 实例自身还在 measure/draw 间复用结果；更改样式、字族或行数上限会重新查询完整键。

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let app = DesktopApp(WindowSpec("Label", 640, 420))
    app.run {
        let notice = "本次更新修复了若干问题，并改进了长文本的折行表现。"
        VStack(spacing: 12.vp) {
            Label("发布说明").bold().fontSize(20.0)
            Label(notice).wrap().width(240.0)
            Label("最近保存于 12:30").muted().textAlign(TextAlign.Trailing)
        }.padding(24.0)
        // 运行时：窗口同时显示加粗标题、自动折行正文与右对齐次要文本。
    }
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init(...)`](#init) | 创建文本标签：文本，以及可选的次要色、对齐、颜色与字号。 |

**方法**

| 成员 | 说明 |
|---|---|
| [`muted()`](#muted) | 使用（或按 `value` 开关）主题的次要文字色。 |
| [`muted(value: Bool)`](#muted) | 使用（或按 `value` 开关）主题的次要文字色。 |
| [`textAlign(value: TextAlign)`](#textalign) | 设置文本在分配帧内的水平对齐。 |
| [`foregroundColor(value: Color)`](#foregroundcolor) | 覆盖主题推导的文字颜色。 |
| [`fontSize(value: Length)`](#fontsize) | 设置字号。 |
| [`fontSize(value: Float32)`](#fontsize) | 设置字号。 |
| [`fontStyle(value: FontStyle)`](#fontstyle) | 一次替换整个文本样式（字重、倾斜与装饰线）。 |
| [`bold(value!: Bool)`](#bold) | 加粗文本（或把粗体设为 `value`）。 |
| [`italic(value!: Bool)`](#italic) | 倾斜文本（或把斜体设为 `value`）。 |
| [`underline(value!: Bool)`](#underline) | 给文本加下划线（或把下划线设为 `value`）。 |
| [`strikethrough(value!: Bool)`](#strikethrough) | 给文本加删除线（或把删除线设为 `value`）。 |
| [`fontFamily(name: String)`](#fontfamily) | 用已注册的应用字体绘制文本。 |
| [`maxLines(value: Int64)`](#maxlines) | 允许文本换行至最多 `value` 行，仍有剩余文本时最后一行以省略号截断。 |
| [`wrap()`](#wrap) | 取消行数上限，让文本按需换行。 |
| [`measure(...)`](#measure) | 单行时按整段文本宽度测量，多行时先按可用宽度折行、再报告最宽行与行数决定的高度。 |
| [`layout(...)`](#layout) | 记录分配的帧矩形。 |
| [`draw(...)`](#draw) | 绘制文本：单行溢出时省略号截断，多行时逐行绘制并整体垂直居中。 |
| [`handle(...)`](#handle) | 恒返回 `false`：标签不交互。 |

## 构造函数

### init

创建文本标签：文本，以及可选的次要色、对齐、颜色与字号。构造时自动注册进包围它的界面构建函数。

```cangjie
public init(
    text: String,
    muted!: Bool = false,
    align!: TextAlign = TextAlign.Leading,
    color!: ?Color = None,
    fontSize!: Length = Length(FontSizes.BODY, LengthUnit.Fp)
)
```

**参数**

- `text`: `String` — 要显示的文本；构造后不可变，变化的文本每帧重建标签即可。
- `muted!`: `Bool` — 是否用主题的次要文字色；默认 `false`。
- `align!`: [`TextAlign`](TextAlign.md) — 帧内水平对齐；默认 `TextAlign.Leading`。
- `color!`: `?Color` — 显式文字颜色，优先于 `muted`；默认 `None`，按 `muted` 从主题取色。
- `fontSize!`: [`Length`](Length.md) — 字号；默认 `Length(FontSizes.BODY, LengthUnit.Fp)`（15 fp，随用户字体缩放）。

## 方法

### muted

使用（或按 `value` 开关）主题的次要文字色。无参形式恒开启；显式的 `foregroundColor` 优先。返回 `this` 便于链式调用。

```cangjie
public func muted(): Label
```

```cangjie
public func muted(value: Bool): Label
```

**参数**

- `value`: `Bool` — `true` 用次要文字色，`false` 恢复常规文字色。

**返回值** `Label` — `this`。

### textAlign

设置文本在分配帧内的水平对齐。多行时逐行生效。返回 `this` 便于链式调用。

```cangjie
public func textAlign(value: TextAlign): Label
```

**参数**

- `value`: [`TextAlign`](TextAlign.md) — `Leading`、`Center` 或 `Trailing`。

**返回值** `Label` — `this`。

### foregroundColor

覆盖主题推导的文字颜色。设置后 `muted` 不再生效。返回 `this` 便于链式调用。

```cangjie
public func foregroundColor(value: Color): Label
```

**参数**

- `value`: `Color` — 文字颜色。

**返回值** `Label` — `this`。

### fontSize

设置字号。`Float32` 重载按字体像素（fp）解释，随用户字体缩放；`Length` 形式可写 `.fontSize(15.fp)`。返回 `this` 便于链式调用。

```cangjie
public func fontSize(value: Length): Label
```

```cangjie
public func fontSize(value: Float32): Label
```

**参数**

- `value`: [`Length`](Length.md) 或 `Float32` — 字号；`Float32` 形式等价于 `Length(value, LengthUnit.Fp)`。

**返回值** `Label` — `this`。

### fontStyle

一次替换整个文本样式（字重、倾斜与装饰线）。逐项开关用 [`bold`](#bold) / [`italic`](#italic) / [`underline`](#underline) / [`strikethrough`](#strikethrough)。返回 `this` 便于链式调用。

```cangjie
public func fontStyle(value: FontStyle): Label
```

**参数**

- `value`: `FontStyle` — 完整文本样式（sdl 类型）。

**返回值** `Label` — `this`。

### bold

加粗文本（或把粗体设为 `value`）。返回 `this` 便于链式调用。

```cangjie
public func bold(value!: Bool = true): Label
```

**参数**

- `value!`: `Bool` — 是否加粗；默认 `true`。

**返回值** `Label` — `this`。

### italic

倾斜文本（或把斜体设为 `value`）。返回 `this` 便于链式调用。

```cangjie
public func italic(value!: Bool = true): Label
```

**参数**

- `value!`: `Bool` — 是否倾斜；默认 `true`。

**返回值** `Label` — `this`。

### underline

给文本加下划线（或把下划线设为 `value`）。返回 `this` 便于链式调用。

```cangjie
public func underline(value!: Bool = true): Label
```

**参数**

- `value!`: `Bool` — 是否加下划线；默认 `true`。

**返回值** `Label` — `this`。

### strikethrough

给文本加删除线（或把删除线设为 `value`）。返回 `this` 便于链式调用。

```cangjie
public func strikethrough(value!: Bool = true): Label
```

**参数**

- `value!`: `Bool` — 是否加删除线；默认 `true`。

**返回值** `Label` — `this`。

### fontFamily

用已注册的应用字体绘制文本。未知名称或字体文件加载失败时回退到平台 UI 字体；注册入口是 sdl 的 `Fonts.register`。返回 `this` 便于链式调用。

```cangjie
public func fontFamily(name: String): Label
```

**参数**

- `name`: `String` — 注册时使用的字体名。

**返回值** `Label` — `this`。

### maxLines

允许文本换行至最多 `value` 行，仍有剩余文本时最后一行以省略号截断。返回 `this` 便于链式调用。

```cangjie
public func maxLines(value: Int64): Label
```

**参数**

- `value`: `Int64` — 行数上限，须为正。

**返回值** `Label` — `this`。

**异常**

- `IllegalArgumentException` — `value` 不为正数时。

### wrap

取消行数上限，让文本按需换行。等价于 `maxLines(Int64.Max)`。返回 `this` 便于链式调用。

```cangjie
public func wrap(): Label
```

**返回值** `Label` — `this`。

### measure

单行时按整段文本宽度测量，多行时先按可用宽度折行、再报告最宽行与行数决定的高度。宽度不超过可用宽度，高度下限为小控件高（28 逻辑像素）。

```cangjie
public func measure(ctx: UiContext, available: Size): Size
```

**参数**

- `ctx`: [`UiContext`](UiContext.md) — 本轮测量使用的 UI 上下文。
- `available`: `Size` — 父级给出的可用尺寸约束。

**返回值** `Size` — 标签的首选尺寸，逻辑像素。

### layout

记录分配的帧矩形。

```cangjie
public func layout(_: UiContext, rect: Rect): Unit
```

**参数**

- `rect`: `Rect` — 父级最终分配给组件的矩形。

### draw

绘制文本：单行溢出时省略号截断，多行时逐行绘制并整体垂直居中。省略号的二分查找只在文本确实溢出时运行，放得下的单行标签不做多余测量。

```cangjie
public func draw(ctx: UiContext): Unit
```

**参数**

- `ctx`: [`UiContext`](UiContext.md) — 本轮绘制使用的 UI 上下文。

### handle

恒返回 `false`：标签不交互。

```cangjie
public func handle(_: UiContext, _: UiEvent): Bool
```

**返回值** `Bool` — 恒为 `false`。

## 另请参阅

- [TextAlign](TextAlign.md) — 水平对齐枚举。
- [RichText](../controls/RichText.md) — 一段内混排多种样式的富文本。
- [Tooltip](Tooltip.md) — 完整文本放不下时的悬停补充。
