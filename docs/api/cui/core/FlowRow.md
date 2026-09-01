[cui](../../index.md) › [cui.core](index.md) › FlowRow

# FlowRow

`cui.core` 包中的 public class

把子组件从左到右排布、放不下时自动换到内容高度新行的流式容器。子组件保持各自的测量尺寸、从不被拉伸，是标签墙、单选组、状态胶囊行的自然写法。

## 声明

```cangjie
public class FlowRow <: Widget
```

## 继承

FlowRow <: [`Widget`](Widget.md)

## 说明

换行规则：当子组件放不进当前行的剩余宽度时移到下一行行首；行首的子组件从不换行，比可用宽度更宽的子组件因此独占一行并溢出。每行行高取本行最高的子组件，行与行之间加垂直间隙。与固定列数的 [`Grid`](Grid.md) 不同，流式行的每行个数随宽度与子组件宽度自然变化。

不参与布局的子组件（`.visible(false)`）在排布与绘制中都被跳过，不留空位。

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let app = DesktopApp(WindowSpec("FlowRow", 640, 420))
    app.run {
        let tags = ["设计", "评审", "阻塞", "紧急", "文档"]
        let tagWall = FlowRow {
            for (name in tags) {
                Label(name).width(90.0).height(24.0)
            }
        }
        // 运行时：缩放窗口可观察标签在可用宽度不足时自动换行。
    }
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init(body!: () -> Unit)`](#init) | 以界面构建函数块创建流式行容器。 |

**方法**

| 成员 | 说明 |
|---|---|
| [`spacing(...)`](#spacing) | 设置子组件之间的水平与垂直间隙。 |
| [`measure(ctx: UiContext, available: Size)`](#measure) | 按换行规则试排子组件，报告实际使用的宽度与总行高，限制在可用空间。 |
| [`layout(ctx: UiContext, rect: Rect)`](#layout) | 从左到右放置子组件，放不下时换到下一行行首；每行行高取本行最高的子组件。 |
| [`draw(ctx: UiContext)`](#draw) | 按声明顺序绘制参与布局的子组件。 |
| [`handle(ctx: UiContext, event: UiEvent)`](#handle) | 把事件派发给子组件并返回是否被消费。 |
| [`focusableIds()`](#focusableids) | 按声明顺序串联全部子组件注册的焦点项。 |

## 构造函数

### init

以界面构建函数块创建流式行容器。

```cangjie
public init(body!: () -> Unit)
```

**参数**

- `body!`: `() -> Unit` — 界面构建函数块；块内构造的组件按声明顺序从左到右排布。

## 方法

### spacing

设置子组件之间的水平与垂直间隙。四个重载：等间隙的 `Length`/`Float32` 版本，与水平、垂直分设的版本；不带单位的 `Float32` 按虚拟像素解释。

```cangjie
public func spacing(value: Length): FlowRow
```

```cangjie
public func spacing(value: Float32): FlowRow
```

```cangjie
public func spacing(horizontal: Length, vertical: Length): FlowRow
```

```cangjie
public func spacing(horizontal: Float32, vertical: Float32): FlowRow
```

**参数**

- `value`: [`Length`](Length.md) / `Float32` — 水平与垂直同值的间隙，如 `10.vp`；默认各 8 虚拟像素，负值按 0 处理。
- `horizontal` / `vertical`: `Length` / `Float32` — 分设的同行间隙与行间隙。

**返回值** `FlowRow` — 本容器自身，用于链式调用。

### measure

按换行规则试排子组件，报告实际使用的宽度与总行高，限制在可用空间。

```cangjie
public func measure(ctx: UiContext, available: Size): Size
```

**参数**

- `ctx`: [`UiContext`](UiContext.md) — 当帧上下文，用于间隙换算。
- `available`: `Size` — 可用空间，逻辑像素；宽度决定换行位置。

**返回值** `Size` — 首选尺寸，不超过 `available`。

### layout

从左到右放置子组件，放不下时换到下一行行首；每行行高取本行最高的子组件。子组件保持测量尺寸，从不被拉伸。

```cangjie
public func layout(ctx: UiContext, rect: Rect): Unit
```

**参数**

- `ctx`: `UiContext` — 当帧上下文。
- `rect`: `Rect` — 分配给容器的框架，逻辑像素。

### draw

按声明顺序绘制参与布局的子组件。

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

**返回值** `Array<String>` — 容器内全部焦点项 id。

## 另请参阅

- [Grid](Grid.md) — 固定列数、等宽单元格的网格容器。
- [HStack](HStack.md) — 不换行的单行水平栈。
- [Chip](../controls/Chip.md) — 常放进流式行的过滤标签控件。
