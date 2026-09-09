# IconStyle

位于 `cui.media`，通过 `cui.*` 重导出。

不可变的图标样式，可在 Icon 与 IconButton 之间复用。size 为逻辑尺寸，color 只影响 Template；opacity 对两种颜色模式均有效。默认线性采样，像素画选 Nearest；flip 控制镜像。背景、边框、圆角使用容器／按钮样式。

```cangjie
public struct IconStyle
```

详见[图标指南](../../../guide/how-to/icons.md)与[图标工坊](../../../../examples/icons/README.md)。

### size

```cangjie
public let size: Length
```

### color

```cangjie
public let color: ?Color
```

### opacity

```cangjie
public let opacity: Float32
```

### sampling

```cangjie
public let sampling: TextureScaleMode
```

### flip

```cangjie
public let flip: TextureFlip
```

### init

默认尺寸 18 vp，颜色继承主题且只影响模板模式。尺寸非有限或为负、透明度非有限或不在 0..1 内时，抛出 `IllegalArgumentException`。

```cangjie
public init(size!: Length = Length(18.0, LengthUnit.Vp), color!: ?Color = None,
        opacity!: Float32 = 1.0, sampling!: TextureScaleMode = TextureScaleMode.Linear,
        flip!: TextureFlip = TextureFlip.None)
```

