[cui](../../index.md) › [cui.controls](index.md) › SplitView

# SplitView

位于 `cui.controls` 包的公开类

用一根可拖动分隔条把空间分给两个窗格的容器，让用户在侧栏与文档、列表与详情之间自行调配空间。`axis` 决定切分方向：`Horizontal` 左右并排（分隔条竖直、左右拖），`Vertical` 上下堆叠（分隔条水平、上下拖）。

## 声明

```cangjie
public class SplitView <: Widget
```

## 继承

- [`Widget`](../core/Widget.md)

## 说明

分隔条位置存为第一窗格占内容尺度（可用尺度减去分隔条厚度）的比例，默认由控件的稳定标识保留，也可经 `ratio` 由外部持有以便持久化或协同动画。`minFirst`/`minSecond` 是两窗格各自的最小尺度（逻辑像素），拖动在此边界处停下；容器小到无法同时满足两个最小值时退回按比例切分，两窗格一起缩小而不是把一侧压成负值。

分隔条的命中区在视觉细缝两侧各加宽 3 逻辑像素，细分隔条也容易抓住；悬停或拖动期间申请对应方向的缩放指针形状。分隔条同时是介于两窗格之间的焦点项：聚焦后沿切分轴的方向键每按一次移动 24 逻辑像素。每个窗格是独立的界面构建函数，块内可声明任意多个组件（自动纵向堆叠），无需再包一层容器。

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let app = DesktopApp(WindowSpec("SplitView", 640, 420))
    app.run {
        let ratio = rememberState<Float32>("ratio") {0.5}
        let split = SplitView(ratio: ratio, minFirst: 96.0, minSecond: 96.0, first: {=> Label("导航列表")}) {
            => Label("正文内容")
        }
        // 运行时：拖动分隔条调整两栏比例；聚焦后方向键可做精细调整。
    }
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init(...)`](#init) | 以切分方向、比例与两个窗格构建器构造分栏容器，全部参数具名。 |

**方法**

| 成员 | 说明 |
|---|---|
| [`measure(_: UiContext, available: Size)`](#measure) | 占满全部可用尺寸（[`Widget`](../core/Widget.md) 协议）。 |
| [`layout(ctx: UiContext, rect: Rect)`](#layout) | 按当前比例切出两窗格框架并分别布局（[`Widget`](../core/Widget.md) 协议）。 |
| [`draw(ctx: UiContext)`](#draw) | 先画两窗格再画分隔条（[`Widget`](../core/Widget.md) 协议）。 |
| [`handle(ctx: UiContext, event: UiEvent)`](#handle) | 处理分隔条的抓取、拖动与键盘微调，其余事件派发给两窗格（[`Widget`](../core/Widget.md) 协议）。 |
| [`isFlexible()`](#isflexible) | 恒为 `true`：参与父栈的剩余空间分配（[`Widget`](../core/Widget.md) 协议）。 |
| [`focusableIds()`](#focusableids) | 按第一窗格、分隔条、第二窗格的顺序返回全部焦点项（[`Widget`](../core/Widget.md) 协议）。 |

## 构造函数

### init

以切分方向、比例与两个窗格构建器构造分栏容器，全部参数具名。

```cangjie
public init(
    axis!: Axis = Axis.Horizontal,
    ratio!: ?Bindable<Float32> = None,
    initialRatio!: Float32 = 0.5,
    minFirst!: Float32 = 96.0,
    minSecond!: Float32 = 96.0,
    dividerThickness!: Float32 = 8.0,
    key!: ?String = None,
    first!: () -> Unit,
    second!: () -> Unit
)
```

**参数**

- `axis!`: [`Axis`](../core/Axis.md) — 切分方向；默认 `Axis.Horizontal` 左右并排，`Vertical` 上下堆叠。
- `ratio!`: `?`[`Bindable`](../core/Bindable.md)`<Float32>` — 外部持有的分隔比例（0–1，第一窗格占内容尺度的份额）；默认 `None`，比例由视图标识内部保留。
- `initialRatio!`: `Float32` — 内部保留比例时的初值，限制在 0–1；默认 `0.5` 平分。传入 `ratio` 时忽略。
- `minFirst!`: `Float32` — 第一窗格的最小尺度（逻辑像素），负值按 `0.0` 计；默认 `96.0`。
- `minSecond!`: `Float32` — 第二窗格的最小尺度（逻辑像素），负值按 `0.0` 计；默认 `96.0`。
- `dividerThickness!`: `Float32` — 分隔条占用的厚度（逻辑像素），最小 `1.0`；默认 `8.0`。
- `key!`: `?String` — 稳定标识，须在同一次构建内唯一；默认 `None` 按声明顺序自动派生，需要跨结构变化保留比例时传入。
- `first!`: `() -> Unit` — 第一窗格（左/上）的界面构建函数。
- `second!`: `() -> Unit` — 第二窗格（右/下）的界面构建函数，通常写作尾随闭包。

**异常**

- `IllegalArgumentException` — `key` 传入空字符串时。

## 方法

### measure

占满全部可用尺寸（[`Widget`](../core/Widget.md) 协议）。

```cangjie
public func measure(_: UiContext, available: Size): Size
```

**参数**

- `available`: `Size` — 父级提供的可用尺寸（逻辑像素）。

**返回值** `Size` — 与 `available` 相同。

### layout

按当前比例切出两窗格框架并分别布局（[`Widget`](../core/Widget.md) 协议）。第一窗格尺度＝比例 × 内容尺度，再按窗格最小值限制；第二窗格取分隔条之后的剩余空间。

```cangjie
public func layout(ctx: UiContext, rect: Rect): Unit
```

**参数**

- `ctx`: [`UiContext`](../core/UiContext.md) — 帧服务上下文。
- `rect`: `Rect` — 分配给容器的框架矩形（逻辑像素）。

### draw

先画两窗格再画分隔条（[`Widget`](../core/Widget.md) 协议）。分隔条是细缝中央的一根发丝线加三点抓握纹，悬停或拖动时提亮为强调色，键盘聚焦时叠加焦点环。

```cangjie
public func draw(ctx: UiContext): Unit
```

**参数**

- `ctx`: `UiContext` — 帧服务上下文。

### handle

处理分隔条的抓取、拖动与键盘微调，其余事件派发给两窗格（[`Widget`](../core/Widget.md) 协议）。左键按在加宽命中区内即聚焦分隔条并开始拖动，记录抓取偏移使细缝不跳到指针下；拖动期间指针移出细缝仍持续跟随；聚焦后沿切分轴的方向键微调 24 逻辑像素（横向 Left/Right，纵向 Up/Down）。帧事件同时发给两个窗格且不消费。

```cangjie
public func handle(ctx: UiContext, event: UiEvent): Bool
```

**参数**

- `ctx`: `UiContext` — 帧服务上下文。
- `event`: `UiEvent` — 本帧派发的输入事件。

**返回值** `Bool` — 分隔条消费了事件，或任一窗格消费了事件时为 `true`。

### isFlexible

恒为 `true`：参与父栈的剩余空间分配（[`Widget`](../core/Widget.md) 协议）。

```cangjie
public func isFlexible(): Bool
```

**返回值** `Bool` — 恒为 `true`。

### focusableIds

按第一窗格、分隔条、第二窗格的顺序返回全部焦点项（[`Widget`](../core/Widget.md) 协议）。分隔条因此在 Tab 顺序里正好落在两窗格之间。

```cangjie
public func focusableIds(): Array<String>
```

**返回值** `Array<String>` — 按遍历顺序排列的焦点项：第一窗格子树、分隔条自身、第二窗格子树。

## 另请参阅

- [TreeView](TreeView.md) — 常与分栏搭配的层级导航（见 `examples/file_explorer`）。
- [Axis](../core/Axis.md) — 切分方向枚举。
