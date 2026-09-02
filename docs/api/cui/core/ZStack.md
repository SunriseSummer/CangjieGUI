[cui](../../index.md) › [cui.core](index.md) › ZStack

# ZStack

位于 `cui.core` 包的公开类

把子组件按声明顺序自底向顶叠放、并在同一框架内对齐的层叠容器。后声明的子组件画在上层、事件也先送达，是模态对话框、Toast 通知层浮于主内容之上的标准写法。

## 声明

```cangjie
public class ZStack <: Widget
```

## 继承

ZStack <: [`Widget`](Widget.md)

## 说明

每个参与布局的子组件都拿到同一块框架：接受拉伸的轴填满框架，其余轴保持测量尺寸并按 [`alignment`](#alignment) 放置（默认居中）。不参与布局的子组件（`.visible(false)`）在测量与布局中被跳过，隐藏的层不影响叠层尺寸。

典型结构是"主内容在下、浮动层在上"：删除确认 [`Modal`](../controls/Modal.md) 或 [`ToastLayer`](../controls/ToastLayer.md) 放在块尾，不占布局空间、自行定位，隐藏时对下方内容零影响。

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let app = DesktopApp(WindowSpec("ZStack", 640, 420))
    app.run {
        let card = ZStack {
            Label("正文内容").width(300.0).height(200.0)
            Label("新").width(48.0).height(24.0)
        }.alignment(Alignment.TopTrailing)
        // 运行时：正文卡片与“新”角标共享框架，角标叠在右上方。
    }
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init(body!: () -> Unit)`](#init) | 以界面构建函数块创建层叠容器，子组件按声明顺序自底向顶叠放。 |

**方法**

| 成员 | 说明 |
|---|---|
| [`alignment(value: Alignment)`](#alignment) | 设置不拉伸的子组件在叠层框架内的对齐位置。 |
| [`measure(ctx: UiContext, available: Size)`](#measure) | 测量为全部参与子组件的最大宽与最大高，限制在可用空间。 |
| [`layout(ctx: UiContext, rect: Rect)`](#layout) | 让每个参与子组件在同一框架内布局：接受拉伸的轴填满框架，其余轴保持测量尺寸并按对齐放置。 |
| [`draw(ctx: UiContext)`](#draw) | 按声明顺序绘制子组件：先声明者在底、后声明者在顶。 |
| [`handle(ctx: UiContext, event: UiEvent)`](#handle) | 把事件自顶向下派发给子组件并返回是否被消费。 |
| [`focusableIds()`](#focusableids) | 按声明顺序串联全部子组件注册的焦点项。 |

## 构造函数

### init

以界面构建函数块创建层叠容器，子组件按声明顺序自底向顶叠放。

```cangjie
public init(body!: () -> Unit)
```

**参数**

- `body!`: `() -> Unit` — 界面构建函数块；块内构造的组件按声明顺序成为叠层，靠后声明者在上。

## 方法

### alignment

设置不拉伸的子组件在叠层框架内的对齐位置。

```cangjie
public func alignment(value: Alignment): ZStack
```

**参数**

- `value`: [`Alignment`](Alignment.md) — 九宫格对齐位置；默认 `Center`。

**返回值** `ZStack` — 本容器自身，用于链式调用。

### measure

测量为全部参与子组件的最大宽与最大高，限制在可用空间。

```cangjie
public func measure(ctx: UiContext, available: Size): Size
```

**参数**

- `ctx`: [`UiContext`](UiContext.md) — 当帧上下文。
- `available`: `Size` — 可用空间，逻辑像素。

**返回值** `Size` — 叠层的首选尺寸，不超过 `available`。

### layout

让每个参与子组件在同一框架内布局：接受拉伸的轴填满框架，其余轴保持测量尺寸并按对齐放置。

```cangjie
public func layout(ctx: UiContext, rect: Rect): Unit
```

**参数**

- `ctx`: `UiContext` — 当帧上下文。
- `rect`: `Rect` — 分配给叠层的框架，逻辑像素。

### draw

按声明顺序绘制子组件：先声明者在底、后声明者在顶。

```cangjie
public func draw(ctx: UiContext): Unit
```

**参数**

- `ctx`: `UiContext` — 当帧上下文。

### handle

把事件从视觉最上层开始交给子组件，遇到返回 `true` 的组件后停止。显式传入的 `Frame` 事件会广播给全部子组件并返回 `false`；桌面应用的正常帧回调使用独立订阅。对于声明了 [`PointerEventScope.LayoutBounds`](PointerEventScope.md) 的子树，指针事件可以跳过明显不相交的区域；重叠区域和活动手势仍按完整层级路由。

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

**返回值** `Array<String>` — 叠层内全部焦点项 id。

## 另请参阅

- [Modal](../controls/Modal.md) — 常放在叠层顶层的模态对话框。
- [ToastLayer](../controls/ToastLayer.md) — 不占布局空间、浮于内容之上的通知层。
- [VStack](VStack.md) / [HStack](HStack.md) — 排列而非层叠的栈容器。
- [Alignment](Alignment.md) — 九宫格二维对齐枚举。
