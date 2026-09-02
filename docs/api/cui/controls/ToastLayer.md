[cui](../../index.md) › [cui.controls](index.md) › ToastLayer

# ToastLayer

位于 `cui.controls` 包的公开类

把一个 [`Toaster`](Toaster.md) 的通知渲染到视口右下角并驱动其时钟的浮层组件。在组件树根部附近放一次（例如根 [`ZStack`](../core/ZStack.md) 的最后一层）使其画在内容之上；它不占布局空间、从不消费事件，不打扰其下的应用。

## 声明

```cangjie
public class ToastLayer <: Widget
```

## 继承

- [`Widget`](../core/Widget.md)

## 说明

通知卡片宽 320 逻辑像素（视口过窄时收窄）、高 46，距视口右下各 16，自底向上按弹出顺序堆叠——最新的一条在最下。入场在前 150 毫秒内自下滑入并淡入，剩余寿命不足 300 毫秒时淡出，透明度取两者较小值。

时钟是时间驱动动画：每帧处理 `Frame` 事件时按 `FrameInfo.deltaMs` 老化每条通知并丢弃到期者，且只要还有通知就调用 [`UiContext.requestFrame`](../core/UiContext.md#requestframe) 索要下一帧——否则空闲屏幕上桌面循环的脏帧跳过会把动画冻住。

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let toaster = Toaster()
    let app = DesktopApp(WindowSpec("ToastLayer", 520, 300))
    app.run {
        Button("下载完成", {
            => toaster.show("下载完成", kind: ToastKind.Success, durationMs: 2400)
        }).padding(24.0)
        ToastLayer(toaster)
        // 运行时：点击按钮向 Toaster 加入通知，ToastLayer 在右下角渲染并计时。
    }
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init(toaster: Toaster)`](#init) | 构造渲染给定调度器通知的浮层。 |

**方法**

| 成员 | 说明 |
|---|---|
| [`measure(_: UiContext, _: Size)`](#measure) | 报告零尺寸（[`Widget`](../core/Widget.md) 协议）。 |
| [`layout(_: UiContext, _: Rect)`](#layout) | 无操作：通知直接按视口定位（[`Widget`](../core/Widget.md) 协议）。 |
| [`participatesInLayout()`](#participatesinlayout) | 恒为 `false`：不在父布局中占据位置（[`Widget`](../core/Widget.md) 协议）。 |
| [`draw(ctx: UiContext)`](#draw) | 按滑入/淡出进度，把当前通知画在视口右下角（[`Widget`](../core/Widget.md) 协议）。 |
| [`handle(ctx: UiContext, event: UiEvent)`](#handle) | 帧事件老化通知并在有通知时索要下一帧，恒不消费（[`Widget`](../core/Widget.md) 协议）。 |

## 构造函数

### init

构造渲染给定调度器通知的浮层。

```cangjie
public init(toaster: Toaster)
```

**参数**

- `toaster`: [`Toaster`](Toaster.md) — 被渲染与老化的通知调度器；层不持有通知，仅每帧读取其快照。

## 方法

### measure

报告零尺寸（[`Widget`](../core/Widget.md) 协议）。

```cangjie
public func measure(_: UiContext, _: Size): Size
```

**返回值** `Size` — 恒为零尺寸。

### layout

无操作：通知直接按视口定位（[`Widget`](../core/Widget.md) 协议）。

```cangjie
public func layout(_: UiContext, _: Rect): Unit
```

### participatesInLayout

恒为 `false`：不在父布局中占据位置（[`Widget`](../core/Widget.md) 协议）。放进任何容器都不影响兄弟组件的排布。

```cangjie
public func participatesInLayout(): Bool
```

**返回值** `Bool` — 恒为 `false`。

### draw

按滑入/淡出进度，把当前通知画在视口右下角（[`Widget`](../core/Widget.md) 协议）。每张卡片包含阴影、圆角背景、按 [`ToastKind`](ToastKind.md) 取色的强调条和单行消息，整体随当前透明度淡化；无通知时不绘制。

```cangjie
public func draw(ctx: UiContext): Unit
```

**参数**

- `ctx`: [`UiContext`](../core/UiContext.md) — 帧服务上下文，读取 `viewportWidth`/`viewportHeight` 定位。

### handle

帧事件老化通知并在有通知时索要下一帧，恒不消费（[`Widget`](../core/Widget.md) 协议）。`Frame` 事件按 `deltaMs` 推进每条通知的年龄与剩余寿命并丢弃到期者；其余事件一律忽略，指针事件照常落到其下的内容。

```cangjie
public func handle(ctx: UiContext, event: UiEvent): Bool
```

**参数**

- `ctx`: `UiContext` — 帧服务上下文。
- `event`: `UiEvent` — 本帧派发的输入事件。

**返回值** `Bool` — 恒为 `false`。

## 另请参阅

- [Toaster](Toaster.md) — 通知的入队与存量查询。
- [ToastKind](ToastKind.md) — 通知类别枚举。
- [ZStack](../core/ZStack.md) — 承载浮层的层叠容器。
