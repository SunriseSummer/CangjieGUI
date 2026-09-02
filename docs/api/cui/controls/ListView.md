[cui](../../index.md) › [cui.controls](index.md) › ListView

# ListView

位于 `cui.controls` 包的公开类

单选字符串列表：可滚动的行列表，点击或键盘移动选择，双向绑定选中下标 `Bindable<Int64>`。选中行画强调色底；聚焦后 ↑/↓/Home/End 移动选择并把新行滚入视区。

## 声明

```cangjie
public class ListView <: Widget
```

## 继承

- [`Widget`](../core/Widget.md) — 组件协议（measure/layout/draw/handle 与焦点遍历）。

## 说明

滚动偏移默认由控件标识内部保留；传 `scroll`（或链式调用 [`scrollState`](#scrollstate)）改用外部 [`State`](../core/State.md)`<Float32>` 持有，可用于恢复位置或与别的视图联动。选择变化时（无论来自点击、键盘还是应用直接改写绑定）选中行都会滚入视区；单纯的滚动不回拉选择。内容装得下时滚轮不消费，留给外层滚动容器。

行高固定 28 逻辑像素，仅绘制可见行。每行渲染一条纯文本；要自定义行内容，用 [`LazyColumn`](../core/LazyColumn.md) 等按需构建容器自行组合。

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let app = DesktopApp(WindowSpec("ListView", 640, 420))
    app.run {
        let cities = ["北京", "上海", "广州", "深圳", "成都"]
        let selected = rememberState<Int64>("selected") {0}
        let list = ListView(cities, selected)
        // 运行时：点击行或用方向键移动选择，当前城市由绑定下标保存。
    }
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init(...)`](#init) | 由选项与选中下标绑定构造列表，可选外部滚动状态与显式标识。 |

**方法**

| 成员 | 说明 |
|---|---|
| [`scrollState(value: State<Float32>)`](#scrollstate) | 改用外部持有的滚动偏移并返回自身，支持位置恢复与联动。 |
| [`measure(_: UiContext, available: Size)`](#measure) | 占满可用空间（宽高均取 `available`）。 |
| [`layout(_: UiContext, rect: Rect)`](#layout) | 记录分配到的框架。 |
| [`draw(ctx: UiContext)`](#draw) | 画底面、可见行与选中高亮、滚动条；选择变化时把选中行滚入视区。 |
| [`handle(ctx: UiContext, event: UiEvent)`](#handle) | 点击选行、滚轮与滚动条拖动滚动；聚焦时 ↑/↓/Home/End 移动选择。 |
| [`isFlexible()`](#isflexible) | 恒返回 `true`——列表在栈中分得剩余空间。 |
| [`focusableId()`](#focusableid) | 返回本控件的焦点 id。 |

## 构造函数

### init

由选项与选中下标绑定构造列表，可选外部滚动状态与显式标识。

```cangjie
public init(
    items: Array<String>,
    selected: Bindable<Int64>,
    scroll!: ?State<Float32> = None,
    key!: ?String = None
)
```

**参数**

- `items`: `Array<String>` — 行文本。
- `selected`: `Bindable<Int64>` — 双向绑定的选中下标；外部赋值会把该行滚入视区。
- `scroll!`: `?State<Float32>` — 外部持有的滚动偏移（逻辑像素）。默认 `None`，偏移由控件标识内部保留。
- `key!`: `?String` — 显式控件标识，让滚动与选择状态跨结构变化保持；空串抛 `IllegalArgumentException`。默认 `None`，按构建顺序自动派生。

## 方法

### scrollState

改用外部持有的滚动偏移并返回自身，支持位置恢复与联动。等价于构造参数 `scroll`，便于链式声明。

```cangjie
public func scrollState(value: State<Float32>): ListView
```

**参数**

- `value`: `State<Float32>` — 外部滚动偏移，逻辑像素；控件滚动时写回它。

**返回值** `ListView` — 本实例，支持 `ListView(...).scrollState(...)` 链式写法。

### measure

占满可用空间（宽高均取 `available`）。列表填满栈分配的区域（见 [`Widget`](../core/Widget.md)）。

```cangjie
public func measure(_: UiContext, available: Size): Size
```

**参数**

- `available`: `Size` — 父级给出的可用尺寸约束。

**返回值** `Size` — 组件请求的尺寸；方法接收 `available` 时，该尺寸在父级给出的可用约束内计算。

### layout

记录分配到的框架。行区在框架内缩四周留出边缘。

```cangjie
public func layout(_: UiContext, rect: Rect): Unit
```

**参数**

- `rect`: `Rect` — 父级最终分配给组件的矩形。

### draw

画底面、可见行与选中高亮、滚动条；选择变化时把选中行滚入视区。仅滚入视口的行被绘制；偏移越界时先限制在有效范围。

```cangjie
public func draw(ctx: UiContext): Unit
```

**参数**

- `ctx`: [`UiContext`](../core/UiContext.md) — 本轮绘制使用的 UI 上下文。

### handle

点击选行、滚轮与滚动条拖动滚动；聚焦时 ↑/↓/Home/End 移动选择。点击同时取得键盘焦点；内容装得下时滚轮不消费，留给外层滚动容器。

```cangjie
public func handle(ctx: UiContext, event: UiEvent): Bool
```

**参数**

- `ctx`: [`UiContext`](../core/UiContext.md) — 本轮事件处理使用的 UI 上下文。
- `event`: `UiEvent` — 本轮待处理的 UI 事件。

**返回值** `Bool` — 是否已消费该事件；`true` 表示调用方不应再继续分发。

### isFlexible

恒返回 `true`——列表在栈中分得剩余空间。

```cangjie
public func isFlexible(): Bool
```

**返回值** `Bool` — 固定为 `true`，组件可参与父布局的弹性空间分配。

### focusableId

返回本控件的焦点 id。构造时已注册为焦点项（见 [`Widget`](../core/Widget.md)）。

```cangjie
public func focusableId(): ?String
```

**返回值** `?String` — 该控件用于参与键盘焦点导航的标识。

## 另请参阅

- [Table](Table.md) — 多列、可排序的数据表格。
- [TreeView](TreeView.md) — 层级数据的树形列表。
- [LazyColumn](../core/LazyColumn.md) — 自定义行内容的按需构建列表。
