# IconSource

位于 `cui.media`，通过 `cui.*` 重导出。

不可变的应用图标资源定义，包含 ImageSource、原色／模板意图及可选位图规格表。可接收应用资源或 [cui.symbols](../symbols/index.md) 常量提供的源码资源，不负责图标名称查找。默认 Template；品牌等彩色资源显式使用 Original。内存资源只复制一次，在组件重建之外创建并复用。

```cangjie
public struct IconSource
```

详见[图标指南](../../../guide/how-to/icons.md)与[图标工坊](../../../../examples/icons/README.md)。

### image

```cangjie
public let image: ImageSource
```

### renderingMode

```cangjie
public let renderingMode: IconRenderingMode
```

### init

复用图像来源；默认模板模式适合随前景色着色的操作图标。

```cangjie
public init(image: ImageSource, renderingMode!: IconRenderingMode = IconRenderingMode.Template)
```

从文件路径创建来源；路径含 NUL 时抛出 `IllegalArgumentException`。

```cangjie
public init(path: String, renderingMode!: IconRenderingMode = IconRenderingMode.Template)
```

### memory

复制编码字节一次；应在构建函数外创建并复用来源，以保持缓存身份。

```cangjie
public static func memory(bytes: Array<UInt8>, typeHint!: String = "",
        renderingMode!: IconRenderingMode = IconRenderingMode.Template): IconSource
```

### variants

复制规格表并复用图像来源。选择满足目标尺寸的最小规格；全部不足时选最大规格。空表或重复边长抛出 `IllegalArgumentException`。

```cangjie
public static func variants(values: Array<IconVariant>,
        renderingMode!: IconRenderingMode = IconRenderingMode.Template): IconSource
```

### withRenderingMode

返回使用指定颜色模式的新描述，保留图像身份与不可变规格表。

```cangjie
public func withRenderingMode(value: IconRenderingMode): IconSource
```

