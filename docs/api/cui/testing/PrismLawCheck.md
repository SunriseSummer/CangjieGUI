[cui](../../index.md) › [cui.testing](index.md) › PrismLawCheck

# PrismLawCheck

`cui.testing` 包中的 public struct

一个和类型源值与一个局部 payload 上的 Prism 往返律检查结果。

## 声明

```cangjie
public struct PrismLawCheck
```

## 属性

| 属性 | 类型 | 说明 |
|---|---|---|
| `extractAfterEmbed` | `Bool` | 嵌入 payload 后必须能提取回同一 payload。 |
| `embedAfterExtract` | `Bool` | 源属于目标 case 时，提取再嵌入必须还原源；未命中时为真空成立。 |

### isLawful

```cangjie
public func isLawful(): Bool
```

仅当两个往返结果都为 `true` 时返回 `true`。

## 另请参阅

- [`checkPrismLaws`](functions.md#checkprismlaws) — 产生此结果。
- [`Prism`](../core/Prism.md) — 被检查的和类型光学投影。
