[cui](../../index.md) › [cui.controls](index.md) › ContextMenu

# ContextMenu

位于 `cui.controls` 包的公开类

给任意子内容包上右键上下文菜单的透明包装组件。在子内容内按下鼠标右键，菜单在指针处经交互浮层浮到组件树之上——点击不会被其下方的控件截走；除此之外它把布局、绘制与全部其余事件原样转发给子组件。

## 声明

```cangjie
public class ContextMenu <: Widget
```

## 继承

- [`Widget`](../core/Widget.md) — 组件协议（measure/layout/draw/handle 与焦点遍历）。

## 说明

菜单行为遵循桌面惯例：选中一项执行其动作并关闭（关闭先于动作，动作因此可以安全地打开自己的浮层）；点击菜单外或按 Escape 撤销；方向键与悬停移动高亮（跳过分隔线与禁用行），Enter 执行高亮项。菜单位置会限制在视口内，靠近边缘时自动向内移动。

浮层以本控件标识注册在 [`UiContext`](../core/UiContext.md) 的浮层栈上，关闭时只移除自己的注册——其下方已打开的对话框不受影响。菜单行由 [`MenuItem`](MenuItem.md) 描述，可带快捷键提示、可禁用，`MenuItem.separator()` 插入分隔线。`items` 为空时右键不弹出任何东西。

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let app = DesktopApp(WindowSpec("ContextMenu", 640, 420))
    app.run {
        let deleted = rememberState<Int64>("deleted") {0}
        let row = ContextMenu(
            items: [
                MenuItem("重命名", {=> ()}),
                MenuItem.separator(),
                MenuItem("删除", {=> deleted.value = deleted.value + 1})
            ]
        ) {
            Label("项目 A")
        }
        Label("已删除 ${deleted.value} 次").muted()
        // 运行时：在“项目 A”上单击右键打开菜单，再选择重命名或删除。
    }
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init(items!: Array<MenuItem>, key!: ?String, body!: () -> Unit)`](#init) | 由菜单项与子内容构建器构造右键菜单包装。 |

**方法**

| 成员 | 说明 |
|---|---|
| [`measure(ctx: UiContext, available: Size)`](#measure) | 转发子组件的测量结果。 |
| [`layout(ctx: UiContext, rect: Rect)`](#layout) | 记录框架并原样布局子组件。 |
| [`draw(ctx: UiContext)`](#draw) | 绘制子组件；菜单打开时把弹出菜单注册为交互浮层。 |
| [`handle(ctx: UiContext, event: UiEvent)`](#handle) | 子内容内的右键按下打开菜单并消费；其余事件转发给子组件。 |
| [`isFlexible()`](#isflexible) | 转发子组件的弹性标记。 |
| [`flexWeight()`](#flexweight) | 转发子组件的弹性权重。 |
| [`acceptsStretch(axis: Axis)`](#acceptsstretch) | 转发子组件对拉伸的接受与否。 |
| [`participatesInLayout()`](#participatesinlayout) | 转发子组件是否占布局位置。 |
| [`focusableId()`](#focusableid) | 转发子组件的焦点 id。 |
| [`focusableIds()`](#focusableids) | 转发子组件子树的全部焦点 id。 |

## 构造函数

### init

由菜单项与子内容构建器构造右键菜单包装。

```cangjie
public init(items!: Array<MenuItem>, key!: ?String = None, body!: () -> Unit)
```

**参数**

- `items!`: `Array<MenuItem>` — 菜单行，见 [`MenuItem`](MenuItem.md)；为空时右键不弹出菜单。
- `key!`: `?String` — 显式控件标识（同时标识浮层注册）；空串抛 `IllegalArgumentException`。默认 `None`，按构建顺序自动派生。
- `body!`: `() -> Unit` — 子内容的界面构建函数；声明多个组件时按竖向堆叠包为一个子组件。

## 方法

### measure

转发子组件的测量结果。包装自身不占任何额外空间（见 [`Widget`](../core/Widget.md)）。

```cangjie
public func measure(ctx: UiContext, available: Size): Size
```

**参数**

- `ctx`: [`UiContext`](../core/UiContext.md) — 本轮测量使用的 UI 上下文。
- `available`: `Size` — 父级给出的可用尺寸约束。

**返回值** `Size` — 组件请求的尺寸；方法接收 `available` 时，该尺寸在父级给出的可用约束内计算。

### layout

记录框架并原样布局子组件。框架即右键的命中区域。

```cangjie
public func layout(ctx: UiContext, rect: Rect): Unit
```

**参数**

- `ctx`: [`UiContext`](../core/UiContext.md) — 本轮布局使用的 UI 上下文。
- `rect`: `Rect` — 父级最终分配给组件的矩形。

### draw

绘制子组件；菜单打开时把弹出菜单注册为交互浮层。浮层每帧重新注册，并把按下时的指针坐标调整到视口范围内。

```cangjie
public func draw(ctx: UiContext): Unit
```

**参数**

- `ctx`: [`UiContext`](../core/UiContext.md) — 本轮绘制使用的 UI 上下文。

### handle

子内容内的右键按下打开菜单并消费；其余事件转发给子组件。打开时高亮落在第一个可选行。

```cangjie
public func handle(ctx: UiContext, event: UiEvent): Bool
```

**参数**

- `ctx`: [`UiContext`](../core/UiContext.md) — 本轮事件处理使用的 UI 上下文。
- `event`: `UiEvent` — 本轮待处理的 UI 事件。

**返回值** `Bool` — 是否已消费该事件；`true` 表示调用方不应再继续分发。

### isFlexible

转发子组件的弹性标记。

```cangjie
public func isFlexible(): Bool
```

**返回值** `Bool` — 子组件报告的弹性参与标记。

### flexWeight

转发子组件的弹性权重。

```cangjie
public func flexWeight(): Float32
```

**返回值** `Float32` — 子组件报告的弹性权重。

### acceptsStretch

转发子组件对拉伸的接受与否。

```cangjie
public func acceptsStretch(axis: Axis): Bool
```

**参数**

- `axis`: [`Axis`](../core/Axis.md) — 要查询是否接受拉伸的布局轴。

**返回值** `Bool` — 子组件是否接受沿 `axis` 方向的拉伸。

### participatesInLayout

转发子组件是否占布局位置。

```cangjie
public func participatesInLayout(): Bool
```

**返回值** `Bool` — 子组件是否占用父布局中的位置。

### focusableId

转发子组件的焦点 id。

```cangjie
public func focusableId(): ?String
```

**返回值** `?String` — 子组件报告的焦点标识；没有单一焦点入口时为 `None`。

### focusableIds

转发子组件子树的全部焦点 id。包装对 Tab 遍历完全透明（见 [`Widget`](../core/Widget.md)）。

```cangjie
public func focusableIds(): Array<String>
```

**返回值** `Array<String>` — 子组件树中可参与键盘焦点导航的全部标识。

## 另请参阅

- [MenuItem](MenuItem.md) — 菜单行的描述类型。
- [MenuBar](MenuBar.md) — 顶部应用菜单栏，共用同一套菜单行。
- [UiContext](../core/UiContext.md) — 浮层栈的注册与分发。
