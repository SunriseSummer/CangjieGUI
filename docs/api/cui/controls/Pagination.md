[cui](../../index.md) › [cui.controls](index.md) › Pagination

# Pagination

位于 `cui.controls` 包的公开类

长分页内容（搜索结果、表格、商品目录）的页码导航条：上一页/下一页箭头夹着一段窗口化页码——恒含首末页与当前页两侧的邻页，其间空缺折叠为省略号。点击页码直接跳页，箭头步进一页并在两端禁用；`current` 绑定零基页号、界面按一基显示。

## 声明

```cangjie
public class Pagination <: Widget
```

## 继承

`Pagination <: Widget` — 实现 [`Widget`](../core/Widget.md) 组件协议。

## 说明

页码窗口在构造时按 `current` 当前值计算：恒含第 0 页与最后一页，加上 `current ± window` 的连续段，两处空缺各折叠为一枚省略号（如 20 页在第 11 页、`window` 为 1 时显示 1 … 10 11 12 … 20）。在每帧重建的声明式树中，窗口随当前页自动重新取中。

`pageCount` 小于 1 时按 1 计；越界的 `current` 只在显示与命中时按就近端截断，控件不会主动改写绑定值（仅点击时写入新页号）。省略号单元与端点处禁用的箭头不可点击，悬停时保持默认指针；可点目标之上申请交互指针。

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let app = DesktopApp(WindowSpec("Pagination", 640, 420))
    app.run {
        let page = rememberState<Int64>("page") {9}
        let pager = Pagination(20, page, window: 1)
        // 运行时：点击页码或两端箭头切页，当前页始终保存在给定范围内。
    }
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init(...)`](#init) | 以总页数、当前页绑定与窗口宽度构造页码导航条。 |

**方法**

| 成员 | 说明 |
|---|---|
| [`measure(_: UiContext, _: Size)`](#measure) | 返回由单元格数决定的固定尺寸：页码窗口加两个箭头，每格 34、间距 4 逻辑像素，忽略可用空间。 |
| [`layout(_: UiContext, rect: Rect)`](#layout) | 从左到右排布上一页箭头、页码单元格与下一页箭头。 |
| [`draw(ctx: UiContext)`](#draw) | 绘制箭头（端点处变淡禁用）、页码（当前页强调色、一基显示）与省略号。 |
| [`handle(ctx: UiContext, event: UiEvent)`](#handle) | 点击页码跳到该页、箭头步进一页并在端点处忽略；悬停可点目标时申请交互指针。 |

## 构造函数

### init

以总页数、当前页绑定与窗口宽度构造页码导航条。

```cangjie
public init(pageCount: Int64, current: Bindable<Int64>, window!: Int64 = 1, key!: ?String = None)
```

**参数**

- `pageCount`: `Int64` — 总页数；小于 1 时按 1 计。
- `current`: [`Bindable`](../core/Bindable.md)`<Int64>` — 零基当前页的双向绑定，界面按一基显示；越界值仅在显示与命中时截断，绑定本身不被改写。
- `window!`: `Int64` — 当前页两侧各保留的邻页数；默认 `1`，负值按 `0` 计（窗口只剩当前页自身）。
- `key!`: `?String` — 悬停指针标识；默认 `None`，按构建顺序自动派生。

**异常**

- `IllegalArgumentException` — `key` 传入空字符串时。

## 方法

### measure

返回由单元格数决定的固定尺寸：页码窗口加两个箭头，每格 34、间距 4 逻辑像素，忽略可用空间。[`Widget`](../core/Widget.md) 协议方法。

```cangjie
public func measure(_: UiContext, _: Size): Size
```

**返回值** `Size` — 组件请求的尺寸；方法接收 `available` 时，该尺寸在父级给出的可用约束内计算。

### layout

从左到右排布上一页箭头、页码单元格与下一页箭头。[`Widget`](../core/Widget.md) 协议方法。

```cangjie
public func layout(_: UiContext, rect: Rect): Unit
```

**参数**

- `rect`: `Rect` — 父级最终分配给组件的矩形。

### draw

绘制箭头（端点处变淡禁用）、页码（当前页强调色、一基显示）与省略号。悬停的可点单元填活跃底色。[`Widget`](../core/Widget.md) 协议方法。

```cangjie
public func draw(ctx: UiContext): Unit
```

**参数**

- `ctx`: [`UiContext`](../core/UiContext.md) — 本轮绘制使用的 UI 上下文。

### handle

点击页码跳到该页、箭头步进一页并在端点处忽略；悬停可点目标时申请交互指针。省略号单元不响应点击。[`Widget`](../core/Widget.md) 协议方法。

```cangjie
public func handle(ctx: UiContext, event: UiEvent): Bool
```

**参数**

- `ctx`: [`UiContext`](../core/UiContext.md) — 本轮事件处理使用的 UI 上下文。
- `event`: `UiEvent` — 本轮待处理的 UI 事件。

**返回值** `Bool` — 是否已消费该事件；`true` 表示调用方不应再继续分发。

## 另请参阅

- [Table](Table.md) — 常与分页搭配呈现大行集的表格控件。
- [StepIndicator](StepIndicator.md) — 分步流程的进度导航，与分页互补。
