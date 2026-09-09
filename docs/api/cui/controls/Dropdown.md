[cui](../../index.md) › [cui.controls](index.md) › Dropdown

# Dropdown

位于 `cui.controls` 包的公开类

下拉选择框：闭合时显示当前项，展开时把选项列表浮到组件树之上，双向绑定选中下标 `Bindable<Int64>`。点击一项即选中并关闭；点击列表外或按 Escape 撤销；列表经交互浮层浮出，点击不会被下方控件截走。

## 声明

```cangjie
public class Dropdown <: Widget
```

## 继承

- [`Widget`](../core/Widget.md) — 组件协议（measure/layout/draw/handle 与焦点遍历）。

## 说明

弹出列表默认锚在字段下方，整列装不下时翻到上方；两侧都装不下时开在更宽裕的一侧、按该侧高度开出，列表在弹层内滚动——滚轮、标准滚动条车道内的拖拽、以及保持高亮可见的方向键都可用。打开时选中行滚入视图（长列表居中），重开永远不会落在离当前值很远的位置。

打开期间 ↑/↓ 直接移动选中项（写回绑定），Enter/Space/Escape 关闭，Tab 关闭并继续焦点遍历。`items` 为空时字段显示“—”；绑定的下标超出范围时，显示最接近的有效选项。

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let app = DesktopApp(WindowSpec("Dropdown", 640, 420))
    app.run {
        let regions = ["华北", "华东", "华南"]
        let selected = rememberState<Int64>("selected") {0}
        VStack(spacing: 12.vp) {
            Dropdown(regions, selected)
            Label("当前地区：${regions[selected.value]}").muted()
        }.padding(24.0)
        // 运行时：点击下拉字段后选择地区，绑定值与字段文本同步更新。
    }
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init(items: Array<String>, selected: Bindable<Int64>, key!: ?String)`](#init) | 由选项与选中下标绑定构造下拉选择框。 |

**方法**

| 成员 | 说明 |
|---|---|
| [`measure(_: UiContext, available: Size)`](#measure) | 宽为可用宽与 190 逻辑像素的较小者，高度为 `max(38, 有效文字行高 + 16)`。 |
| [`layout(_: UiContext, rect: Rect)`](#layout) | 记录分配到的框架。 |
| [`draw(ctx: UiContext)`](#draw) | 画字段（当前项文本与下箭头）；打开时把选项列表注册为交互浮层。 |
| [`handle(ctx: UiContext, event: UiEvent)`](#handle) | 点击字段展开列表；聚焦时 Enter/Space/↓ 同效。 |
| [`focusableId()`](#focusableid) | 返回本控件的焦点 id。 |
| [`isFlexible()`](#isflexible) | 恒返回 `false`——字段保持固有宽度，不参与栈的剩余空间分配。 |

## 构造函数

### init

由选项与选中下标绑定构造下拉选择框。

```cangjie
public init(items: Array<String>, selected: Bindable<Int64>, key!: ?String = None)
```

**参数**

- `items`: `Array<String>` — 选项文本；为空时字段显示"—"。
- `selected`: `Bindable<Int64>` — 双向绑定的选中下标；超出范围时显示最接近的有效选项。
- `key!`: `?String` — 显式控件标识（同时标识浮层注册）；空串抛 `IllegalArgumentException`。默认 `None`，按构建顺序自动派生。

## 方法

### measure

宽为可用宽与 190 逻辑像素的较小者，高度为 `max(38, 有效文字行高 + 16)`。字段自身贴合固有尺寸（见 [`Widget`](../core/Widget.md)）。

```cangjie
public func measure(ctx: UiContext, available: Size): Size
```

**参数**

- `available`: `Size` — 父级给出的可用尺寸约束。

**返回值** `Size` — 组件请求的尺寸；方法接收 `available` 时，该尺寸在父级给出的可用约束内计算。

### layout

记录分配到的框架。弹出列表与字段同宽。

```cangjie
public func layout(ctx: UiContext, rect: Rect): Unit
```

**参数**

- `rect`: `Rect` — 父级最终分配给组件的矩形。

### draw

画字段（当前项文本与下箭头）；打开时把选项列表注册为交互浮层。聚焦或打开时底面进入活跃态；列表行高为 `max(28, 有效文字行高 + 8)`，只画可见行，超长时带滚动条。

```cangjie
public func draw(ctx: UiContext): Unit
```

**参数**

- `ctx`: [`UiContext`](../core/UiContext.md) — 本轮绘制使用的 UI 上下文。

### handle

点击字段展开列表；聚焦时 Enter/Space/↓ 同效。已打开时的点击由浮层处理，不再落到这里。

```cangjie
public func handle(ctx: UiContext, event: UiEvent): Bool
```

**参数**

- `ctx`: [`UiContext`](../core/UiContext.md) — 本轮事件处理使用的 UI 上下文。
- `event`: `UiEvent` — 本轮待处理的 UI 事件。

**返回值** `Bool` — 是否已消费该事件；`true` 表示调用方不应再继续分发。

### focusableId

返回本控件的焦点 id。构造时已注册为焦点项（见 [`Widget`](../core/Widget.md)）。

```cangjie
public func focusableId(): ?String
```

**返回值** `?String` — 该控件用于参与键盘焦点导航的标识。

### isFlexible

恒返回 `false`——字段保持固有宽度，不参与栈的剩余空间分配。

```cangjie
public func isFlexible(): Bool
```

**返回值** `Bool` — 固定为 `false`，组件按自身请求尺寸参与布局。

## 另请参阅

- [Picker](Picker.md) — 行内分段式的选项选择。
- [ComboBox](../text/ComboBox.md) — 可输入过滤的组合框。
- [ListView](ListView.md) — 常驻展开的选择列表。
