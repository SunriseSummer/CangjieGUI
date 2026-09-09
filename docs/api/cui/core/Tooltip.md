[cui](../../index.md) › [cui.core](index.md) › Tooltip

# Tooltip

位于 `cui.core` 包的公开类

为任意控件包上悬停提示：指针在子组件上驻留 500 毫秒后，提示文本被绘制在整棵组件树之上；其余时刻是完全透明的包装。测量、布局、绘制与事件全部原样转发给子组件，弹性与焦点行为也一并转发。

## 声明

```cangjie
public class Tooltip <: Widget
```

## 继承

Tooltip <: [`Widget`](Widget.md)

## 说明

提示气泡由宿主经 [`UiContext`](UiContext.md) 的单槽浮层绘制：优先出现在被包装控件正下方，贴近窗口底部时翻转到上方，水平方向限制在窗口内；配色为主题反色（亮色主题出深色气泡）。驻留倒计时期间组件会请求下一帧，保证桌面循环的脏帧跳过不会冻结计时；指针离开即重置计时。驻留起点存放在按标识键控的局部状态里，跨构建存活。

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let app = DesktopApp(WindowSpec("Tooltip", 640, 420))
    app.run {
        Tooltip(text: "把当前文档写入磁盘") {
            Button("保存", {=> ()})
        }.padding(24.0)
        // 运行时：把指针停在“保存”按钮上，驻留后显示不会占布局空间的提示。
    }
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init(text!: String, body!: () -> Unit)`](#init) | 用提示文本包装一个子组件。 |

**方法**

| 成员 | 说明 |
|---|---|
| [`measure(...)`](#measure) | 原样转发子组件的测量结果。 |
| [`layout(...)`](#layout) | 记录自身帧，并把同一矩形转发给子组件布局。 |
| [`draw(...)`](#draw) | 先绘制子组件；指针驻留满 500 毫秒后向宿主注册提示文本，未满时请求下一帧继续计时。 |
| [`handle(...)`](#handle) | 原样转发给子组件。 |
| [`isFlexible()`](#isflexible) | 转发子组件的弹性标志。 |
| [`flexWeight()`](#flexweight) | 转发子组件的弹性权重。 |
| [`acceptsStretch(axis: Axis)`](#acceptsstretch) | 转发子组件在该轴上是否接受拉伸。 |
| [`participatesInLayout()`](#participatesinlayout) | 转发子组件是否参与父布局。 |
| [`focusableId()`](#focusableid) | 转发子组件的焦点标识。 |
| [`focusableIds()`](#focusableids) | 转发子组件子树的全部焦点项。 |

## 构造函数

### init

用提示文本包装一个子组件。构造时自动注册进包围它的界面构建函数。

```cangjie
public init(text!: String, body!: () -> Unit)
```

**参数**

- `text!`: `String` — 悬停后显示的提示文本，单行绘制。
- `body!`: `() -> Unit` — 界面构建函数，产出被包装的子组件；声明多个组件时自动包进一个垂直栈，空构建器得到空占位。

## 方法

### measure

原样转发子组件的测量结果。

```cangjie
public func measure(ctx: UiContext, available: Size): Size
```

**参数**

- `ctx`: [`UiContext`](UiContext.md) — 本轮测量使用的 UI 上下文。
- `available`: `Size` — 父级给出的可用尺寸约束。

**返回值** `Size` — 子组件的首选尺寸。

### layout

记录自身帧，并把同一矩形转发给子组件布局。记录的帧同时是悬停命中区域与气泡的锚点。

```cangjie
public func layout(ctx: UiContext, rect: Rect): Unit
```

**参数**

- `ctx`: [`UiContext`](UiContext.md) — 本轮布局使用的 UI 上下文。
- `rect`: `Rect` — 父级最终分配给组件的矩形。

### draw

先绘制子组件；指针驻留满 500 毫秒后向宿主注册提示文本，未满时请求下一帧继续计时。指针不在帧内时重置驻留计时。

```cangjie
public func draw(ctx: UiContext): Unit
```

**参数**

- `ctx`: [`UiContext`](UiContext.md) — 本轮绘制使用的 UI 上下文。

### handle

原样转发给子组件。

```cangjie
public func handle(ctx: UiContext, event: UiEvent): Bool
```

**参数**

- `ctx`: [`UiContext`](UiContext.md) — 本轮事件处理使用的 UI 上下文。
- `event`: `UiEvent` — 本轮待处理的 UI 事件。

**返回值** `Bool` — 子组件是否消费了事件。

### isFlexible

转发子组件的弹性标志。

```cangjie
public func isFlexible(): Bool
```

**返回值** `Bool` — 子组件的取值。

### flexWeight

转发子组件的弹性权重。

```cangjie
public func flexWeight(): Float32
```

**返回值** `Float32` — 子组件的取值。

### acceptsStretch

转发子组件在该轴上是否接受拉伸。

```cangjie
public func acceptsStretch(axis: Axis): Bool
```

**参数**

- `axis`: [`Axis`](Axis.md) — 询问的轴向。

**返回值** `Bool` — 子组件的取值。

### participatesInLayout

转发子组件是否参与父布局。

```cangjie
public func participatesInLayout(): Bool
```

**返回值** `Bool` — 子组件的取值。

### focusableId

转发子组件的焦点标识。包装不改变 Tab 遍历。

```cangjie
public func focusableId(): ?String
```

**返回值** `?String` — 子组件的取值。

### focusableIds

转发子组件子树的全部焦点项。

```cangjie
public func focusableIds(): Array<String>
```

**返回值** `Array<String>` — 子组件的取值，声明顺序。

## 另请参阅

- [IconButton](../media/IconButton.md) — 最常被 Tooltip 包装的纯图标控件。
- [UiContext](UiContext.md) — 承载单槽提示浮层的每帧服务枢纽。
