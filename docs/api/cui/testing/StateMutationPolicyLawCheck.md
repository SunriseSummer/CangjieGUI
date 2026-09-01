[cui](../../index.md) › [cui.testing](index.md) › StateMutationPolicyLawCheck

# StateMutationPolicyLawCheck

`cui.testing` 包中的 public struct

一个策略在三个具体值上的重复性和等价关系定律检查结果。它用于发现会错误吞掉状态、破坏事务端点商映射或让
selector 失效不稳定的自定义策略。

## 声明

```cangjie
public struct StateMutationPolicyLawCheck
```

## 属性

| 属性 | 类型 | 说明 |
|---|---|---|
| `deterministic` | `Bool` | 三值上的九个有序比较重复执行后结果相同。 |
| `reflexive` | `Bool` | 三个值都与自身等价。 |
| `symmetric` | `Bool` | 三对不同值的正反比较相同。 |
| `transitive` | `Bool` | 缓存的三值关系矩阵满足全部 27 个传递蕴含。 |

### isLawful

```cangjie
public func isLawful(): Bool
```

仅当四个结果都为 `true` 时返回 `true`。

有限值集只能提供反例而非普遍证明；应选取相等、不同、边界和会触发领域分支的代表值，或在属性测试生成器中重复
调用。策略比较抛出的异常不会被转换成失败布尔值，而是原样传播。

## 另请参阅

- [`checkStateMutationPolicyLaws`](functions.md#checkstatemutationpolicylaws) — 产生此结果。
- [`StateMutationPolicy`](../core/StateMutationPolicy.md) — 被检查的观察等价关系。
