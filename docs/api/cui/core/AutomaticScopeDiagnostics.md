[cui](../../index.md) › [cui.core](index.md) › AutomaticScopeDiagnostics

# AutomaticScopeDiagnostics

框架自动组合作用域的一行不可变诊断。普通 UI 不需要创建或配置该类型；它只用于性能工具、测试和
缺陷报告。

```cangjie
public struct AutomaticScopeDiagnostics {
    public let identity: String
    public let path: String
    public let depth: Int64
    public let stateCount: Int64
    public let effectCount: Int64
    public let retainedChildCount: Int64
    public let automaticChildCount: Int64
    public let buildDirty: Bool
    public let selfDirty: Bool
    public let descendantDirty: Bool
    public let buildDependencyCount: Int64
    public let buildInvalidations: UInt64
    public let buildHits: UInt64
    public let renderNodeCount: Int64
    public let layoutHits: UInt64
    public let paintHits: UInt64
    public let paintRecordAttempts: UInt64
    public let paintDynamicBypasses: UInt64
    public let paintRejectedCandidates: UInt64
    public let paintBudgetEvictions: UInt64
    public let paintCommandCount: Int64
    public let paintEstimatedBytes: UInt64
    public let paintBypassRemaining: Int64
    public let sceneRevision: UInt64
    public let lastInvalidationReason: String
}
```

`selfDirty` 表示作用域自己读取的 `State` 已变化，框架会保守刷新其自动后代以更新闭包捕获；
`descendantDirty` 表示这里只是通往脏后代的祖先路径，干净兄弟 body 可以复用。`buildHits` 是该
身份成功跳过 body 的累计次数。`buildDependencyCount` 统计已提交的直接响应式边；一个稳定派生节点计为 1，
不等于它传递依赖的 State 总数。字段属于诊断契约，不应参与应用业务判断。

`renderNodeCount` 大于 0 表示该作用域被框架选为持久渲染边界；`layoutHits` / `paintHits` 分别记录
布局与显示列表复用。`paintRecordAttempts` 是自动录制探测次数，`paintDynamicBypasses` 表示
hover/focus/IME/续帧等动态协议使候选旁路，`paintRejectedCandidates` 表示候选过小、过大、阶段失效
或预算不足。`paintBudgetEvictions` 记录 32 MiB 应用级 LRU 淘汰；`paintCommandCount` /
`paintEstimatedBytes` 是当前仍持有的命令规模，`paintBypassRemaining` 是下次重探前剩余的直绘帧。
`sceneRevision` 汇总该作用域 Element 所有的场景节点内容/几何代数，可用于确认局部 patch 是否实际提交；它不
承诺每次变化只增加一，因为一个提交可能同时更新边界和命令槽。
这些计数用于确认框架策略和定位异常抖动，不是让业务代码反向控制优化器的开关。

由 [`RetainedGraphDiagnostics.automaticScopes`](RetainedGraphDiagnostics.md) 返回。
