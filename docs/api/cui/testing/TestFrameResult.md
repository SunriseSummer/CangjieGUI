[cui](../../index.md) › [cui.testing](index.md) › TestFrameResult

# TestFrameResult

```cangjie
public class TestFrameResult {
    public let widget: Widget
    public let metrics: TestFrameMetrics
    public let schedule: FrameSchedule
    public init(widget: Widget, metrics: TestFrameMetrics, schedule: FrameSchedule)
}
```

`widget` 是事件状态已反映后的稳定树；`metrics` 是这一帧的阶段和诊断数据；`schedule` 是当帧组件
请求的立即/最早截止计划。稳定化达到三次上限仍有构建副作用时，`schedule.immediate` 为 `true`。
