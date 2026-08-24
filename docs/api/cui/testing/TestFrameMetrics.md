[cui](../../index.md) › [cui.testing](index.md) › TestFrameMetrics

# TestFrameMetrics

```cangjie
public struct TestFrameMetrics {
    public let buildNs: UInt64
    public let layoutNs: UInt64
    public let eventNs: UInt64
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

纳秒字段适合相同机器/构建配置下的 A/B；计数探针用于定位原因，不应用单次绝对值做跨机器门禁。
`frameSubscribers` 是稳定构建显式登记的逐帧回调数量；静态树应接近 0，永久增长通常表示错误挂载了轮询或动画。
