[cui.core](index.md) › FrameSchedule

# FrameSchedule

```cangjie
public class FrameSchedule {
    public let immediate: Bool
    public let deadlineMs: ?UInt64
    public init(immediate!: Bool, deadlineMs!: ?UInt64)
    public func isDue(elapsedMs: UInt64): Bool
    public func hasPending(): Bool
}
```

组件请求的下一帧计划快照。它同时表达“尽快绘制”和“到某个 SDL 单调时钟时刻再绘制”，供自定义宿主像 [`DesktopApp`](../desktop/DesktopApp.md) 一样进入事件等待，而不是空闲轮询。

常规组件只需调用 [`UiContext.requestFrame`](UiContext.md) 或 `requestFrameAt`；`FrameSchedule` 主要是宿主扩展接口。

## 属性

- `immediate: Bool`：是否存在立即帧请求。
- `deadlineMs: ?UInt64`：最早的绝对截止时刻；`None` 表示没有定时请求。

## 方法

`isDue` 判断计划在给定时刻是否到期；`hasPending` 判断是否存在任一种请求。
