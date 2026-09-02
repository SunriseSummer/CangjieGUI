[cui](../../index.md) › [cui.core](index.md) › FrameHandler

# FrameHandler

位于 `cui.core` 包的公开类

每渲染帧调用一次回调并自动请求续帧的透明包装组件，是时间驱动动画与帧内轮询的挂载点。布局、绘制与弹性行为全部转发给子树，包上它不改变界面。

## 声明

```cangjie
public class FrameHandler <: Widget
```

## 继承

FrameHandler <: [`Widget`](Widget.md)

## 说明

挂载即向当前构建的显式 Frame 订阅表登记一份逐帧契约；retained 边界命中会重放该登记，不需要遍历全部静态组件。回调调用 [`UiContext`](UiContext.md) 的 [`requestFrame`](UiContext.md#requestframe)，桌面循环因此持续渲染、回调持续触发，不会被空闲跳帧冻住。这给出"按需帧"模式——只在需要时挂载：番茄钟只在计时运行态包上 `FrameHandler`，暂停即卸下，应用回到零帧空闲；异步文件对话框的结果也可在回调里逐帧轮询取回。

只需拦截输入事件而不需要帧脉搏时，用 [`EventHandler`](EventHandler.md)。

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let app = DesktopApp(WindowSpec("FrameHandler", 640, 420))
    app.run {
        let elapsed = rememberState<Int64>("elapsed") {0}
        FrameHandler(onFrame: {info => elapsed.value = elapsed.value + Int64(info.deltaMs)}) {
            VStack(spacing: 12.vp) {
                Label("已运行 ${elapsed.value} ms")
                Button("归零", {=> elapsed.value = 0})
            }.padding(24.0)
        }
        // 运行时：窗口帧循环持续更新计时文本，回调主动请求后续帧。
    }
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init(onFrame!: (FrameInfo) -> Unit, body!: () -> Unit)`](#init) | 以帧回调与界面构建函数块创建包装。 |

**方法**

| 成员 | 说明 |
|---|---|
| [`measure(ctx: UiContext, available: Size)`](#measure) | 把可用空间原样转给子树并返回其测量尺寸。 |
| [`layout(ctx: UiContext, rect: Rect)`](#layout) | 把框架原样转给子树布局。 |
| [`draw(ctx: UiContext)`](#draw) | 绘制子树。 |
| [`handle(ctx: UiContext, event: UiEvent)`](#handle) | 直接调用兼容：收到 `Frame` 时执行本回调并转发子树；宿主正常走显式订阅表。 |
| [`isFlexible()`](#isflexible) | 转发子树的弹性参与声明。 |
| [`flexWeight()`](#flexweight) | 转发子树声明的弹性权重。 |
| [`acceptsStretch(axis: Axis)`](#acceptsstretch) | 转发子树是否允许在给定轴上被拉伸。 |
| [`participatesInLayout()`](#participatesinlayout) | 转发子树是否占据父布局中的位置。 |
| [`focusableId()`](#focusableid) | 转发子树的单一焦点项 id。 |
| [`focusableIds()`](#focusableids) | 转发子树注册的全部焦点项。 |

## 构造函数

### init

以帧回调与界面构建函数块创建包装。

```cangjie
public init(onFrame!: (FrameInfo) -> Unit, body!: () -> Unit)
```

**参数**

- `onFrame!`: `(FrameInfo) -> Unit` — 每渲染帧调用一次，收到本帧的时间信息（总流逝毫秒与帧间隔毫秒）。
- `body!`: `() -> Unit` — 界面构建函数块；块内声明多个组件时自动竖排为一个子树。

## 方法

### measure

把可用空间原样转给子树并返回其测量尺寸。

```cangjie
public func measure(ctx: UiContext, available: Size): Size
```

**参数**

- `ctx`: [`UiContext`](UiContext.md) — 当帧上下文。
- `available`: `Size` — 可用空间，逻辑像素。

**返回值** `Size` — 子树的测量尺寸。

### layout

把框架原样转给子树布局。

```cangjie
public func layout(ctx: UiContext, rect: Rect): Unit
```

**参数**

- `ctx`: `UiContext` — 当帧上下文。
- `rect`: `Rect` — 分配给本包装的框架，逻辑像素。

### draw

绘制子树。

```cangjie
public func draw(ctx: UiContext): Unit
```

**参数**

- `ctx`: `UiContext` — 当帧上下文。

### handle

直接调用 `handle(Frame)` 时请求续帧、调用回调并转发给子树，其余事件原样转发。桌面与测试宿主正常通过构建期订阅表直接调用本回调，子树中的订阅者各自登记；保留这个分支便于单组件测试与兼容手动派发。

```cangjie
public func handle(ctx: UiContext, event: UiEvent): Bool
```

**参数**

- `ctx`: `UiContext` — 当帧上下文；`Frame` 分支经它调用 `requestFrame()` 保持循环渲染。
- `event`: `UiEvent` — 待处理的输入事件。

**返回值** `Bool` — `Frame` 事件恒为 `false`；其余事件返回子树是否消费。

### isFlexible

转发子树的弹性参与声明。

```cangjie
public func isFlexible(): Bool
```

**返回值** `Bool` — 子树是否参与所在栈的弹性分配。

### flexWeight

转发子树声明的弹性权重。

```cangjie
public func flexWeight(): Float32
```

**返回值** `Float32` — 子树的权重份额。

### acceptsStretch

转发子树是否允许在给定轴上被拉伸。

```cangjie
public func acceptsStretch(axis: Axis): Bool
```

**参数**

- `axis`: [`Axis`](Axis.md) — 询问的轴向。

**返回值** `Bool` — 子树允许被拉伸时为 `true`。

### participatesInLayout

转发子树是否占据父布局中的位置。

```cangjie
public func participatesInLayout(): Bool
```

**返回值** `Bool` — 子树参与布局时为 `true`。

### focusableId

转发子树的单一焦点项 id。

```cangjie
public func focusableId(): ?String
```

**返回值** `?String` — 子树的焦点项 id，子树不可聚焦时为 `None`。

### focusableIds

转发子树注册的全部焦点项。

```cangjie
public func focusableIds(): Array<String>
```

**返回值** `Array<String>` — 子树内全部焦点项 id，按声明顺序。

## 另请参阅

- [EventHandler](EventHandler.md) — 拦截输入事件的姊妹包装。
- [Spring](Spring.md)、[Animator](Animator.md)、[Pulse](Pulse.md) — 常与帧回调配合的基础动画类型。
- [UiContext](UiContext.md) — `requestFrame` 的续帧语义。
