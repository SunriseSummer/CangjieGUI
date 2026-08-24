[cui](../../index.md) › [cui.testing](index.md) › RetainedTestMode

# RetainedTestMode

```cangjie
public enum RetainedTestMode {
    | Incremental
    | Full
}
```

[`WidgetTestHost`](WidgetTestHost.md) 的 retained 执行策略。`Incremental` 是生产路径：依赖未变化时允许
命中 build、layout 与可选 paint 缓存。`Full` 是确定性差分诊断路径：每帧重新执行 retained 边界，便于
发现漏记依赖造成的陈旧界面；它不改变事件事务和帧调度语义，也不应作为性能基准模式。
