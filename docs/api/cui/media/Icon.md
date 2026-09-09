# Icon

位于 `cui.media`，通过 `cui.*` 重导出。

用户媒体资源构成的非交互图标。默认 18 vp、居中等比容纳、Template 模板着色。测量不加载，加载失败保持占位；`alt` 非空时提供独立图像语义。资源格式继承 ImageSource，支持文件、内存和显式位图规格。关闭只停用当前视图，不销毁共享纹理。

```cangjie
public class Icon <: Widget & Resource
```

详见[图标指南](../../../guide/how-to/icons.md)与[图标工坊](../../../../examples/icons/README.md)。

### init

```cangjie
public init(source: IconSource, style!: IconStyle = IconStyle())
```

从文件创建模板图标；彩色素材应设置 `renderingMode(IconRenderingMode.Original)`。

```cangjie
public init(path: String, style!: IconStyle = IconStyle())
```

复用已有的不可变图像来源，不复制编码字节。

```cangjie
public init(source: ImageSource, style!: IconStyle = IconStyle())
```

### iconStyle

整体替换图标外观。

```cangjie
public func iconStyle(value: IconStyle): Icon
```

### iconSize

设置有限、非负的正方形尺寸；零尺寸不解码、不绘制图标。

```cangjie
public func iconSize(value: Length): Icon
```

按虚拟像素（vp）设置尺寸。

```cangjie
public func iconSize(value: Float32): Icon
```

### foregroundColor

设置模板前景色；原色来源保留自身 RGB。

```cangjie
public func foregroundColor(value: Color): Icon
```

### renderingMode

改变颜色模式，保留资源身份。

```cangjie
public func renderingMode(value: IconRenderingMode): Icon
```

### iconOpacity

设置 0..1 内的有限透明度，对模板和原色模式均有效。

```cangjie
public func iconOpacity(value: Float32): Icon
```

### fallback

主来源失败时使用指定备用资源，只尝试一层回退。

```cangjie
public func fallback(value: IconSource): Icon
```

### alt

设置独立图标的无障碍名称；空字符串表示装饰性图标。

```cangjie
public func alt(value: String): Icon
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
public func handle(_: UiContext, _: UiEvent): Bool
```

### pointerEventScope

```cangjie
public func pointerEventScope(): PointerEventScope
```

### status

查询主来源的加载状态，不触发 I/O；备用图成功也不改变主来源状态。

```cangjie
public func status(): ImageStatus
```

### loadError

查询主来源的失败诊断，不触发 I/O。

```cangjie
public func loadError(): ?String
```

### isClosed

```cangjie
public func isClosed(): Bool
```

### close

停用当前视图；共享纹理仍由有界缓存管理。

```cangjie
public func close(): Unit
```

