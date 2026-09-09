[cui](../../index.md) › [cui.text](index.md) › TextSelectionWidth

# TextSelectionWidth

编辑控件选区的水平覆盖策略，通过 `TextInputStyle.selectionWidth` 设置，根包 `cui` 同时导出。

```cangjie
public enum TextSelectionWidth {
    | Content
    | Viewport
}
```

- `Content`（默认）：覆盖被选中的字素及实际空格的排版宽度。仅选中换行符或选中的空行显示光标宽度的窄条，便于观察和复制空行。
- `Viewport`：选区包含硬换行符时，该行背景延伸至内视口右端；其它行仍按内容宽度绘制。

软换行不产生新的文档字符。选区高度由 `TextInputStyle.lineHeight` 控制，与此策略独立。

参见 [TextInputStyle](TextInputStyle.md) 和[文本编辑指南](../../../guide/how-to/text-editing.md)。
