[cui](../../index.md) › [cui.core](index.md) › ImeComposition

# ImeComposition

输入法尚未提交的预编辑文本快照。文本控件用它绘制正在组合的文字和选区；内容只用于显示，不会提前写入绑定值。

## 声明

```cangjie
public struct ImeComposition {
    public let text: String
    public let selectionStart: Int32
    public let selectionLength: Int32
}
```

## 构造函数

```cangjie
public init(text: String, selectionStart: Int32, selectionLength: Int32)
```

- `text`：输入法当前提供的预编辑文本。
- `selectionStart`：输入法报告的选区起点。
- `selectionLength`：输入法报告的选区长度。

三个字段均为只读。CUI 按 SDL 事件原样保存选区数值，不改变输入法采用的索引单位。

## 示例

```cangjie verify
package docexample

import cui.core.ImeComposition

main(): Unit {
    let composition = ImeComposition("拼音", 0, 2)
    println(composition.text)
}
```

## 另请参阅

- [`UiContext.imeComposition`](UiContext.md#ime-composition) — 读取当前焦点控件的预编辑状态。
- [`ImeCandidates`](ImeCandidates.md) — 可选的输入法候选列表快照。
