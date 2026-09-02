[cui](../../index.md) › [cui.core](index.md) › PaintOutset

# PaintOutset

声明组件在布局矩形之外额外绘制的范围，单位为逻辑像素。四个方向的负值会转为 0；`join` 分别取各方向最大值，
容器可用它合并阴影、焦点环和自定义 Canvas 的额外范围。

```cangjie
public struct PaintOutset {
    public let left: Float32
    public let top: Float32
    public let right: Float32
    public let bottom: Float32

    public init(left!: Float32 = 0.0, top!: Float32 = 0.0,
        right!: Float32 = 0.0, bottom!: Float32 = 0.0)
    public static func all(value: Float32): PaintOutset
    public func join(other: PaintOutset): PaintOutset
    public func expand(bounds: Rect): Rect
}
```

它只声明绘制范围，不改变 `measure` 或 `layout`。内置阴影、表面和焦点环会自动声明；自定义绘制可覆盖
[`Widget.paintOutset()`](Widget.md#paintoutset)，或用 `.paintOutset(...)` 包装。滚动容器在滚动方向仍按可视区域裁剪，
只在另一个方向保留额外绘制范围。局部重绘和惰性列表裁剪也使用这个值。

例如，自定义光晕在左右各超出布局区域 32 像素时，应给 `CanvasWidget` 应用
`.paintOutset(PaintOutset(left: 32.0, right: 32.0))`。
