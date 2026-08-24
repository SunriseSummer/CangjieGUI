[cui](../../index.md) › [cui.text](index.md) › TextArea

# TextArea

`cui.text` 包中的 public class

多行文本编辑控件：把编辑写回绑定的 `Bindable<String>`，带垂直滚动与右缘滚动条，行间导航按字节列对齐。沿用单行编辑的全部桌面惯例（多击选择、Ctrl 快捷键表、分组撤销），文档的行拆分按文本修订号缓存，滚动不会每帧重拆整篇文本；绑定可以是 [`State`](../core/State.md)，也可以是任何 [`Bindable`](../core/Bindable.md) 实现。

## 声明

```cangjie
public class TextArea <: Widget
```

## 继承

`TextArea <: Widget` — 实现组件接口 [`Widget`](../core/Widget.md)。

## 说明

- **字节偏移语义**：与 [`TextField`](TextField.md) 相同，光标与选区锚点是 UTF-8 字节偏移。从外部接管 `cursor` 后再从外部移动它（加载文件、程序化粘贴）时必须连同 `anchor` 一起移动，否则陈旧锚点会张开一段用户从未做过的选区，下一次按键将整段替换。完整的编辑操作见 [`TextEditState`](TextEditState.md)。
- **键盘表**：方向键按字符移动，Up/Down 跨行且尽量保持字节列；Home/End 移到**行**首尾（单行控件则是全文首尾）；Enter 插入换行；按住 Shift 的所有导航键扩展选区；Ctrl+A/C/X/V/Z/Y 与 Ctrl+Shift+Z 同单行控件。
- **只读模式**：`editable: false` 时仍可移动光标、选择和复制；Ctrl+X 只复制而不删除，粘贴与撤销/重做会被忽略，控件不进入 Tab 焦点遍历。
- **滚动**：滚轮只在内容超出视口时被消费（内容装得下时让给外层滚动容器，不留死区）；键盘编辑与导航后视口滚动最小距离让光标所在行可见，指针路径不做跟随。滚动偏移每帧限制在内容范围，且仅在值变化时写回，外部接管的滚动状态不会收到空写通知。
- **粘贴换行处理**：保留多行内容，但把 Windows 的 CRLF 和单独的 CR 统一为 `\n`；否则行尾残留的 `\r` 会干扰 End、退格和文字测量。剪贴板不可用时复制/粘贴会静默失败，不会让控件退出。
- **撤销**：与单行控件相同——500 毫秒内连续编辑合并一步、光标跳转切分撤销组、栈上限 300 步；撤销/重做后自动滚动到光标行。

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let app = DesktopApp(WindowSpec("TextArea", 640, 420))
    app.run {
        let draft = rememberState<String>("draft") {"会议纪要"}
        let area = TextArea(draft).autofocus()
        // 运行时：在多行编辑区输入、换行并滚动，绑定文本实时更新。
    }
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init(...)`](#init) | 构造多行编辑区，并把它注册进当前声明式构建块。 |

**方法**

| 成员 | 说明 |
|---|---|
| [`autofocus()`](#autofocus) | 可编辑区域首次出现时申请键盘焦点，返回自身以便链式声明。 |
| [`undo()`](#undo) | 回退最近一组编辑；同时绑定在 Ctrl+Z。 |
| [`redo()`](#redo) | 重做最近撤销的编辑；同时绑定在 Ctrl+Y 与 Ctrl+Shift+Z。 |
| [`measure(...)`](#measure) | [`Widget`](../core/Widget.md) 协议实现：占满全部可用空间。 |
| [`layout(...)`](#layout) | [`Widget`](../core/Widget.md) 协议实现：记录分配的框架矩形，供绘制与命中测试使用。 |
| [`draw(...)`](#draw) | [`Widget`](../core/Widget.md) 协议实现：绘制底框、选区、可见行、光标与右缘滚动条。 |
| [`handle(...)`](#handle) | [`Widget`](../core/Widget.md) 协议实现：处理滚动条与滚轮、定位与多击选择、字符输入、Enter 换行、编辑导航键及 Ctrl 快捷键表。 |
| [`isFlexible()`](#isflexible) | [`Widget`](../core/Widget.md) 协议实现：返回 `true`，在栈布局中参与剩余空间分配。 |
| [`focusableId()`](#focusableid) | [`Widget`](../core/Widget.md) 协议实现：可编辑时返回控件标识，只读区域返回 `None`。 |

## 构造函数

### init

构造多行编辑区，并把它注册进当前声明式构建块。

```cangjie
public init(
    text: Bindable<String>,
    key!: ?String = None,
    scroll!: ?State<Float32> = None,
    cursor!: ?State<Int64> = None,
    anchor!: ?State<Int64> = None,
    editable!: Bool = true
)
```

**参数**

- `text`: `Bindable<String>` — 被编辑的文档；每次输入、粘贴与撤销都直接写回该绑定。
- `key!`: `?String` — 显式控件标识；默认 `None`，按声明顺序自动派生。需要编辑状态跨结构变化保留时传入稳定键。
- `scroll!`: `?State<Float32>` — 外部接管的垂直滚动偏移，逻辑像素；默认 `None`，控件在自身标识下保留。
- `cursor!`: `?State<Int64>` — 外部接管的光标字节偏移；默认 `None`，初值在文本末尾。
- `anchor!`: `?State<Int64>` — 外部接管的选区锚点字节偏移；默认 `None`，初值与光标重合（无选区）。接管时必须与 `cursor` 成对移动。
- `editable!`: `Bool` — 默认 `true`；传 `false` 渲染为只读：可导航选择复制，不可编辑，不进入 Tab 焦点遍历。

**异常**

- `IllegalArgumentException` — `key` 传入空字符串时。

## 方法

### autofocus

可编辑区域首次出现时申请键盘焦点，返回自身以便链式声明。焦点在该帧的指针事件之后一次性生效并显示焦点环；只读区域的申请被忽略。

```cangjie
public func autofocus(): TextArea
```

**返回值** `TextArea` — 控件自身。

### undo

回退最近一组编辑；同时绑定在 Ctrl+Z。回退后自动滚动到光标所在行；没有可回退的编辑时调用无效果。

```cangjie
public func undo(): Unit
```

### redo

重做最近撤销的编辑；同时绑定在 Ctrl+Y 与 Ctrl+Shift+Z。任何新编辑都会清空重做栈；没有可重做的编辑时调用无效果。

```cangjie
public func redo(): Unit
```

### measure

[`Widget`](../core/Widget.md) 协议实现：占满全部可用空间。

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

[`Widget`](../core/Widget.md) 协议实现：绘制底框、选区、可见行、IME pre-edit、光标与右缘滚动条。先把滚动偏移限制在内容范围（仅在变化时写回），行内容来自按修订号缓存的行拆分；点击定位使用 shaped-cluster hit test；聚焦时上报 IME 光标锚点并维持光标闪烁。

```cangjie
public func draw(ctx: UiContext): Unit
```

**参数**

- `ctx`: [`UiContext`](../core/UiContext.md) — 本轮绘制使用的 UI 上下文。

### handle

[`Widget`](../core/Widget.md) 协议实现：处理滚动条与滚轮、定位与多击选择、字符输入、Enter 换行、编辑导航键及 Ctrl 快捷键表。滚轮只在内容超出视口时被消费；只读区域不申请文本光标形状。

```cangjie
public func handle(ctx: UiContext, event: UiEvent): Bool
```

**参数**

- `ctx`: [`UiContext`](../core/UiContext.md) — 本轮事件处理使用的 UI 上下文。
- `event`: `UiEvent` — 本轮待处理的 UI 事件。

**返回值** `Bool` — 是否已消费该事件；`true` 表示调用方不应再继续分发。

### isFlexible

[`Widget`](../core/Widget.md) 协议实现：返回 `true`，在栈布局中参与剩余空间分配。

```cangjie
public func isFlexible(): Bool
```

**返回值** `Bool` — 固定为 `true`，组件可参与父布局的弹性空间分配。

### focusableId

[`Widget`](../core/Widget.md) 协议实现：可编辑时返回控件标识，只读区域返回 `None`。只读区域从未注册焦点项，无需被 `.enabled(false)` 摘除。

```cangjie
public func focusableId(): ?String
```

**返回值** `?String` — 可编辑时返回参与键盘焦点导航的标识；只读文本区返回 `None`。

## 另请参阅

- [TextField](TextField.md) — 单行变体，带水平光标跟随。
- [TextEditState](TextEditState.md) — 两个控件共享的编辑操作。
- [ScrollBar](../core/ScrollBar.md) — 本控件复用的可拖动滚动条。
