[cui](../../index.md) › [cui.controls](index.md) › Breadcrumb

# Breadcrumb

位于 `cui.controls` 包的公开类

面包屑路径：以箭头分隔的一行层级段（如 首页 › 文档 › 项目），末段为当前位置、前段可点击返回上级路径。点击前段以其下标调用 `onSelect`；不传 `onSelect` 时整条是纯展示。

## 声明

```cangjie
public class Breadcrumb <: Widget
```

## 继承

- [`Widget`](../core/Widget.md) — 组件协议（measure/layout/draw/handle 与焦点遍历）。

## 说明

末段始终以正文色强调显示且不可点击；可点击的前段用主题强调色，悬停时显示底色。设置 `maxItems` 且段数超过它时，中段折叠为省略号，保留首段与末尾 `maxItems - 1` 段——例如 7 段限 4 时显示"首段 › … › 第 5、6、7 段"。省略号本身不可点击。

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let app = DesktopApp(WindowSpec("Breadcrumb", 640, 420))
    app.run {
        let jumpedTo = rememberState<Int64>("jumpedTo") {-1}
        VStack(spacing: 12.vp) {
            Breadcrumb(["首页", "文档", "季度报告"], onSelect: {index => jumpedTo.value = index})
            Label(if (jumpedTo.value < 0) {
                "尚未选择上级路径"
            } else {
                "已选择第 ${jumpedTo.value + 1} 段"
            }).muted()
        }.padding(24.0)
        // 运行时：点击“首页”或“文档”返回上级路径，末段保持为不可点击的当前位置。
    }
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init(...)`](#init) | 由路径段构造面包屑，可选路径选择回调与折叠上限。 |

**方法**

| 成员 | 说明 |
|---|---|
| [`measure(ctx: UiContext, _: Size)`](#measure) | 各段宽度（文本加左右各 7 逻辑像素）与分隔符（各 18 逻辑像素）之和，高度固定 28。 |
| [`layout(ctx: UiContext, rect: Rect)`](#layout) | 从左到右排布各段与分隔符。 |
| [`isFlexible()`](#isflexible) | 恒返回 `false`——面包屑贴合内容，不参与栈的剩余空间分配。 |
| [`draw(ctx: UiContext)`](#draw) | 绘制各段文本、可点击段的悬停底色与分隔箭头，整体裁剪到自身框架。 |
| [`handle(ctx: UiContext, event: UiEvent)`](#handle) | 点击可点击段时，以该段下标调用 `onSelect` 并消费事件。 |

## 构造函数

### init

由路径段构造面包屑，可选路径选择回调与折叠上限。

```cangjie
public init(segments: Array<String>, onSelect!: ?(Int64) -> Unit = None, maxItems!: Int64 = 0, key!: ?String = None)
```

**参数**

- `segments`: `Array<String>` — 路径段文本，最后一个是当前位置。
- `onSelect!`: `?(Int64) -> Unit` — 点击前段时以其在 `segments` 中的下标回调。默认 `None`，整条为纯展示。
- `maxItems!`: `Int64` — 显示的段数上限；超过时中段折叠为省略号，保留首段与末尾 `maxItems - 1` 段。最小按 2 生效。默认 `0`（不折叠）。
- `key!`: `?String` — 显式控件标识；空串抛 `IllegalArgumentException`。默认 `None`，按构建顺序自动派生。

## 方法

### measure

各段宽度（文本加左右各 7 逻辑像素）与分隔符（各 18 逻辑像素）之和，高度固定 28。忽略可用尺寸（见 [`Widget`](../core/Widget.md)）。

```cangjie
public func measure(ctx: UiContext, _: Size): Size
```

**参数**

- `ctx`: [`UiContext`](../core/UiContext.md) — 本轮测量使用的 UI 上下文。

**返回值** `Size` — 组件请求的尺寸；方法接收 `available` 时，该尺寸在父级给出的可用约束内计算。

### layout

从左到右排布各段与分隔符。

```cangjie
public func layout(ctx: UiContext, rect: Rect): Unit
```

**参数**

- `ctx`: [`UiContext`](../core/UiContext.md) — 本轮布局使用的 UI 上下文。
- `rect`: `Rect` — 父级最终分配给组件的矩形。

### isFlexible

恒返回 `false`——面包屑贴合内容，不参与栈的剩余空间分配。

```cangjie
public func isFlexible(): Bool
```

**返回值** `Bool` — 固定为 `false`，组件按自身请求尺寸参与布局。

### draw

绘制各段文本、可点击段的悬停底色与分隔箭头，整体裁剪到自身框架。末段用正文色，可点击段用强调色，省略号与不可点段用次要文本色。

```cangjie
public func draw(ctx: UiContext): Unit
```

**参数**

- `ctx`: [`UiContext`](../core/UiContext.md) — 本轮绘制使用的 UI 上下文。

### handle

点击可点击段时，以该段下标调用 `onSelect` 并消费事件。末段、省略号，以及未传 `onSelect` 时的所有位置都不响应；悬停在可点击段上时显示交互指针。

```cangjie
public func handle(ctx: UiContext, event: UiEvent): Bool
```

**参数**

- `ctx`: [`UiContext`](../core/UiContext.md) — 本轮事件处理使用的 UI 上下文。
- `event`: `UiEvent` — 本轮待处理的 UI 事件。

**返回值** `Bool` — 是否已消费该事件；`true` 表示调用方不应再继续分发。

## 另请参阅

- [StepIndicator](StepIndicator.md) — 线性流程的步骤指示。
- [TreeView](TreeView.md) — 层级数据的树形导航。
