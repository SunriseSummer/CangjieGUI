[cui](../../index.md) › [cui.core](index.md) › RetainedSubtreeStats

# RetainedSubtreeStats

保留边界的累计命中与自动 build 依赖诊断。

```cangjie
public struct RetainedSubtreeStats {
    public let buildHits: UInt64
    public let layoutHits: UInt64
    public let paintHits: UInt64
    public let buildDependencyCount: Int64
    public let buildInvalidations: UInt64
    public let frameSubscriberCount: Int64
    public let measureDependencyCount: Int64
    public let layoutDependencyCount: Int64
    public let paintDependencyCount: Int64
    public let paintCommandCount: Int64
    public let paintEstimatedBytes: UInt64
    public let paintRecordAttempts: UInt64
    public let paintDynamicBypasses: UInt64
    public let paintBypassFrames: UInt64
    public let paintBypassRemaining: Int64
}
```

`buildHits` 表示声明体复用，`layoutHits` 表示相同几何下跳过布局，`paintHits` 表示
`cachePaint: true` 后重放透明绘制命令而不再执行子树 draw。`buildDependencyCount` 是当前 body 实际读取的不同 State
数量；`buildInvalidations` 是该边界由干净转为待重建的累计次数，同一帧/事务内的多次写入会合并。
`frameSubscriberCount` 是边界后代的显式 Frame 回调数；其余三个依赖字段分别给出 measure、layout 与命令缓存
paint 的 State 依赖数。`paintCommandCount` 与 `paintEstimatedBytes` 给出当前 display list 的命令数及保守内存
估算；动态绘制安全检查绕过缓存或尚未录制时为 0。它们用于定位依赖过宽、意外高频重建、动画订阅和过大的
绘制边界，不暴露内部订阅对象。

`paintRecordAttempts` 是累计录制探测次数，`paintDynamicBypasses` 是其中检测到动态协议的次数；
`paintBypassFrames` 是退避期间直接绘制的累计帧数，`paintBypassRemaining` 是距下次探测的剩余绘制帧。动态
区域若 `paintRecordAttempts` 持续接近 `paintBypassFrames`，说明退避被频繁失效，应检查 revision、几何抖动或
paint State 自写；正常稳定动态区域的探测比例会随指数退避下降。
