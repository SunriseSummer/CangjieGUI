[cui](../../index.md) › [cui.core](index.md) › StateMutationPolicyDiagnostics

# StateMutationPolicyDiagnostics

`cui.core` 包中的 public struct

显式诊断策略在某一时刻的不可变计数快照。它用于判断等价比较是否真正截断了足够多的状态写入或派生失效，以及
比较自身的总耗时和最坏耗时是否值得。普通 [`StateMutationPolicy`](StateMutationPolicy.md) 不维护这些字段。

## 声明

```cangjie
public struct StateMutationPolicyDiagnostics
```

## 属性

| 属性 | 类型 | 说明 |
|---|---|---|
| `comparisons` | `UInt64` | 已开始的比较次数，包含失败比较。 |
| `equivalentResults` | `UInt64` | 返回 `true`、因而可抑制后续变化的次数。 |
| `distinctResults` | `UInt64` | 返回 `false`、应继续传播变化的次数。 |
| `failures` | `UInt64` | 抛出异常的比较次数。 |
| `totalNanoseconds` | `UInt64` | 所有比较（包含失败）的累计墙钟时间。 |
| `maximumNanoseconds` | `UInt64` | 单次比较的最大墙钟时间。 |

一次比较只会落入等价、不同或失败三类之一，因此稳定快照满足
`comparisons == equivalentResults + distinctResults + failures`。纳秒值是运行时诊断而不是硬实时保证，跨机器比较时应以
同一环境下的分布和命中收益为准。

## 另请参阅

- [`DiagnosedStateMutationPolicy`](DiagnosedStateMutationPolicy.md) — 产生并重置此快照的显式包装器。
- [`diagnoseStateMutationPolicy`](functions.md#diagnosestatemutationpolicy) — 创建诊断包装器。
