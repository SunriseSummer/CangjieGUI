[cui](../../index.md) › [cui.text](index.md) › TextEditState

# TextEditState

位于 `cui.text` 包的公开类

有光标的文本框与文本域共享的文本编辑模型：文本绑定、光标与选择锚点，以及在这三者上实现的全部编辑操作（插入/删除、按字符/行/整体移动与扩展选择、词与行选择）。

## 声明

```cangjie
public class TextEditState
```

## 说明

选择区是 `anchor` 与 `cursor` 之间的跨度；两者重合即无选择，编辑严格按普通光标行为走。全部偏移是 UTF-8 字节偏移，操作前都会规范到扩展字素边界（[`normalizeCursor`](#normalizecursor) 每帧运行、只在需要时写回）。`move*` 系列折叠选择（有选择时落到行进方向的近端），`extend*` 系列保留锚点——按住 Shift 的语义。模型的垂直移动按字素列计数；TextArea 在此基础上使用实际字体的像素列导航。

## 示例

```cangjie verify
package docexample

import cui.text.TextEditState

main(): Unit {
    let edit = TextEditState("hello cui")
    // 双击选词:光标落在开头,选中 hello
    edit.selectWordAt(1)
    println("选中「${edit.selectedText()}」")
    edit.insert("你好")
    println("替换后 ${edit.text.value}")
    edit.selectAll()
    println("全选范围 ${edit.selectionStart()}..${edit.selectionEnd()}")
    edit.backspace()
    println("删除后「${edit.text.value}」 光标 ${edit.cursor.value}")
    // 输出: 选中「hello」
    // 替换后 你好 cui
    // 全选范围 0..10
    // 删除后「」 光标 0
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init(...)`](#init) | 绑定形态：外部文本绑定加可选的光标/锚点状态；便捷形态：以初始字符串自建三者（光标与锚点落在末尾）。 |

**字段**

| 成员 | 说明 |
|---|---|
| [`text`](#text) | 文本内容绑定。 |
| [`cursor`](#cursor) | 光标字节偏移状态。 |
| [`anchor`](#anchor) | 选择锚点字节偏移状态；与光标重合即无选择。 |

**方法（选择查询与设置）**

| 成员 | 说明 |
|---|---|
| [`normalizeCursor()`](#normalizecursor) | 把光标与锚点规范到扩展字素边界（只在需要时写回，避免每帧空通知）。 |
| [`hasSelection()`](#hasselection) | 是否选中了非空范围。 |
| [`selectionStart()`](#selectionstart) | 选择区低端字节偏移（无选择时即光标）。 |
| [`selectionEnd()`](#selectionend) | 选择区高端字节偏移（无选择时即光标）。 |
| [`selectedText()`](#selectedtext) | 选中的子串，无选择时为空。 |
| [`selectAll()`](#selectall) | 全选，光标留在末尾。 |
| [`selectWordAt(...)`](#selectwordat) | 选中 `position` 周围同类字符的连续段（双击语义）。 |
| [`selectLineAt(...)`](#selectlineat) | 选中含 `position` 的整行含行尾换行（三击语义）。 |
| [`clearSelection()`](#clearselection) | 把选择折叠到光标上。 |

**方法（编辑）**

| 成员 | 说明 |
|---|---|
| [`deleteSelection()`](#deleteselection) | 删除选中范围（如有），返回文本是否变化。 |
| [`insert(...)`](#insert) | 以一次文本赋值替换选区或插入。 |
| [`backspace()`](#backspace) | 删选择区，否则删光标前一个字符。 |
| [`deleteForward()`](#deleteforward) | 删选择区，否则删光标后一个字符。 |

**方法（移动与扩展）**

| 成员 | 说明 |
|---|---|
| [`moveLeft()`](#moveleft) / [`moveRight()`](#moveright) | 左移一个扩展字素边界；有选择时折叠到选择低端。 |
| [`extendLeft()`](#extendleft) / [`extendRight()`](#extendright) | 保留锚点左扩展一个扩展字素边界（Shift+Left）。 |
| [`moveToStart()`](#movetostart) / [`moveToEnd()`](#movetoend) | 跳到文本开头并折叠选择。 |
| [`extendToStart()`](#extendtostart) / [`extendToEnd()`](#extendtoend) | 保留锚点扩展到文本开头。 |
| [`moveToLineStart()`](#movetolinestart) / [`moveToLineEnd()`](#movetolineend) | 跳到行首并折叠选择。 |
| [`extendToLineStart()`](#extendtolinestart) / [`extendToLineEnd()`](#extendtolineend) | 保留锚点扩展到行首（Shift+Home）。 |
| [`moveLineUp()`](#movelineup) / [`moveLineDown()`](#movelinedown) | 保列上移一行并折叠选择。 |
| [`extendLineUp()`](#extendlineup) / [`extendLineDown()`](#extendlinedown) | 保留锚点保列上移一行（Shift+Up）。 |
| [`moveTo(...)`](#moveto) | 光标落到 `position` 并折叠选择（单击）。 |
| [`extendTo(...)`](#extendto) | 光标移到 `position`、保留锚点（拖拽选择）。 |

## 构造函数

### init

绑定形态：外部文本绑定加可选的光标/锚点状态；便捷形态：以初始字符串自建三者（光标与锚点落在末尾）。

```cangjie
public init(text: Bindable<String>, cursor!: ?State<Int64> = None, anchor!: ?State<Int64> = None)
```

```cangjie
public init(value: String)
```

**参数**

- `text`: [`Bindable`](../core/Bindable.md)`<String>` — 文本绑定；编辑写回它。
- `cursor!`、`anchor!`: `?State<Int64>` — 外部持有的光标/锚点；默认值均为 `None`，此时内部自建状态（光标在末尾、锚点随光标）。
- `value`: `String` — 便捷形态的初始文本。

## 字段

### text

文本内容绑定。

```cangjie
public let text: Bindable<String>
```

### cursor

光标字节偏移状态。

```cangjie
public let cursor: State<Int64>
```

### anchor

选择锚点字节偏移状态；与光标重合即无选择。

```cangjie
public let anchor: State<Int64>
```

## 方法

### normalizeCursor

把光标与锚点规范到扩展字素边界（只在需要时写回，避免每帧空通知）。

```cangjie
public func normalizeCursor(): Unit
```

### hasSelection

是否选中了非空范围。

```cangjie
public func hasSelection(): Bool
```

**返回值** `Bool` — 锚点与光标（各自规范化后）不同即 `true`。

### selectionStart

选择区低端字节偏移（无选择时即光标）。

```cangjie
public func selectionStart(): Int64
```

**返回值** `Int64` — 低端字节偏移。

### selectionEnd

选择区高端字节偏移（无选择时即光标）。

```cangjie
public func selectionEnd(): Int64
```

**返回值** `Int64` — 高端字节偏移。

### selectedText

选中的子串，无选择时为空。

```cangjie
public func selectedText(): String
```

**返回值** `String` — 选中内容。

### selectAll

全选，光标留在末尾。

```cangjie
public func selectAll(): Unit
```

### selectWordAt

选中 `position` 周围同类字符的连续段（双击语义）。

```cangjie
public func selectWordAt(position: Int64): Unit
```

**参数**

- `position`: `Int64` — 字节偏移；越界先规范。

### selectLineAt

选中含 `position` 的整行含行尾换行（三击语义）。

```cangjie
public func selectLineAt(position: Int64): Unit
```

**参数**

- `position`: `Int64` — 目标字节偏移；越界值先规范到有效的扩展字素边界。

### clearSelection

把选择折叠到光标上。

```cangjie
public func clearSelection(): Unit
```

### deleteSelection

删除选中范围（如有），返回文本是否变化。

```cangjie
public func deleteSelection(): Bool
```

**返回值** `Bool` — 有选择并已删除为 `true`。

### insert

以一次文本赋值替换选区或插入。光标与锚点落到插入内容之后。

```cangjie
public func insert(value: String): Unit
```

**参数**

- `value`: `String` — 插入的文本。

### backspace

删选择区，否则删光标前一个字符。在文本开头是无操作。

```cangjie
public func backspace(): Unit
```

### deleteForward

删选择区，否则删光标后一个字符。在文本末尾是无操作。

```cangjie
public func deleteForward(): Unit
```

### moveLeft

左移一个扩展字素边界；有选择时折叠到选择低端。

```cangjie
public func moveLeft(): Unit
```

### moveRight

右移一个扩展字素边界；有选择时折叠到选择高端。

```cangjie
public func moveRight(): Unit
```

### extendLeft

保留锚点左扩展一个扩展字素边界（Shift+Left）。

```cangjie
public func extendLeft(): Unit
```

### extendRight

保留锚点右扩展一个扩展字素边界（Shift+Right）。

```cangjie
public func extendRight(): Unit
```

### moveToStart

跳到文本开头并折叠选择。

```cangjie
public func moveToStart(): Unit
```

### moveToEnd

跳到文本末尾并折叠选择。

```cangjie
public func moveToEnd(): Unit
```

### extendToStart

保留锚点扩展到文本开头。

```cangjie
public func extendToStart(): Unit
```

### extendToEnd

保留锚点扩展到文本末尾。

```cangjie
public func extendToEnd(): Unit
```

### moveToLineStart

跳到行首并折叠选择。

```cangjie
public func moveToLineStart(): Unit
```

### moveToLineEnd

跳到行尾并折叠选择。

```cangjie
public func moveToLineEnd(): Unit
```

### extendToLineStart

保留锚点扩展到行首（Shift+Home）。

```cangjie
public func extendToLineStart(): Unit
```

### extendToLineEnd

保留锚点扩展到行尾（Shift+End）。

```cangjie
public func extendToLineEnd(): Unit
```

### moveLineUp

保列上移一行并折叠选择。已在首行时落到文本开头。

```cangjie
public func moveLineUp(): Unit
```

### moveLineDown

保列下移一行并折叠选择。已在末行时落到文本末尾。

```cangjie
public func moveLineDown(): Unit
```

### extendLineUp

保留锚点保列上移一行（Shift+Up）。

```cangjie
public func extendLineUp(): Unit
```

### extendLineDown

保留锚点保列下移一行（Shift+Down）。

```cangjie
public func extendLineDown(): Unit
```

### moveTo

光标落到 `position` 并折叠选择（单击）。

```cangjie
public func moveTo(position: Int64): Unit
```

**参数**

- `position`: `Int64` — 目标字节偏移；先规范到扩展字素边界。

### extendTo

光标移到 `position`、保留锚点（拖拽选择）。

```cangjie
public func extendTo(position: Int64): Unit
```

**参数**

- `position`: `Int64` — 光标要移到的目标字节偏移；锚点保持不变。

## 字素与词段

移动、扩展、删除和选区规范化共享 Unicode 17.0.0 的扩展字素规则；组合字符、emoji ZWJ／肤色／旗帜、韩文及 CRLF 不会被拆成部分字符。Backspace 和 Delete 在所有平台均按完整字素删除。外部偏移向前吸附；插入或删除导致相邻字素合并时，光标移到合并字素后的有效边界。

```cangjie
public func moveWordLeft(): Unit
public func moveWordRight(): Unit
public func extendWordLeft(): Unit
public func extendWordRight(): Unit
public func deleteWordBackward(): Unit
public func deleteWordForward(): Unit
```

词段按字母／数字／下划线、空白、符号分类，不提供中文／泰文词典分词。低层 TextEditState 不维护剪贴板或撤销历史；应用工具栏应使用 TextField／TextArea 的公开命令。参见 [文本编辑指南](../../../guide/how-to/text-editing.md)。

## 另请参阅

- [`TextField`](TextField.md) / [`TextArea`](TextArea.md) — 消费本模型的编辑控件。
