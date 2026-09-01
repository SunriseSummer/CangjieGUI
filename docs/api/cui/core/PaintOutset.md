[cui](../../index.md) › [cui.core](index.md) › PaintOutset

# PaintOutset

布局矩形之外的保守绘制溢出，单位为逻辑像素。四个方向在构造时收敛到非负值；`join` 逐分量取最大值，满足
结合、交换和幂等，因此容器可按任意遍历分组安全聚合阴影、焦点环和自定义 Canvas 效果。

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

它只声明绘制域，不改变 `measure` 或 `layout`。内建 shadow/surface/focus ring 会自动产生声明；自定义绘制可覆盖
[`Widget.paintOutset()`](Widget.md#paintoutset)，或用 `.paintOutset(...)` 包装。滚动容器仅在非滚动轴保留声明的
overflow，滚动轴始终按 viewport 精确裁剪；ScenePatch、damage 与 lazy item clip 消费同一个值。

```cangjie
CanvasWidget({renderer, rect =>
    drawGlow(renderer, rect)
}).paintOutset(PaintOutset(left: 32.0, right: 32.0))
```
