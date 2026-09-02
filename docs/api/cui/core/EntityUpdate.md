[cui](../../index.md) › [cui.core](index.md) › EntityUpdate

# EntityUpdate

位于 `cui.core` 包的公开结构体

把一个实体 ID 与其纯自变换配对，作为 [`EntityTable.updatingAll`](EntityTable.md#批量更新) 的可复用有序补丁。

```cangjie
public struct EntityUpdate<ID, Entity> {
    public let id: ID
    public init(id: ID, transform!: (Entity) -> Entity)
    public func apply(entity: Entity): Entity
}
```

`transform` 应是无外部副作用的确定性函数，且必须保留实体 ID。一个批次内相同 ID 可以出现多次；后一个变换读取
前一个变换的结果，因此顺序是语义的一部分。

同一实体可以在一个数组中连续出现多次，例如先重命名再标记完成；把该数组传给 `table.updatingAll` 后，第二个变换会读取
第一个变换的结果。

## 另请参阅

- [`EntityTable`](EntityTable.md) — 应用单个或有序批量实体补丁。
- [`IdentifiedAction`](IdentifiedAction.md) — reducer 路由使用的 ID 与 Action 值对。
