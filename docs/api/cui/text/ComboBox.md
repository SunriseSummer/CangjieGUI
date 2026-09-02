[cui](../../index.md) › [cui.text](index.md) › ComboBox

# ComboBox

位于 `cui.text` 包的公开类

可输入的下拉组合框：在内嵌单行编辑框上浮出建议列表，输入即过滤；绑定文本就是控件的值，自由输入即使不匹配任何选项也被保留。它内嵌一个 [`TextField`](TextField.md)（因此继承完整编辑能力：光标、选区、撤销、剪贴板），建议列表通过与菜单、下拉共用的交互浮层 [`Overlay`](../core/Overlay.md) 浮出。

## 声明

```cangjie
public class ComboBox <: Widget
```

## 继承

`ComboBox <: Widget` — 实现组件接口 [`Widget`](../core/Widget.md)。

## 说明

- **组合结构**：内嵌编辑框与本控件共享同一标识（焦点与状态对齐），且本控件接管其光标与选区锚点——提交建议时才能把光标移到末尾并收起选区，否则陈旧锚点会把新值整段高亮。输入、光标点选、快捷键全部转交内嵌编辑框处理。
- **过滤**：按 ASCII 大小写不敏感的子串匹配过滤建议；空输入显示全部选项。列表打开期间继续输入会实时重过滤，高亮索引超出新列表时被限制在末尾；没有匹配时弹层显示占位行 `—`，点击它只是关闭列表。
- **弹层行为**：默认开在控件下方，只有上方放得下整列时才翻到上方；两侧都放不下时取更宽裕的一侧、按该侧高度打开并在弹层内滚动（滚轮、标准槽位里的可拖滚动条、方向键保持高亮可见）。Escape 关闭；Enter 提交当前高亮；Tab 关闭并把事件放行给宿主的焦点遍历；弹层外按下关闭列表并放行事件（点在下拉箭头上除外——那是开合切换）。
- **值语义**：绑定的 `text` 就是值。选中建议把该项写回绑定并把光标移到末尾；用户自由输入的文本原样保留，控件不做校验或回退。

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let app = DesktopApp(WindowSpec("ComboBox", 640, 420))
    app.run {
        let city = rememberState<String>("city") {""}
        VStack(spacing: 12.vp) {
            ComboBox(city, ["北京", "上海", "深圳"], key: "city")
            Label("当前输入：${city.value}").muted()
        }.padding(24.0)
        // 运行时：输入文字过滤城市建议，方向键选择后按 Enter 提交。
    }
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init(...)`](#init) | 构造组合框：内嵌一个共享本控件标识的编辑框，并接管其光标与选区锚点。 |

**方法**

| 成员 | 说明 |
|---|---|
| [`measure(...)`](#measure) | [`Widget`](../core/Widget.md) 协议实现：占满可用宽度，高度固定为标准控件高 38 逻辑像素。 |
| [`layout(...)`](#layout) | [`Widget`](../core/Widget.md) 协议实现：记录框架矩形，并把同一矩形交给内嵌编辑框布局。 |
| [`draw(...)`](#draw) | [`Widget`](../core/Widget.md) 协议实现：绘制内嵌编辑框与右缘下拉箭头；列表打开时把弹层注册进浮层栈。 |
| [`handle(...)`](#handle) | [`Widget`](../core/Widget.md) 协议实现：处理下拉箭头的开合点击与聚焦时按 Down 打开列表，其余事件转交内嵌编辑框。 |
| [`isFlexible()`](#isflexible) | [`Widget`](../core/Widget.md) 协议实现：返回 `false`，不参与栈布局的剩余空间分配。 |
| [`focusableId()`](#focusableid) | [`Widget`](../core/Widget.md) 协议实现：返回内嵌编辑框的标识——焦点项归内嵌字段所有。 |

## 构造函数

### init

构造组合框：内嵌一个共享本控件标识的编辑框，并接管其光标与选区锚点。

```cangjie
public init(text: Bindable<String>, options: Array<String>, key!: ?String = None)
```

**参数**

- `text`: `Bindable<String>` — 绑定的值；输入与提交都写回这里，当前内容同时作为过滤查询。
- `options`: `Array<String>` — 建议列表的全部候选，按给定顺序展示。
- `key!`: `?String` — 显式控件标识；默认 `None`，按声明顺序自动派生。

**异常**

- `IllegalArgumentException` — `key` 传入空字符串时。

## 方法

### measure

[`Widget`](../core/Widget.md) 协议实现：占满可用宽度，高度固定为标准控件高 38 逻辑像素。

```cangjie
public func measure(_: UiContext, available: Size): Size
```

**参数**

- `available`: `Size` — 父级给出的可用尺寸约束。

**返回值** `Size` — 组件请求的尺寸；方法接收 `available` 时，该尺寸在父级给出的可用约束内计算。

### layout

[`Widget`](../core/Widget.md) 协议实现：记录框架矩形，并把同一矩形交给内嵌编辑框布局。

```cangjie
public func layout(ctx: UiContext, rect: Rect): Unit
```

**参数**

- `ctx`: [`UiContext`](../core/UiContext.md) — 本轮布局使用的 UI 上下文。
- `rect`: `Rect` — 父级最终分配给组件的矩形。

### draw

[`Widget`](../core/Widget.md) 协议实现：绘制内嵌编辑框与右缘下拉箭头；列表打开时把弹层注册进浮层栈。弹层以本控件为属主每帧重注册，保持既有 z 位置，关闭时只移除自己的注册（下方的对话框保持打开）。

```cangjie
public func draw(ctx: UiContext): Unit
```

**参数**

- `ctx`: [`UiContext`](../core/UiContext.md) — 本轮绘制使用的 UI 上下文。

### handle

[`Widget`](../core/Widget.md) 协议实现：处理下拉箭头的开合点击与聚焦时按 Down 打开列表，其余事件转交内嵌编辑框。列表打开后的键盘导航与列表点击由注册的浮层处理器接管。

```cangjie
public func handle(ctx: UiContext, event: UiEvent): Bool
```

**参数**

- `ctx`: [`UiContext`](../core/UiContext.md) — 本轮事件处理使用的 UI 上下文。
- `event`: `UiEvent` — 本轮待处理的 UI 事件。

**返回值** `Bool` — 是否已消费该事件；`true` 表示调用方不应再继续分发。

### isFlexible

[`Widget`](../core/Widget.md) 协议实现：返回 `false`，不参与栈布局的剩余空间分配。

```cangjie
public func isFlexible(): Bool
```

**返回值** `Bool` — 固定为 `false`，组件按自身请求尺寸参与布局。

### focusableId

[`Widget`](../core/Widget.md) 协议实现：返回内嵌编辑框的标识——焦点项归内嵌字段所有。

```cangjie
public func focusableId(): ?String
```

**返回值** `?String` — 内嵌文本字段用于参与键盘焦点导航的标识。

## 另请参阅

- [TextField](TextField.md) — 内嵌的单行编辑框，编辑能力的来源。
- [Overlay](../core/Overlay.md) — 建议列表浮出所用的交互浮层。
- [Dropdown](../controls/Dropdown.md) — 只选不输的下拉选择控件。
