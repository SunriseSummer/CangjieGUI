[cui](../../index.md) › [cui.testing](index.md) › TestFrameMetrics

# TestFrameMetrics

```cangjie
public struct TestFrameMetrics {
    public let buildNs: UInt64
    public let layoutNs: UInt64
    public let eventNs: UInt64
    public let semanticsNs: UInt64
    public let drawNs: UInt64
    public let stabilizationPasses: Int64
    public let textMeasures: UInt64
    public let textComputes: UInt64
    public let textDraws: UInt64
    public let frameSubscribers: Int64
    public let overlayCount: Int64
    public func totalNs(): UInt64
}
```

`buildNs`、`layoutNs`、`eventNs`、`semanticsNs` 和 `drawNs` 分别记录构建、布局、事件、无障碍信息提交和绘制耗时。
这些纳秒字段适合相同机器、相同构建配置下的 A/B；计数用于定位原因，不应用单次绝对值做跨机器门禁。
`frameSubscribers` 是稳定构建显式登记的逐帧回调数量；静态树应接近 0，永久增长通常表示错误挂载了轮询或动画。

## 构造函数

```cangjie
public init(
    buildNs: UInt64, layoutNs: UInt64, eventNs: UInt64, drawNs: UInt64,
    stabilizationPasses: Int64, textMeasures: UInt64, textComputes: UInt64,
    textDraws: UInt64, overlayCount: Int64
)
public init(
    buildNs: UInt64, layoutNs: UInt64, eventNs: UInt64, drawNs: UInt64,
    stabilizationPasses: Int64, textMeasures: UInt64, textComputes: UInt64,
    textDraws: UInt64, frameSubscribers: Int64, overlayCount: Int64
)
public init(
    buildNs: UInt64, layoutNs: UInt64, eventNs: UInt64, semanticsNs: UInt64,
    drawNs: UInt64, stabilizationPasses: Int64, textMeasures: UInt64,
    textComputes: UInt64, textDraws: UInt64, frameSubscribers: Int64,
    overlayCount: Int64
)
```

前两个重载把 `semanticsNs` 设为 0；第一个重载还把 `frameSubscribers` 设为 0。
