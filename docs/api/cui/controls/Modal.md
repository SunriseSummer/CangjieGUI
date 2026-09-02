[cui](../../index.md) › [cui.controls](index.md) › Modal

# Modal

位于 `cui.controls` 包的公开类

模态对话框：`presented` 为真时把 `body` 子树布局在一块对视口居中的面板里，经浮层浮于整棵界面树之上并压暗背景，事件一律不再落到背景树。对话框承载的是真实组件子树——按钮、文本框乃至会再弹浮层的控件都按平常方式工作；Escape 或按下背景即关闭。

## 声明

```cangjie
public class Modal <: Widget
```

## 继承

`Modal <: Widget` — 实现 [`Widget`](../core/Widget.md) 组件协议。

## 说明

与下拉、右键菜单等亲手绘制内容的浮层不同，Modal 经 [`Overlay`](../core/Overlay.md) 注册进 [`UiContext`](../core/UiContext.md) 浮层栈后，把事件路由进 `body` 子树、把子树绘制在面板之上，所以对话框内的控件保有普通状态；其中会自开弹层的控件（[`Dropdown`](Dropdown.md)、[`ComboBox`](../text/ComboBox.md)、[`ContextMenu`](ContextMenu.md)）在浮层栈上注册于对话框之上，画在其上、先收事件。

Modal 是焦点陷阱：Tab/Shift+Tab 只在对话框自己的焦点项之间循环（无焦点时前向从第一个进入、后向从最后一个进入），永不逃逸到背景下的控件。`body` 仅在 `presented` 为真时构建，隐藏时不构建内容、也不注册焦点项。

对话框在树中不占位（测量恒为零），放在哪都行——典型做法是挂在根部的 [`ZStack`](../core/ZStack.md) 里；面板尺寸取 `body` 测量结果加内边距，宽封顶于 min(视口 85%, 460)、高封顶于视口 85%。`presented` 在本帧事件阶段才翻真时，对话框推迟到下一帧（body 构建完成后）出现，避免闪现一帧空面板。

关闭途径：Escape 或按下背景把 `presented` 写回 `false`、移除浮层并调用 `onDismiss`；应用代码直接把 `presented` 置 `false`（如“取消”按钮）同样关闭，但不触发 `onDismiss`。

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let app = DesktopApp(WindowSpec("Modal", 640, 420))
    app.run {
        let confirmOpen = rememberState("confirmOpen") {false}
        let dismissed = rememberState<Int64>("dismissed") {0}
        VStack(spacing: 12.vp) {
            Button("删除项目", {=> confirmOpen.value = true}, role: ButtonRole.Danger)
            Label("已从对话框关闭 ${dismissed.value} 次").muted()
        }.padding(24.0)
        Modal(confirmOpen, onDismiss: {=> dismissed.value = dismissed.value + 1}) {
            VStack {
                Label("清空回收站？")
                Button("取消", {=> confirmOpen.value = false})
                Button("确认", {=> confirmOpen.value = false})
            }
        }
        // 运行时：点击“删除项目”打开模态框；取消、确认或 Escape 都会关闭它。
    }
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init(...)`](#init) | 以呈现状态、可选关闭回调与内容构建器构造对话框。 |

**方法**

| 成员 | 说明 |
|---|---|
| [`measure(_: UiContext, _: Size)`](#measure) | 恒返回零尺寸——对话框不占父布局空间。 |
| [`layout(ctx: UiContext, _: Rect)`](#layout) | 把面板对视口居中：按 `body` 测量结果加内边距定尺寸，忽略传入矩形。 |
| [`draw(ctx: UiContext)`](#draw) | `presented` 为真且内容已构建时，把对话框注册进浮层栈。 |
| [`handle(ctx: UiContext, event: UiEvent)`](#handle) | 只把 `Frame` 帧事件转发给对话框内容，其余输入经浮层进入；恒返回 `false`。 |
| [`focusableIds()`](#focusableids) | 返回对话框 `body` 里声明的焦点项（隐藏时为空）——焦点陷阱循环的集合。 |

## 构造函数

### init

以呈现状态、可选关闭回调与内容构建器构造对话框。

```cangjie
public init(presented: Bindable<Bool>, onDismiss!: ?() -> Unit = None, body!: () -> Unit)
```

**参数**

- `presented`: [`Bindable`](../core/Bindable.md)`<Bool>` — 是否呈现的双向绑定：为真时构建并显示对话框；对话框自行关闭时写回 `false`。
- `onDismiss!`: `?() -> Unit` — 对话框自行关闭（Escape 或按下背景）后的回调；默认 `None` 不回调。应用代码直接改写 `presented` 不触发它。
- `body!`: `() -> Unit` — 对话框内容的界面构建函数，仅 `presented` 为真时执行。

## 方法

### measure

恒返回零尺寸——对话框不占父布局空间。[`Widget`](../core/Widget.md) 协议方法。

```cangjie
public func measure(_: UiContext, _: Size): Size
```

**返回值** `Size` — 组件请求的尺寸；方法接收 `available` 时，该尺寸在父级给出的可用约束内计算。

### layout

把面板对视口居中：按 `body` 测量结果加内边距定尺寸，忽略传入矩形。宽封顶于 min(视口 85%, 460)、高封顶于视口 85%，随后在面板内边距内布局 `body`。[`Widget`](../core/Widget.md) 协议方法。

```cangjie
public func layout(ctx: UiContext, _: Rect): Unit
```

**参数**

- `ctx`: [`UiContext`](../core/UiContext.md) — 本轮布局使用的 UI 上下文。

### draw

`presented` 为真且内容已构建时，把对话框注册进浮层栈。本帧事件阶段才翻真的对话框推迟到下一帧出现，避免闪现空面板。[`Widget`](../core/Widget.md) 协议方法。

```cangjie
public func draw(ctx: UiContext): Unit
```

**参数**

- `ctx`: [`UiContext`](../core/UiContext.md) — 本轮绘制使用的 UI 上下文。

### handle

只把 `Frame` 帧事件转发给对话框内容，其余输入经浮层进入；恒返回 `false`。帧事件驱动对话框内的定时行为（文本框自动聚焦、应用帧钩子）。[`Widget`](../core/Widget.md) 协议方法。

```cangjie
public func handle(ctx: UiContext, event: UiEvent): Bool
```

**参数**

- `ctx`: [`UiContext`](../core/UiContext.md) — 本轮事件处理使用的 UI 上下文。
- `event`: `UiEvent` — 本轮待处理的 UI 事件。

**返回值** `Bool` — 是否已消费该事件；`true` 表示调用方不应再继续分发。

### focusableIds

返回对话框 `body` 里声明的焦点项（隐藏时为空）——焦点陷阱循环的集合。[`Widget`](../core/Widget.md) 协议方法。

```cangjie
public func focusableIds(): Array<String>
```

**返回值** `Array<String>` — 当前对话框焦点陷阱中的导航标识；对话框隐藏时为空。

## 另请参阅

- [Overlay](../core/Overlay.md) — 对话框借以浮起的交互浮层。
- [UiContext](../core/UiContext.md) — 浮层栈、焦点与事件路由的宿主。
- [ZStack](../core/ZStack.md) — 挂载对话框的常用根容器。
