[cui](../../index.md) › [cui.core](index.md) › RetainedScopeDiagnostics

# RetainedScopeDiagnostics

retained 执行图中一个 root 或边界的不可变诊断行。

```cangjie
public struct RetainedScopeDiagnostics {
    public let identity: String
    public let path: String
    public let depth: Int64
    public let bounds: Rect
    public let stateCount: Int64
    public let effectCount: Int64
    public let retainedChildCount: Int64
    public let buildDirty: Bool
    public let measureDirty: Bool
    public let layoutDirty: Bool
    public let paintDirty: Bool
    public let lastInvalidationReason: String
    public let stats: RetainedSubtreeStats
}
```

`identity` 是无歧义的内部键编码，`path` 是面向人的 `outer / inner` 路径，`depth` 从 root 的 0 开始；
`bounds` 是最近一次成功布局的逻辑矩形，也是局部 damage 的基础范围（实际清理会为内置阴影留出余量）。
四个 dirty 字段表示下一次相应阶段不能命中；`lastInvalidationReason` 区分本 scope State、后代传播和结构替换。
状态/effect/子边界数量只统计直接所有权，避免把后代重复计入父项；详细依赖和命中数见 `stats`。
