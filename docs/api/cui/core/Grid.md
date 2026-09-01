[cui](../../index.md) › [cui.core](index.md) › Grid

# Grid

`cui.core` 包中的 public class

把子组件排进固定列数、等宽单元格的网格容器，行高取本行最高的单元格。子组件按行主序（从左到右、从上到下）填入，是键盘、指标卡墙、商品卡片墙的直接写法。

## 声明

```cangjie
public class Grid <: Widget
```

## 继承

Grid <: [`Widget`](Widget.md)

## 说明

网格总是占满分到的宽度：单元格宽 =（宽度 −（列数 − 1）× 水平间隙）÷ 列数，行数由参与布局的子组件数除以列数向上取整得出。单元格内接受拉伸的轴撑满单元格，否则保持测量尺寸，超出单元格的部分被限制。不参与布局的子组件（`.visible(false)`）被跳过、不占格位；要保留空格位，放一个空的 [`Flexible`](Flexible.md)`{}` 或 [`Spacer`](Spacer.md)。

`columns` 必须为正，否则构造即抛出 `IllegalArgumentException`。

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let app = DesktopApp(WindowSpec("Grid", 640, 420))
    app.run {
        let keys = ["7", "8", "9", "÷", "4", "5", "6", "×"]
        let keypad = Grid(4) {
            for (label in keys) {
                Button(label, {=> ()}).height(40.0)
            }
        }.spacing(12.0)
        // 运行时：八个按键按四列等宽排列，改变窗口宽度会重算单元格。
    }
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init(columns: Int64, body!: () -> Unit)`](#init) | 以列数与界面构建函数块创建网格。 |

**方法**

| 成员 | 说明 |
|---|---|
| [`spacing(...)`](#spacing) | 设置单元格之间的水平与垂直间隙。 |
| [`measure(ctx: UiContext, available: Size)`](#measure) | 测量结果宽为全部可用宽度、高为各行行高之和加行间隙，高度限制在可用空间。 |
| [`layout(ctx: UiContext, rect: Rect)`](#layout) | 把子组件按行主序放进等宽单元格：接受拉伸的轴撑满单元格，否则保持测量尺寸。 |
| [`draw(ctx: UiContext)`](#draw) | 按声明顺序绘制子组件。 |
| [`handle(ctx: UiContext, event: UiEvent)`](#handle) | 把事件派发给子组件并返回是否被消费。 |
| [`focusableIds()`](#focusableids) | 按声明顺序串联全部子组件注册的焦点项。 |

## 构造函数

### init

以列数与界面构建函数块创建网格。

```cangjie
public init(columns: Int64, body!: () -> Unit)
```

**参数**

- `columns`: `Int64` — 列数，须为正。
- `body!`: `() -> Unit` — 界面构建函数块；块内构造的组件按声明顺序行主序填入单元格。

**异常**

- `IllegalArgumentException` — `columns` 不为正时。

## 方法

### spacing

设置单元格之间的水平与垂直间隙。四个重载：等间隙的 `Length`/`Float32` 版本，与水平、垂直分设的版本；不带单位的 `Float32` 按虚拟像素解释。

```cangjie
public func spacing(value: Length): Grid
```

```cangjie
public func spacing(value: Float32): Grid
```

```cangjie
public func spacing(horizontal: Length, vertical: Length): Grid
```

```cangjie
public func spacing(horizontal: Float32, vertical: Float32): Grid
```

**参数**

- `value`: [`Length`](Length.md) / `Float32` — 水平与垂直同值的间隙，如 `12.vp`；默认各 8 虚拟像素，负值按 0 处理。
- `horizontal` / `vertical`: `Length` / `Float32` — 分设的水平与垂直间隙。

**返回值** `Grid` — 本网格自身，用于链式调用。

### measure

测量结果宽为全部可用宽度、高为各行行高之和加行间隙，高度限制在可用空间。行高按单元格宽度试测各行最高的子组件得出。

```cangjie
public func measure(ctx: UiContext, available: Size): Size
```

**参数**

- `ctx`: [`UiContext`](UiContext.md) — 当帧上下文，用于间隙换算。
- `available`: `Size` — 可用空间，逻辑像素。

**返回值** `Size` — 首选尺寸：宽度恒为 `available.w`，高度不超过 `available.h`。

### layout

把子组件按行主序放进等宽单元格：接受拉伸的轴撑满单元格，否则保持测量尺寸。超出单元格的部分被限制；不参与布局的子组件被跳过、不占格位。

```cangjie
public func layout(ctx: UiContext, rect: Rect): Unit
```

**参数**

- `ctx`: `UiContext` — 当帧上下文。
- `rect`: `Rect` — 分配给网格的框架，逻辑像素。

### draw

按声明顺序绘制子组件。

```cangjie
public func draw(ctx: UiContext): Unit
```

**参数**

- `ctx`: `UiContext` — 当帧上下文。

### handle

把事件派发给子组件并返回是否被消费。`Frame` 事件广播给全部子组件并返回 `false`；其余事件保持自后声明者向前、遇到消费者即停止的顺序。点事件会用布局提交的有序 AABB 树跳过不相交的 [`PointerEventScope.LayoutBounds`](PointerEventScope.md) 子树；无界兼容叶和活动捕获仍完整遍历。

```cangjie
public func handle(ctx: UiContext, event: UiEvent): Bool
```

**参数**

- `ctx`: `UiContext` — 当帧上下文。
- `event`: `UiEvent` — 待处理的输入事件。

**返回值** `Bool` — 某个子组件消费该事件时为 `true`。

### focusableIds

按声明顺序串联全部子组件注册的焦点项。

```cangjie
public func focusableIds(): Array<String>
```

**返回值** `Array<String>` — 网格内全部焦点项 id。

## 另请参阅

- [FlowRow](FlowRow.md) — 不固定列数、按内容宽度换行的流式容器。
- [VStack](VStack.md) / [HStack](HStack.md) — 单方向排列的栈容器。
- [LazyColumn](LazyColumn.md) — 大数据量下按行虚拟化的替代（含 `LazyGrid` 构建函数）。
