[cui](../../index.md) › [cui.core](index.md) › RetainedGraphDiagnostics

# RetainedGraphDiagnostics

一次已提交 retained 执行图的确定性快照。

```cangjie
public class RetainedGraphDiagnostics {
    public let scopes: Array<RetainedScopeDiagnostics>
    public let automaticScopes: Array<AutomaticScopeDiagnostics>
    public let activeEffectCount: Int64
    public let failedEffectCleanupCount: Int64
    public let fullDamagePending: Bool
    public let pendingDamage: ?Rect
    public func describe(): String
}
```

`scopes` 总是以 root 开头，其余项按可读路径稳定排序；`automaticScopes` 是框架自动建立的声明体
作用域，按路径稳定排序，可查看自身脏/后代脏、依赖和跳过次数。`activeEffectCount` 是当前挂载的 effect 数，
`failedEffectCleanupCount` 是 cleanup 抛错后仍保留等待重试的 Resource 数。`describe` 生成稳定多行文本，适合
日志、golden 断言和缺陷报告；每个 scope 行还包含命令数/估算字节。`fullDamagePending` 表示下一次状态驱动帧
必须全绘，`pendingDamage` 是尚未消费的局部矩形；两者均无待处理项时为 false/None。自动化分析应优先读取
结构化字段。

快照可从 [`DesktopApp.retainedDiagnostics`](../desktop/DesktopApp.md#retaineddiagnostics) 或
[`WidgetTestHost.retainedDiagnostics`](../testing/WidgetTestHost.md) 获取。
