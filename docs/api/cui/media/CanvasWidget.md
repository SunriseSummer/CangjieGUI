[cui](../../index.md) › [cui.media](index.md) › CanvasWidget

# CanvasWidget

`cui.media` 包中的 public class

自由绘制表面：弹性填满分得的空间、画主题输入底色、裁剪到框，然后把原始 `Renderer` 与框矩形交给 `onDraw`——坐标是绝对的，绘制方从矩形偏移、不从零点起。输入事件连同同一矩形转给 `onEvent`，返回 `true` 即消费。

## 声明

```cangjie
public class CanvasWidget <: Widget
```

## 继承

- 实现 [`Widget`](../core/Widget.md)。

## 说明

普通路径中的 CanvasWidget 值会随构建更新，`RetainedSubtree` 又可能复用它；无论哪条路径，需要驱动可见结果和失效的绘图事实都应放 [`State`](../core/State.md) 或显式 revision，不要依赖实例字段的偶然寿命。适合图表、示波器、自绘小游戏等一切直接用渲染器 API 的场景。

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let app = DesktopApp(WindowSpec("CanvasWidget", 640, 420))
    app.run {
        CanvasWidget({
            renderer, frame => renderer.strokeLine(frame.x + 10.0, frame.y + 10.0, frame.right() - 10.0,
                frame.bottom() - 10.0, Pen(width: 2.0, color: Color.rgb(33, 114, 229)))
        })
        // 运行时：画布随窗口尺寸铺满可用空间，并始终从左上到右下绘制对角线。
    }
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init(...)`](#init) | 以绘制回调与可选事件回调创建画布。 |

**方法**

| 成员 | 说明 |
|---|---|
| [`onEvent(...)`](#onevent) | 设置事件回调，收到事件与当前画布矩形。 |
| [`measure(...)`](#measure) | 填满父容器提供的全部空间。 |
| [`layout(...)`](#layout) | 记住分配的矩形。 |
| [`draw(...)`](#draw) | 画底色、裁剪后调用 `onDraw`。 |
| [`handle(...)`](#handle) | 把事件与矩形转给事件回调。 |
| [`isFlexible()`](#isflexible) | 恒为 `true`——画布天然填满剩余空间。 |

## 构造函数

### init

以绘制回调与可选事件回调创建画布。

```cangjie
public init(onDraw: (Renderer, Rect) -> Unit, onEvent!: (UiEvent, Rect) -> Bool = {_, _ => false})
```

**参数**

- `onDraw`: `(Renderer, Rect) -> Unit` — 每帧收到渲染器与画布矩形（绝对坐标）。
- `onEvent!`: `(UiEvent, Rect) -> Bool` — 事件回调；返回 `true` 表示消费。默认值为 `{_, _ => false}`，即不消费任何事件。

## 方法

### onEvent

设置事件回调，收到事件与当前画布矩形。

```cangjie
public func onEvent(value: (UiEvent, Rect) -> Bool): CanvasWidget
```

**参数**

- `value`: `(UiEvent, Rect) -> Bool` — 新事件回调。

**返回值** [`CanvasWidget`](CanvasWidget.md) — 自身，供链式调用。

### measure

填满父容器提供的全部空间。

```cangjie
public func measure(_: UiContext, available: Size): Size
```

**参数**

- `available`: `Size` — 父级给出的可用尺寸约束。

**返回值** `Size` — 恒为 `available`。

### layout

记住分配的矩形。

```cangjie
public func layout(_: UiContext, rect: Rect): Unit
```

**参数**

- `rect`: `Rect` — 父级最终分配给组件的矩形。

### draw

画底色、裁剪后调用 `onDraw`。裁剪内缩 1 像素保住边框。

```cangjie
public func draw(ctx: UiContext): Unit
```

**参数**

- `ctx`: [`UiContext`](../core/UiContext.md) — 本轮绘制使用的 UI 上下文。

### handle

把事件与矩形转给事件回调。

```cangjie
public func handle(_: UiContext, event: UiEvent): Bool
```

**参数**

- `event`: `UiEvent` — 本轮待处理的 UI 事件。

**返回值** `Bool` — 事件回调的返回值。

### isFlexible

恒为 `true`——画布天然填满剩余空间。

```cangjie
public func isFlexible(): Bool
```

**返回值** `Bool` — 恒为 `true`。

## 另请参阅

- [`ImageView`](ImageView.md) — 文件图像展示。
- `Renderer`（sdl 模块） — 回调收到的二维绘制入口。
