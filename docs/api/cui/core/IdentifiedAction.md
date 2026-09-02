[cui](../../index.md) › [cui.core](index.md) › IdentifiedAction

# IdentifiedAction

位于 `cui.core` 包的公开结构体

把局部 Action 与目标元素或实体的稳定 ID 配对。位置索引不是身份，列表重排或关系重组后同一 Action 仍命中同一
业务对象。

```cangjie
public struct IdentifiedAction<ID, Action> {
    public let id: ID
    public let action: Action
    public init(id: ID, action: Action)
}
```

它由 [`identifiedReducer`](functions.md#identifiedreducer)、[`entityReducer`](functions.md#entityreducer) 和父 reducer
的 [`forEach`](Reducer.md#foreach)/[`forEntity`](Reducer.md#forentity) 解释。

## 另请参阅

- [`IdentifiedArray`](IdentifiedArray.md) — 保持顺序与唯一 ID 索引的持久集合。
- [`EntityTable`](EntityTable.md) — 按业务 ID 存储的不可变实体表。
- [`MissingFeaturePolicy`](MissingFeaturePolicy.md) — ID 已不存在时拒绝或忽略。
