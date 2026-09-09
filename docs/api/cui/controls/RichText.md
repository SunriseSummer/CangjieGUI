[cui](../../index.md) › [cui.controls](index.md) › RichText

# RichText

位于 `cui.controls` 包的公开类

行内多样式文本组件：把一串 [`RichSpan`](RichSpan.md)（配色、加粗、变字号的文本段与行内图标）排在同一行内，超出可用宽度自动换行到任意多行。是单一样式 [`Label`](../core/Label.md) 的多样式、带图标对应物，统计大数字、更新日志、可点击链接等混排文本都由它承担。

## 声明

```cangjie
public class RichText <: Widget
```

## 继承

`RichText <: Widget` — 实现 [`Widget`](../core/Widget.md) 组件协议。

## 说明

未自带字号的片段继承本组件的基准字号；同一行内不同字号的文字按主字体基线对齐，行高包含各片段的基线上/下距离。换行按文字习惯处理：CJK 逐字可断，空格分隔的文字回退到空格处断行，行中开始的 ASCII 词（标识符、议题号）放得进一行时整词移到下一行、绝不拦腰截断；图标作为方形盒随文字流动。

带 [`onTap`](RichSpan.md#ontap) 的链接片段可交互：按下并在同一片段盒上松开触发动作、悬停显示交互指针；每个链接片段按声明序注册为键盘焦点项，Tab 依次走过、Enter/Space 激活，键盘聚焦的链接画焦点环。不含链接的 `RichText` 不注册、不分配任何交互结构，保持纯静态。

测量语义：内容只占一行时贴合内容宽（行内嵌进横排容器时按内容收身），一旦换行即充满可用宽度。排版结果按宽度、字号与显示缩放缓存，测量与绘制共用，不逐帧重排。

LF、CRLF、CR、NEL（U+0085）、行分隔符（U+2028）和段分隔符（U+2029）强制换行；连续及末尾空行占据对应字号的行高。CRLF 即使位于相邻不同样式片段中也只产生一次换行。换行符不绘制为字形，片段身份与链接命中保留；软换行不会拆开字素簇。跨不同视觉样式片段的统一 shaping 和段落级 bidi 尚未完成。

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let app = DesktopApp(WindowSpec("RichText", 640, 420))
    app.run {
        let opened = rememberState<Int64>("opened") {0}
        let notice = RichText(
            [
                RichSpan.text("同步完成，"),
                RichSpan.text("查看详情").underline().onTap({=> opened.value = opened.value + 1})
            ]
        )
        Label("链接已触发 ${opened.value} 次").muted()
        // 运行时：点击“查看详情”片段触发动作，普通片段只参与排版。
    }
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init(...)`](#init) | 以片段序列与可选基准字号构造多样式文本。 |

**方法**

| 成员 | 说明 |
|---|---|
| [`fontSize(...)`](#fontsize) | 设置未自带字号的片段共享的基准字号。 |
| [`measure(ctx: UiContext, available: Size)`](#measure) | 单行时贴合内容宽、换行后充满可用宽；高度随行内最大字号增长且不低于基准行高。 |
| [`layout(_: UiContext, rect: Rect)`](#layout) | 记录文本框架。 |
| [`draw(ctx: UiContext)`](#draw) | 逐片段画高亮底、文字或图标，给键盘聚焦的链接片段画焦点环；内容块垂直居中，不同控件之间仍由外层布局决定对齐。 |
| [`handle(ctx: UiContext, event: UiEvent)`](#handle) | 链接片段上按下并松开触发其动作、悬停申请交互指针，Enter/Space 激活聚焦链接；无链接时恒不消费。 |
| [`focusableIds()`](#focusableids) | 按声明序返回每个链接片段的焦点项；无链接时为空。 |

## 构造函数

### init

以片段序列与可选基准字号构造多样式文本。

```cangjie
public init(
    spans: Array<RichSpan>,
    fontSize!: ?Length = None,
    key!: ?String = None
)
```

**参数**

- `spans`: `Array<RichSpan>` — 按序排布的片段。
- `fontSize!`: `?`[`Length`](../core/Length.md) — 默认 `None`，继承 TextStyle；无继承值时使用 `FontSizes.BODY`（15 fp）。未自带字号的片段采用该有效基准字号。
- `key!`: `?String` — 显式标识，作链接片段焦点与按压追踪的作用域；默认 `None`，按构建顺序自动派生。

**异常**

- `IllegalArgumentException` — `key` 传入空字符串时。

## 方法

### fontSize

设置未自带字号的片段共享的基准字号。两个重载分别接受带单位的 `Length` 与字体像素（fp）数值。

```cangjie
public func fontSize(value: Length): RichText
```

```cangjie
public func fontSize(value: Float32): RichText
```

**参数**

- `value`: [`Length`](../core/Length.md) — `Length` 重载接收带单位的基准字号；`Float32` 重载接收字体像素（fp）数值，随用户字体缩放。

**返回值** `RichText` — 返回自身以便链式调用。

### measure

单行时贴合内容宽、换行后充满可用宽；高度随行内最大字号增长且不低于基准行高。单行与否按行数判断——一行里孤立的大字号片段仍按单行收身（统计组件“大数值 + 小单位”的典型场景）。[`Widget`](../core/Widget.md) 协议方法。

```cangjie
public func measure(ctx: UiContext, available: Size): Size
```

**参数**

- `ctx`: [`UiContext`](../core/UiContext.md) — 本轮测量使用的 UI 上下文。
- `available`: `Size` — 父级给出的可用尺寸约束。

**返回值** `Size` — 组件请求的尺寸；方法接收 `available` 时，该尺寸在父级给出的可用约束内计算。

### layout

记录文本框架。[`Widget`](../core/Widget.md) 协议方法。

```cangjie
public func layout(_: UiContext, rect: Rect): Unit
```

**参数**

- `rect`: `Rect` — 父级最终分配给组件的矩形。

### draw

逐片段画高亮底、文字或图标，给键盘聚焦的链接片段画焦点环；内容块垂直居中，不同控件之间仍由外层布局决定对齐。[`Widget`](../core/Widget.md) 协议方法。

```cangjie
public func draw(ctx: UiContext): Unit
```

**参数**

- `ctx`: [`UiContext`](../core/UiContext.md) — 本轮绘制使用的 UI 上下文。

### handle

链接片段上按下并松开触发其动作、悬停申请交互指针，Enter/Space 激活聚焦链接；无链接时恒不消费。按下同时把该链接设为焦点锚（不画环），与按钮的按下-释放语义一致。[`Widget`](../core/Widget.md) 协议方法。

```cangjie
public func handle(ctx: UiContext, event: UiEvent): Bool
```

**参数**

- `ctx`: [`UiContext`](../core/UiContext.md) — 本轮事件处理使用的 UI 上下文。
- `event`: `UiEvent` — 本轮待处理的 UI 事件。

**返回值** `Bool` — 是否已消费该事件；`true` 表示调用方不应再继续分发。

### focusableIds

按声明序返回每个链接片段的焦点项；无链接时为空。[`Widget`](../core/Widget.md) 协议方法。

```cangjie
public func focusableIds(): Array<String>
```

**返回值** `Array<String>` — 各可点击链接用于参与键盘焦点导航的标识。

## 字体继承与缩放

构造时省略 fontSize 会继承 TextStyle；显式 `.fontSize(...)` 或构造参数优先。字体族可使用应用注册名或标准系统目录发现的族名。字体/字号/样式、字体版本与实际 raster scale 变化都会使相关布局缓存失效。

## 基线与文本拆段

混合字号使用主字体基线对齐，每行高度包含最大的基线上/下距离。相邻、同字体/字号/样式/颜色，且无链接/高亮的文本片段在 shaping 前合并，避免 `AV` 等仅因拆段而丢失字距。颜色、链接和高亮边界仍保留独立片段；跨这些边界的统一 shaping、段落级双向排版与完整 cluster 绘制映射仍未实现。

## 另请参阅

- [RichSpan](RichSpan.md) — 片段的构建工厂与链式样式配置。
- [Label](../core/Label.md) — 单一样式的普通文本。
