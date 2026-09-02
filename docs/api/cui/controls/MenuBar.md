[cui](../../index.md) › [cui.controls](index.md) › MenuBar

# MenuBar

位于 `cui.controls` 包的公开类

应用菜单栏：一行水平排列的菜单标题，点击标题即在其正下方弹出下拉菜单，菜单打开时指针掠过其他标题即切换过去。菜单由 [`Menu`](Menu.md) 值描述、条目为 [`MenuItem`](MenuItem.md)（可带快捷键提示、可禁用、可为分隔线）；整条菜单栏是一个键盘焦点项，方向键即可完成全部导航。

## 声明

```cangjie
public class MenuBar <: Widget
```

## 继承

`MenuBar <: Widget` — 实现 [`Widget`](../core/Widget.md) 组件协议。

## 说明

打开的下拉经 [`Overlay`](../core/Overlay.md) 注册进 [`UiContext`](../core/UiContext.md) 的浮层栈：事件先于界面树分发、绘制在树之后，菜单因此始终压在内容上方并优先收到输入。弹层锚在所属标题正下方，水平方向夹进视口，下方放不下时翻到菜单栏上方。标题格宽度随文字自适应，命中区与绘制共用同一套几何。

指针交互：点击标题打开、再点同一标题收起、点另一标题直接切换；菜单打开时悬停其他标题即切换（经典菜单栏手感）；点中可选条目执行其动作并关闭菜单，点击菜单与菜单栏之外的任意位置只关闭。

键盘交互：菜单栏聚焦后 ←/→ 沿标题移动焦点、Enter/Space/↓ 打开当前标题；菜单打开时 ↑/↓ 移动高亮（跳过分隔线与禁用行）、←/→ 切换相邻菜单（两端回绕）、Enter/Space 执行高亮行、Escape 关闭；Tab 关闭菜单且不消费事件，把控制权交还全局焦点遍历。

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let app = DesktopApp(WindowSpec("MenuBar", 640, 420))
    app.run {
        let saved = rememberState<Int64>("saved") {0}
        let bar = MenuBar(
            [
                Menu(
                    "文件",
                    [
                        MenuItem("保存", {=> saved.value = saved.value + 1}, shortcut: "Ctrl+S"),
                        MenuItem.separator(),
                        MenuItem("退出", {=> ()}, enabled: false)
                    ]
                ),
                Menu("帮助", [MenuItem("关于", {=> ()})])
            ]
        )
        Label("保存动作执行 ${saved.value} 次").padding(24.0)
        // 运行时：点击菜单标题或使用键盘打开下拉菜单，禁用项不可执行。
    }
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init(menus: Array<Menu>, key!: ?String = None)`](#init) | 以顶级菜单序列构造菜单栏。 |

**方法**

| 成员 | 说明 |
|---|---|
| [`measure(_: UiContext, available: Size)`](#measure) | 返回充满可用宽度、高度固定 34 逻辑像素的尺寸。 |
| [`layout(_: UiContext, rect: Rect)`](#layout) | 记录菜单栏的水平条框架，高度恒为 34 逻辑像素，忽略传入高度。 |
| [`draw(ctx: UiContext)`](#draw) | 绘制标题行，并在菜单打开时把下拉注册为浮层。 |
| [`handle(ctx: UiContext, event: UiEvent)`](#handle) | 点击标题打开其菜单并获得焦点；聚焦后 ←/→ 移动标题焦点、Enter/Space/↓ 打开。 |
| [`focusableId()`](#focusableid) | 返回菜单栏的焦点标识——整条菜单栏是一个键盘焦点项。 |
| [`isFlexible()`](#isflexible) | 恒为 `false`，菜单栏不参与栈内弹性空间分配。 |

## 构造函数

### init

以顶级菜单序列构造菜单栏。

```cangjie
public init(menus: Array<Menu>, key!: ?String = None)
```

**参数**

- `menus`: `Array<Menu>` — 顶级菜单，逐项为一个标题及其下拉条目；菜单栏按声明顺序从左到右排布。
- `key!`: `?String` — 显式焦点标识；默认 `None`，按构建顺序自动派生。

**异常**

- `IllegalArgumentException` — `key` 传入空字符串时。

## 方法

### measure

返回充满可用宽度、高度固定 34 逻辑像素的尺寸。[`Widget`](../core/Widget.md) 协议方法。

```cangjie
public func measure(_: UiContext, available: Size): Size
```

**参数**

- `available`: `Size` — 父级给出的可用尺寸约束。

**返回值** `Size` — 组件请求的尺寸；方法接收 `available` 时，该尺寸在父级给出的可用约束内计算。

### layout

记录菜单栏的水平条框架，高度恒为 34 逻辑像素，忽略传入高度。[`Widget`](../core/Widget.md) 协议方法。

```cangjie
public func layout(_: UiContext, rect: Rect): Unit
```

**参数**

- `rect`: `Rect` — 父级最终分配给组件的矩形。

### draw

绘制标题行，并在菜单打开时把下拉注册为浮层。打开的标题填强调色、悬停标题填活跃底色，键盘聚焦且未打开时画焦点环。

```cangjie
public func draw(ctx: UiContext): Unit
```

**参数**

- `ctx`: [`UiContext`](../core/UiContext.md) — 本轮绘制使用的 UI 上下文。

### handle

点击标题打开其菜单并获得焦点；聚焦后 ←/→ 移动标题焦点、Enter/Space/↓ 打开。菜单打开期间的事件由浮层处理（见上文说明），只有浮层主动放行的事件才会落回这里。[`Widget`](../core/Widget.md) 协议方法。

```cangjie
public func handle(ctx: UiContext, event: UiEvent): Bool
```

**参数**

- `ctx`: [`UiContext`](../core/UiContext.md) — 本轮事件处理使用的 UI 上下文。
- `event`: `UiEvent` — 本轮待处理的 UI 事件。

**返回值** `Bool` — 是否已消费该事件；`true` 表示调用方不应再继续分发。

### focusableId

返回菜单栏的焦点标识——整条菜单栏是一个键盘焦点项。[`Widget`](../core/Widget.md) 协议方法。

```cangjie
public func focusableId(): ?String
```

**返回值** `?String` — 该控件用于参与键盘焦点导航的标识。

### isFlexible

恒为 `false`，菜单栏不参与栈内弹性空间分配。[`Widget`](../core/Widget.md) 协议方法。

```cangjie
public func isFlexible(): Bool
```

**返回值** `Bool` — 固定为 `false`，组件按自身请求尺寸参与布局。

## 另请参阅

- [Menu](Menu.md) — 一个顶级菜单：标题与其下拉条目。
- [MenuItem](MenuItem.md) — 菜单条目：标签、动作、快捷键提示、禁用与分隔线。
- [ContextMenu](ContextMenu.md) — 右键弹出同款菜单的包装容器。
