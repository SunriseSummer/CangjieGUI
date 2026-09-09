# IconButton

位于 `cui.media`，通过 `cui.*` 重导出。

用户媒体图标与可选文字组成的按钮。默认 38 vp 最小自然尺寸；图标变大时点击区域随之增长，受父约束时内容裁剪。`iconStyle` 控制图标，`style` 控制按钮表面。纯图标按钮应设置 `accessibilityLabel`；带文字时默认使用文字作为名称。键盘、鼠标与 `.enabled(false)` 使用统一 Button 协议。

```cangjie
public class IconButton <: Widget
```

详见[图标指南](../../../guide/how-to/icons.md)与[图标工坊](../../../../examples/icons/README.md)。

### init

```cangjie
public init(source: IconSource, label!: String = "", role!: ButtonRole = ButtonRole.Normal,
        style!: ?SurfaceStyle = None, iconStyle!: IconStyle = IconStyle(), onClick!: () -> Unit)
```

从文件创建模板图标来源。

```cangjie
public init(path: String, label!: String = "", role!: ButtonRole = ButtonRole.Normal,
        style!: ?SurfaceStyle = None, iconStyle!: IconStyle = IconStyle(), onClick!: () -> Unit)
```

复用已有的不可变图像来源，不复制编码字节。

```cangjie
public init(source: ImageSource, label!: String = "", role!: ButtonRole = ButtonRole.Normal,
        style!: ?SurfaceStyle = None, iconStyle!: IconStyle = IconStyle(), onClick!: () -> Unit)
```

### key

设置跨重建的焦点与按压身份；空键抛出 `IllegalArgumentException`。

```cangjie
public func key(value: String): IconButton
```

### label

设置可见文字；空字符串表示纯图标按钮。

```cangjie
public func label(value: String): IconButton
```

### accessibilityLabel

覆盖无障碍名称，不增加可见文字。

```cangjie
public func accessibilityLabel(value: String): IconButton
```

### role

按按钮角色选择表面和前景色。

```cangjie
public func role(value: ButtonRole): IconButton
```

### style

覆盖按钮表面样式。

```cangjie
public func style(value: SurfaceStyle): IconButton
```

### iconStyle

替换图标外观，保留按钮表面样式。

```cangjie
public func iconStyle(value: IconStyle): IconButton
```

### iconSize

设置有限、非负的图标尺寸；自然点击区域仍保留标准控件的最小尺寸。

```cangjie
public func iconSize(value: Length): IconButton
```

```cangjie
public func iconSize(value: Float32): IconButton
```

### foregroundColor

设置模板图标颜色，不改变文字或原色图标。

```cangjie
public func foregroundColor(value: Color): IconButton
```

### renderingMode

```cangjie
public func renderingMode(value: IconRenderingMode): IconButton
```

### iconOpacity

```cangjie
public func iconOpacity(value: Float32): IconButton
```

### iconGap

设置图标与文字之间有限、非负的间距。

```cangjie
public func iconGap(value: Length): IconButton
```

### fallback

指定主来源解码或上传失败时的备用图标。

```cangjie
public func fallback(value: IconSource): IconButton
```

### status

```cangjie
public func status(): ImageStatus
```

### loadError

```cangjie
public func loadError(): ?String
```

### measure

```cangjie
public func measure(ctx: UiContext, available: Size): Size
```

### layout

```cangjie
public func layout(ctx: UiContext, rect: Rect): Unit
```

### draw

```cangjie
public func draw(ctx: UiContext): Unit
```

### handle

```cangjie
public func handle(ctx: UiContext, event: UiEvent): Bool
```

### pointerEventScope

```cangjie
public func pointerEventScope(): PointerEventScope
```

### focusableId

```cangjie
public func focusableId(): ?String
```

