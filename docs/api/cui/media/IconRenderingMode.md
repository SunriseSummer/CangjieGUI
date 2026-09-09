# IconRenderingMode

位于 `cui.media`，通过 `cui.*` 重导出。

Original 保留媒体 RGB，忽略 foregroundColor；Template 以透明度为覆盖范围，使用前景色替换 RGB。Template 不是乘法 tint：黑色图形也能变成白色或任意主题色。无透明背景的素材在模板模式下会形成实心矩形。两种模式都应用独立 opacity。

```cangjie
public enum IconRenderingMode
```

详见[图标指南](../../../guide/how-to/icons.md)与[图标工坊](../../../../examples/icons/README.md)。

### Original

保留原始颜色。

### Template

透明度模板，跟随前景色。
