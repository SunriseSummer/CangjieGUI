# cui.symbols.arrow_right 公开值

### ICON_ARROW_RIGHT

```cangjie
public let ICON_ARROW_RIGHT: IconSource
```

共享的向右图标：24 × 24 坐标，透明背景、1.75 单位圆头描边，默认 `IconRenderingMode.Template`。
包初始化时创建一次不可变资源描述，不读取文件、不解码或创建纹理。后续读取保持同一资源身份，不复制 SVG 字节。
`let` 禁止重新赋值；这是一次初始化的运行时资源，不是仓颉编译期 `const`。

导入路径为 `cui.symbols.arrow_right.ICON_ARROW_RIGHT`。将值直接传给 Icon、IconButton、RichSpan、TreeNode 或 paintIcon，无需括号。
通过组件设置尺寸、颜色、透明度和镜像；`withRenderingMode` 返回派生描述，不修改此全局值。
GPU 纹理由原有按 UI 线程隔离的有界缓存管理。

本包不经 `cui.*` 或 `cui.symbols.*` 全量再导出，见[链接边界与用法](../../../../guide/how-to/preset-icons.md)。
