[cui](../../index.md) › [cui.core](index.md) › EventOutcome

# EventOutcome

`cui.core` 包中的 public enum

描述监听器对一次事件施加的两个正交效果：是否已处理、是否停止传播。

```cangjie
public enum EventOutcome {
    | Continue
    | Handled
    | StopPropagation
    | Consume

    public func combined(other: EventOutcome): EventOutcome
}
```

| 值 | 已处理 | 停止传播 | 用途 |
|---|---:|---:|---|
| `Continue` | 否 | 否 | 恒等结果，不改变路由。 |
| `Handled` | 是 | 否 | 阻止落到后方兄弟，但允许当前路径继续到冒泡。 |
| `StopPropagation` | 否 | 是 | 截断当前路径。 |
| `Consume` | 是 | 是 | 已完成处理并立即截断路径。 |

`combined` 对两列做逻辑或，因此以 `Continue` 为恒等元，并满足结合律、交换律和幂等律。多个独立策略可先各自产生结果再安全合并，不需要约定“哪个 Bool 优先”。

## 另请参阅

- [`EventListener`](EventListener.md) — 消费本结果的传播包装。
- [`EventPhase`](EventPhase.md) — 捕获、目标与冒泡阶段。
