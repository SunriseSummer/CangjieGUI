[cui](../../index.md) › [cui.core](index.md) › EffectCleanup

# EffectCleanup

把 cleanup 闭包适配为幂等 `Resource`，便于从 [`mountEffect`](functions.md#mounteffect) 或
[`lifecycleEffect`](functions.md#lifecycleeffect) 返回。

```cangjie
public class EffectCleanup <: Resource {
    public init(action: () -> Unit)
    public func isClosed(): Bool
    public func close(): Unit
}
```

`close` 只在 action 成功后标记关闭；action 抛异常时仍保持可重试，下一次 `close` 会再次执行。

```cangjie
lifecycleEffect("watch-project", project.revision) {
    watcher.start(project.value)
    EffectCleanup({=> watcher.stop()})
}
```
