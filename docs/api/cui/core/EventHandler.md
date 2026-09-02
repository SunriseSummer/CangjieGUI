[cui](../../index.md) › [cui.core](index.md) › EventHandler

# EventHandler

位于 `cui.core` 包的公开类

在子树收到事件之前先把每个事件交给回调的透明包装组件，回调返回 `true` 即消费该事件。布局、绘制与弹性行为全部转发给子树，因此把它包在任意位置都不改变界面，只改变事件路由。

这是兼容且低仪式成本的 Bool API。需要区分捕获/冒泡，或把“已处理”与“停止传播”独立组合时，使用 [`EventListener`](EventListener.md) 与 [`EventOutcome`](EventOutcome.md)。

## 声明

```cangjie
public class EventHandler <: Widget
```

## 继承

EventHandler <: [`Widget`](Widget.md)

## 说明

典型用法是处理应用级按键：把整个界面包进 `EventHandler`，在回调里处理回车、Escape、Delete 或 Ctrl/Cmd/Shift 组合键；回调不处理的事件继续交给子控件。`KeyDown` 的第二个载荷是 repeat `Bool`，不是修饰键。

无需事件上下文时可使用单参数 `(UiEvent) -> Bool` 回调；组合键使用上下文感知的 `(UiContext, UiEvent) -> Bool` 重载，并从 [`UiContext.eventModifiers()`](UiContext.md#eventmetadata-eventmodifiers) 读取与当前事件一起采集的稳定快照。不要在延迟派发阶段查询全局 `Keyboard.modifiers()`，因为 SDL 队列可能已继续处理 KeyUp。构建时 `EventHandler` 会显式登记自己的 Frame 观察，子控件的帧订阅独立登记，回调不能拦截帧脉搏；需要每帧更新状态并自动续帧时改用 [`FrameHandler`](FrameHandler.md)。

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let app = DesktopApp(WindowSpec("EventHandler", 640, 420))
    app.run {
        let status = rememberState<String>("shortcut.status") {"等待按键"}
        EventHandler(onEvent: {
            ctx, event => match (event) {
                case UiEvent.KeyDown(Key.Letter(code), _) =>
                    if (code == UInt8(83) && ctx.eventModifiers().command) {
                        status.value = "已处理 Ctrl/Cmd+S"
                        true
                    } else {
                        false
                    }
                case _ => false
            }
        }) {
            VStack {
                Label("按 Ctrl/Cmd+S 触发应用快捷键")
                Label(status.value)
                // 运行时：命中后第二行更新；普通 S 与其它按键继续交给子控件。
            }
        }
    }
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init(onEvent!: (UiEvent) -> Bool, body!: () -> Unit)`](#init) | 以事件回调与界面构建函数块创建包装。 |
| [`init(onEvent!: (UiContext, UiEvent) -> Bool, body!: () -> Unit)`](#init) | 创建可读取事件时元数据的包装。 |

**方法**

| 成员 | 说明 |
|---|---|
| [`measure(ctx: UiContext, available: Size)`](#measure) | 把可用空间原样转给子树并返回其测量尺寸。 |
| [`layout(ctx: UiContext, rect: Rect)`](#layout) | 把分配到的区域原样交给子树布局。 |
| [`draw(ctx: UiContext)`](#draw) | 绘制子树。 |
| [`handle(ctx: UiContext, event: UiEvent)`](#handle) | 先把事件交给回调，回调未消费时再下发给子树。 |
| [`isFlexible()`](#isflexible) | 转发子树的弹性参与声明。 |
| [`flexWeight()`](#flexweight) | 转发子树声明的弹性权重。 |
| [`acceptsStretch(axis: Axis)`](#acceptsstretch) | 转发子树是否允许在给定轴上被拉伸。 |
| [`participatesInLayout()`](#participatesinlayout) | 转发子树是否占据父布局中的位置。 |
| [`focusableId()`](#focusableid) | 转发子树的单一焦点项 id。 |
| [`focusableIds()`](#focusableids) | 转发子树注册的全部焦点项。 |

## 构造函数

### init

以事件回调与界面构建函数块创建包装。

```cangjie
public init(onEvent!: (UiEvent) -> Bool, body!: () -> Unit)
public init(onEvent!: (UiContext, UiEvent) -> Bool, body!: () -> Unit)
```

**参数**

- `onEvent!`: `(UiEvent) -> Bool` — 兼容的简洁回调，适合不需要事件上下文的判断。
- `onEvent!`: `(UiContext, UiEvent) -> Bool` — 上下文感知回调；通过 `ctx.eventModifiers()` 读取当前事件的修饰键快照。两种回调均先于子树收到事件，返回 `true` 即消费；`Frame` 事件的返回值被忽略。
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

把分配到的区域原样交给子树布局。

```cangjie
public func layout(ctx: UiContext, rect: Rect): Unit
```

**参数**

- `ctx`: `UiContext` — 当帧上下文。
- `rect`: `Rect` — 分配给本包装组件的区域，单位为逻辑像素。

### draw

绘制子树。

```cangjie
public func draw(ctx: UiContext): Unit
```

**参数**

- `ctx`: `UiContext` — 当帧上下文。

### handle

先把事件交给回调，回调未消费时再下发给子树。`Frame` 事件例外：回调与子树都会收到，且本方法总是返回 `false`，帧脉搏因此无法被拦截。

```cangjie
public func handle(ctx: UiContext, event: UiEvent): Bool
```

**参数**

- `ctx`: `UiContext` — 当帧上下文。
- `event`: `UiEvent` — 待处理的输入事件。

**返回值** `Bool` — 事件被回调或子树消费时为 `true`。

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

- [FrameHandler](FrameHandler.md) — 按帧回调的姊妹包装，用于动画与帧内轮询。
- [EventListener](EventListener.md) — 分相、可组合的新事件传播 API。
- [Widget](Widget.md) — 事件派发与消费语义的协议定义。
- [UiContext](UiContext.md#eventmetadata-eventmodifiers) — 回调或自定义组件读取事件时刻修饰键与原始键元数据。
