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

典型用法是在 `lifecycleEffect` 的 setup 中启动监听器，并返回 `EffectCleanup({=> watcher.stop()})`；版本变化或组件
卸载时，框架会调用清理函数。
