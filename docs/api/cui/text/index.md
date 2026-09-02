[cui](../../index.md) › cui.text

# cui.text

```cangjie
import cui.text.*
```

文本编辑控件包：单行 [`TextField`](TextField.md)、多行 [`TextArea`](TextArea.md)、带建议列表的 [`ComboBox`](ComboBox.md)，以及共享的编辑模型 [`TextEditState`](TextEditState.md)。控件负责绘制、命中、选择和快捷键；文本值通过 Binding 由应用持有。

## 类型

**类**

| 类型 | 说明 |
|---|---|
| [`ComboBox`](ComboBox.md) | 可输入的下拉组合框：在内嵌单行编辑框上浮出建议列表，输入即过滤；绑定文本就是控件的值，自由输入即使不匹配任何选项也被保留。 |
| [`TextArea`](TextArea.md) | 多行文本编辑控件：把编辑写回绑定的 `Bindable<String>`，带垂直滚动与右缘滚动条，行间导航按字节列对齐。 |
| [`TextEditState`](TextEditState.md) | 有光标的文本框与文本域共享的文本编辑模型：文本绑定、光标与选择锚点，以及在这三者上实现的全部编辑操作（插入/删除、按字符/行/整体移动与扩展选择、词与行选择）。 |
| [`TextField`](TextField.md) | 单行文本编辑控件：把输入写回绑定的 `Bindable<String>`，按桌面惯例提供点选拖选、双击选词、Ctrl 快捷键、分组撤销与光标水平跟随。 |
