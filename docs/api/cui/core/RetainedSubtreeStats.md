[cui](../../index.md) › [cui.core](index.md) › RetainedSubtreeStats

# RetainedSubtreeStats

`RetainedSubtree` 的累计命中、状态依赖和绘制缓存诊断。

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

## 构造函数

```cangjie
public init(buildHits: UInt64, layoutHits: UInt64, paintHits: UInt64)
public init(
    buildHits: UInt64,
    layoutHits: UInt64,
    paintHits: UInt64,
    buildDependencyCount: Int64,
    buildInvalidations: UInt64
)
public init(
    buildHits: UInt64,
    layoutHits: UInt64,
    paintHits: UInt64,
    buildDependencyCount: Int64,
    buildInvalidations: UInt64,
    measureDependencyCount: Int64,
    layoutDependencyCount: Int64,
    paintDependencyCount: Int64
)
public init(
    buildHits: UInt64,
    layoutHits: UInt64,
    paintHits: UInt64,
    buildDependencyCount: Int64,
    buildInvalidations: UInt64,
    frameSubscriberCount: Int64,
    measureDependencyCount: Int64,
    layoutDependencyCount: Int64,
    paintDependencyCount: Int64,
    paintCommandCount!: Int64 = 0,
    paintEstimatedBytes!: UInt64 = UInt64(0),
    paintRecordAttempts!: UInt64 = UInt64(0),
    paintDynamicBypasses!: UInt64 = UInt64(0),
    paintBypassFrames!: UInt64 = UInt64(0),
    paintBypassRemaining!: Int64 = 0
)
```

## 字段说明

| 字段 | 说明 |
|---|---|
| `buildHits` | 复用上次子树、跳过 `body` 的次数。 |
| `layoutHits` | 布局条件相同，跳过布局的次数。 |
| `paintHits` | 重放缓存绘制命令、跳过子树 `draw` 的次数。 |
| `buildDependencyCount` | 当前 `body` 直接依赖的状态数；一个 `DerivedState` 记为一个依赖。 |
| `buildInvalidations` | 边界从稳定变为需要重建的累计次数；同一事务的多次写入会合并。 |
| `frameSubscriberCount` | 后代显式注册的逐帧回调数。 |
| `measureDependencyCount` | 测量阶段读取的状态数。 |
| `layoutDependencyCount` | 布局阶段读取的状态数。 |
| `paintDependencyCount` | 记录绘制命令时读取的状态数。 |
| `paintCommandCount` | 当前缓存中的绘制命令数；未记录或暂时绕过缓存时为 0。 |
| `paintEstimatedBytes` | 当前绘制命令的估算内存占用。 |
| `paintRecordAttempts` | 尝试记录绘制命令的累计次数。 |
| `paintDynamicBypasses` | 因检测到动态绘制能力而放弃记录的次数。 |
| `paintBypassFrames` | 暂时直接绘制、不尝试记录的累计帧数。 |
| `paintBypassRemaining` | 距离下次尝试记录还剩多少帧。 |

如果记录尝试一直很频繁，应检查 `revision` 是否每帧变化、布局区域是否抖动，或绘制阶段是否修改了自己的状态。
