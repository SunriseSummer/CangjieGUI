[cui](../../index.md) › [cui.text](index.md) › TextInputStyle

# TextInputStyle

TextField／TextArea 共用的编辑器外观。通过 `.style(TextInputStyle(...))` 设置；字体族、字号、字重与倾斜继续使用 `TextStyle` 继承。

## 声明

```cangjie
public struct TextInputStyle
public init(
    lineHeight!: ?Length = None,
    padding!: LengthInsets = LengthInsets(Length(8.0, LengthUnit.Vp)),
    alignment!: TextAlign = TextAlign.Leading,
    textColor!: ?Color = None, placeholderColor!: ?Color = None,
    selectionColor!: ?Color = None, inactiveSelectionColor!: ?Color = None,
    selectedTextColor!: ?Color = None, cursorColor!: ?Color = None,
    cursorWidth!: Length = Length(1.5, LengthUnit.Vp),
    surface!: ?SurfaceStyle = None, focusedSurface!: ?SurfaceStyle = None,
    cursorHeight!: ?Length = None,
    cursorBlinkIntervalMs!: UInt64 = UInt64(530),
    selectionWidth!: TextSelectionWidth = TextSelectionWidth.Content
)
```

以上参数均保存为同名 `public let` 字段。

| 设置 | 行为 |
| --- | --- |
| `lineHeight` | 最小可视行高，包含行间留白；不会低于当前字体的自然行高。显式设置时，文字在行框内居中；光标另按参考墨迹中心对齐，选区覆盖整行高。不是额外叠加的行距。 |
| `padding` | 四边内边距，同时影响文本绘制、点击、光标与视口。TextArea 另保留右缘滚动条通道。 |
| `alignment` | 每一可视行的 Leading／Center／Trailing 对齐；超长行从左侧起排并跟随光标。 |
| `textColor`／`placeholderColor` | 正文与占位提示颜色；默认使用主题正文色／次要文字色。彩色 Emoji 保留字体调色板。 |
| `selectionColor`／`inactiveSelectionColor` | 聚焦／失焦选区背景；默认使用主题强调色／次要文字色的半透明版本。 |
| `selectedTextColor` | 选区内文字颜色；未设置时保留正文色。对选区及两侧分别裁剪整行绘制，保留连字与 shaping，避免重复叠色。 |
| `cursorColor`／`cursorWidth` | 光标和预编辑下划线颜色、光标宽度；默认强调色与 1.5 vp。 |
| `cursorHeight` | 默认采用自然行高，也可指定独立高度；以当前字体稳定参考字形 `国Ag` 的墨迹中心对齐，上下留白对称。高度不超过内视口，不随旁边的单个字符跳动。 |
| `cursorBlinkIntervalMs` | 每个亮／暗阶段的时长，默认 530 ms；`0` 为常亮。正文有选区、窗口失焦或光标在裁剪区外时不闪烁；IME 预编辑光标常亮。 |
| `selectionWidth` | 默认 [`Content`](TextSelectionWidth.md) 只覆盖选中的文本 advance，包括实际空格；单独选中换行符时以窄条显示。`Viewport` 可恢复选中硬换行时延伸到视口右端的效果。 |
| `surface`／`focusedSurface` | 普通／聚焦背景、边框与阴影；聚焦样式未设置时继承普通样式，均未设置时使用主题。 |

长度必须有限；内边距可以为零，行高、光标宽度和显式光标高度必须大于零，否则抛出 `IllegalArgumentException`。`fp` 随字体缩放，`vp` 使用逻辑像素，`px` 随显示密度换算。

默认保持原有布局：TextField 文字在内视口中居中；TextArea 行高为 `max(28, 自然行高 + 4)`，文字位于行顶。TextField 的自然测量高度包含行高与上下内边距；外部强制更小高度时会裁剪，布局应优先采用自然测量或最小高度。

参见[文本编辑指南](../../../guide/how-to/text-editing.md)、[TextField](TextField.md)、[TextArea](TextArea.md)。
