[cui](../../index.md) › [cui.text](index.md) › TextField

# TextField

`cui.text` 包中的 public class

单行文本编辑控件：把输入写回绑定的 `Bindable<String>`，按桌面惯例提供点选拖选、双击选词、Ctrl 快捷键、分组撤销与光标水平跟随。光标与选区锚点是 UTF-8 文本的字节偏移，连同水平滚动一起按控件标识跨帧保留；绑定可以是 [`State`](../core/State.md)，也可以是任何 [`Bindable`](../core/Bindable.md) 实现，例如指向模型字段的双向绑定。

## 声明

```cangjie
public class TextField <: Widget
```

## 继承

`TextField <: Widget` — 实现组件接口 [`Widget`](../core/Widget.md)。

## 说明

- **字节偏移语义**：光标与锚点是 UTF-8 字节偏移（始终落在字符边界上），不是字符计数。通过 `cursor`/`anchor` 参数从外部接管这两个状态时，必须让它们保持在字符边界并成对移动——只挪光标会留下陈旧锚点，凭空张开一段用户从未做过的选区，下一次按键就会把它整段替换掉。完整的编辑操作见 [`TextEditState`](TextEditState.md)。
- **编辑快捷键**：Ctrl+A 全选、Ctrl+C 复制、Ctrl+X 剪切、Ctrl+V 粘贴、Ctrl+Z 撤销、Ctrl+Y 与 Ctrl+Shift+Z 重做；Home/End 移到两端，按住 Shift 的方向键扩展选区。粘贴的多行文本被折叠为一行（换行变空格、回车符丢弃）。剪贴板访问按尽力而为处理：没有桌面会话时复制粘贴静默失败，不会让控件崩溃。
- **分组撤销**：500 毫秒内的连续编辑合并为一步撤销，停顿即开新组；光标跳转（点击、方向键导航）也会切分撤销组；撤销栈上限 300 步。空操作编辑（如在开头按退格）不产生撤销步。
- **水平跟随**：值比控件宽时文本窗口左移，且仅在光标越出可视窗口时移动（桌面编辑器的常见手感）；偏移有限制，文本尾部不会脱离右缘。
- **焦点与 IME**：聚焦时每帧把光标矩形上报为 IME 候选窗锚点；`TextEditing` pre-edit 独立保存并以文本加下划线绘制，不会提前写入绑定值，`TextInput` 到达才提交；`editable: false` 渲染为只读且不进入 Tab 焦点遍历，但仍可点选、全选与复制。

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let app = DesktopApp(WindowSpec("TextField", 640, 420))
    app.run {
        let name = rememberState<String>("name") {"张三丰"}
        let field = TextField(name).autofocus()
        // 运行时：在单行字段中编辑姓名，光标与选择随常规键盘操作移动。
    }
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init(...)`](#init) | 构造单行编辑框，并把它注册进当前声明式构建块。 |

**方法**

| 成员 | 说明 |
|---|---|
| [`autofocus()`](#autofocus) | 控件首次出现时申请键盘焦点，返回自身以便链式声明。 |
| [`undo()`](#undo) | 回退最近一组编辑；同时绑定在 Ctrl+Z。 |
| [`redo()`](#redo) | 重做最近撤销的编辑；同时绑定在 Ctrl+Y 与 Ctrl+Shift+Z。 |
| [`measure(...)`](#measure) | [`Widget`](../core/Widget.md) 协议实现：占满可用宽度，高度固定为标准控件高 38 逻辑像素。 |
| [`layout(...)`](#layout) | [`Widget`](../core/Widget.md) 协议实现：记录分配的框架矩形，供绘制与命中测试使用。 |
| [`draw(...)`](#draw) | [`Widget`](../core/Widget.md) 协议实现：绘制底框、选区、文本与光标，三者共用同一水平跟随偏移并整体裁剪进框内。 |
| [`handle(...)`](#handle) | [`Widget`](../core/Widget.md) 协议实现：处理定位与拖选、双击选词与三击选行、字符输入、编辑导航键及 Ctrl 快捷键表。 |
| [`focusableId()`](#focusableid) | [`Widget`](../core/Widget.md) 协议实现：返回本控件的焦点标识。 |

## 构造函数

### init

构造单行编辑框，并把它注册进当前声明式构建块。

```cangjie
public init(
    text: Bindable<String>,
    key!: ?String = None,
    cursor!: ?State<Int64> = None,
    anchor!: ?State<Int64> = None,
    editable!: Bool = true
)
```

**参数**

- `text`: `Bindable<String>` — 被编辑的值；每次输入、粘贴与撤销都直接写回该绑定。
- `key!`: `?String` — 显式控件标识；默认 `None`，按声明顺序自动派生。需要编辑状态跨结构变化保留时传入稳定键。
- `cursor!`: `?State<Int64>` — 外部接管的光标字节偏移；默认 `None`，控件在自身标识下保留光标，初值在文本末尾。
- `anchor!`: `?State<Int64>` — 外部接管的选区锚点字节偏移；默认 `None`，初值与光标重合（无选区）。接管时必须与 `cursor` 成对移动。
- `editable!`: `Bool` — 默认 `true`；传 `false` 渲染为只读，拒绝编辑事件且不进入 Tab 焦点遍历。

**异常**

- `IllegalArgumentException` — `key` 传入空字符串时。

## 方法

### autofocus

控件首次出现时申请键盘焦点，返回自身以便链式声明。焦点在该帧的指针事件之后一次性生效（启动瞬间的偶发点击取消不了它），并按键盘聚焦惯例显示焦点环；之后的帧把焦点交还给用户。

```cangjie
public func autofocus(): TextField
```

**返回值** `TextField` — 控件自身。

### undo

回退最近一组编辑；同时绑定在 Ctrl+Z。分组规则见页首说明；没有可回退的编辑时调用无效果。

```cangjie
public func undo(): Unit
```

### redo

重做最近撤销的编辑；同时绑定在 Ctrl+Y 与 Ctrl+Shift+Z。任何新编辑都会清空重做栈；没有可重做的编辑时调用无效果。

```cangjie
public func redo(): Unit
```

### measure

[`Widget`](../core/Widget.md) 协议实现：占满可用宽度，高度固定为标准控件高 38 逻辑像素。

```cangjie
public func measure(_: UiContext, available: Size): Size
```

**参数**

- `available`: `Size` — 父级给出的可用尺寸约束。

**返回值** `Size` — 组件请求的尺寸；方法接收 `available` 时，该尺寸在父级给出的可用约束内计算。

### layout

[`Widget`](../core/Widget.md) 协议实现：记录分配的框架矩形，供绘制与命中测试使用。

```cangjie
public func layout(_: UiContext, rect: Rect): Unit
```

**参数**

- `rect`: `Rect` — 父级最终分配给组件的矩形。

### draw

[`Widget`](../core/Widget.md) 协议实现：绘制底框、选区、文本、IME pre-edit 与光标，共用同一水平跟随偏移并整体裁剪进框内。点击定位使用 SDL_ttf shaped-cluster hit test，避免长行逐前缀测量并正确处理连字/RTL。聚焦时把光标矩形上报为 IME 锚点，并请求后续帧以维持光标闪烁。

```cangjie
public func draw(ctx: UiContext): Unit
```

**参数**

- `ctx`: [`UiContext`](../core/UiContext.md) — 本轮绘制使用的 UI 上下文。

### handle

[`Widget`](../core/Widget.md) 协议实现：处理定位与拖选、双击选词与三击选行、字符输入、编辑导航键及 Ctrl 快捷键表。只读字段不申请文本光标形状、拒绝编辑事件，但点选与复制照常。

```cangjie
public func handle(ctx: UiContext, event: UiEvent): Bool
```

**参数**

- `ctx`: [`UiContext`](../core/UiContext.md) — 本轮事件处理使用的 UI 上下文。
- `event`: `UiEvent` — 本轮待处理的 UI 事件。

**返回值** `Bool` — 是否已消费该事件；`true` 表示调用方不应再继续分发。

### focusableId

[`Widget`](../core/Widget.md) 协议实现：返回本控件的焦点标识。单子组件包装器由此转发焦点项，`.enabled(false)` 由此把控件摘出 Tab 遍历。

```cangjie
public func focusableId(): ?String
```

**返回值** `?String` — 该控件用于参与键盘焦点导航的标识。

## 另请参阅

- [TextEditState](TextEditState.md) — 本控件使用的编辑操作与字节偏移规则。
- [TextArea](TextArea.md) — 多行变体，带垂直滚动。
- [ComboBox](ComboBox.md) — 内嵌本控件的可输入下拉。
- [State](../core/State.md) — 可绑定的可观察状态单元。
