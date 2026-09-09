# IconVariant

位于 `cui.media`，通过 `cui.*` 重导出。

应用提供的一个正方形位图规格，pixels 为原始画布边长（物理像素），不是 vp。规格表选择能够满足目标栅格尺寸的最小项；均不足时选择最大项。声明的尺寸须与实际文件匹配。不同逻辑尺寸的光学校正稿应由应用选择，不能仅按 DPI 自动替换。

```cangjie
public struct IconVariant
```

详见[图标指南](../../../guide/how-to/icons.md)与[图标工坊](../../../../examples/icons/README.md)。

### source

```cangjie
public let source: ImageSource
```

### pixels

```cangjie
public let pixels: Int32
```

### init

`pixels` 须为正，否则抛出 `IllegalArgumentException`；构造时不加载图像。

```cangjie
public init(source: ImageSource, pixels: Int32)
```

从文件创建规格；检查边长为正、路径不含 NUL，否则抛出 `IllegalArgumentException`。

```cangjie
public init(path: String, pixels: Int32)
```

