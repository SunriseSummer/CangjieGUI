[cui](../../index.md) › [cui.testing](index.md) › LensLawCheck

# LensLawCheck

位于 `cui.testing` 包的公开结构体

一个具体源值和两个焦点值上的 Lens 三定律检查结果。有限样本不能证明所有输入上的定律，但能把模型测试中的
Get-Put、Put-Get 与 Put-Put 义务变成统一、可定位的可执行反例。

## 声明

```cangjie
public struct LensLawCheck
```

## 属性

| 属性 | 类型 | 说明 |
|---|---|---|
| `getPut` | `Bool` | `set(source, get(source)) == source`。 |
| `putGet` | `Bool` | 两个候选焦点都满足 `get(set(source, value)) == value`。 |
| `putPut` | `Bool` | 连续写入两个焦点等于只写最后一个焦点。 |

### isLawful

```cangjie
public func isLawful(): Bool
```

仅当三个结果都为 `true` 时返回 `true`。

## 另请参阅

- [`checkLensLaws`](functions.md#checklenslaws) — 产生此结果。
- [`Lens`](../core/Lens.md) — 被检查的双向投影。
