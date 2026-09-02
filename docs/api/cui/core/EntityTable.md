[cui](../../index.md) › [cui.core](index.md) › EntityTable

# EntityTable

位于 `cui.core` 包的公开结构体

按唯一业务 ID 存储实体的不可变表。每次修改返回新表，并与旧表共享未修改的数据；原表和已有快照不会发生变化。
它不保证遍历或显示顺序；界面顺序应单独保存为 ID 数组或
[`IdentifiedArray`](IdentifiedArray.md)。

```cangjie
public struct EntityTable<ID, Entity>
    where ID <: Hashable & Equatable<ID>
```

## 构造与不变量

```cangjie
public init(entities: Array<Entity>, id!: (Entity) -> ID)
```

构造时会复制输入数组；重复 ID 抛出 `IllegalArgumentException`。`updating` 的 transform 改变实体 ID 时同样抛出
`IllegalArgumentException`，transform 自身异常原样传播，源版本保持不变。ID 的 `Hashable` 与 `Equatable` 实现必须
一致；散列碰撞不影响结果，但会增加查询比较次数，可用 [`diagnostics`](#diagnostics) 发现。

## 大小与查询

```cangjie
public prop size: Int64
public func isEmpty(): Bool
public func get(id: ID): ?Entity
public func contains(id: ID): Bool
```

相比原生可变 `HashMap`，该类型为不可变快照和数据共享支付少量额外读取成本。若界面在一帧中反复读取同一实体，
可通过 `ModelStore.select` 建立缓存选择器。

## 持久修改

```cangjie
public func updating(
    id: ID,
    transform: (Entity) -> Entity
): ?EntityTable<ID, Entity>

public func updating(
    update: EntityUpdate<ID, Entity>
): ?EntityTable<ID, Entity>

public func inserting(entity: Entity): EntityTable<ID, Entity>
public func setting(entity: Entity): EntityTable<ID, Entity>
public func removing(id: ID): ?EntityTable<ID, Entity>
```

- `updating`/`removing` 在 ID 缺失时返回 `None`；旧版本保持不变。
- `inserting` 遇到重复 ID 时抛出 `IllegalArgumentException`；`setting` 表达插入或替换。
- 普通修改只复制到目标实体的索引路径，其余数据继续共享。
- 插入越过负载阈值时 O(N) 重建更宽目录；删除不自动缩容，避免高频增删抖动，并保留历史版本共享。

## 批量更新

```cangjie
public func updatingAll(
    updates: Array<EntityUpdate<ID, Entity>>
): ?EntityTable<ID, Entity>
```

按数组顺序原子应用全部补丁。相同 ID 的后续变换读取前一个结果；任一 ID 缺失时返回 `None`，变换自身异常原样
传播，ID 改变时抛出 `IllegalArgumentException`。所有情况下调用者持有的源版本都不变，也不会得到部分结果。
空数组返回当前版本。实现会根据批次大小选择更新方式，避免较大批次重复复制相同的内部索引节点。

## 快照

```cangjie
public func toArray(): Array<Entity>
```

返回隔离数组，但顺序只是当前 hash bucket 遍历顺序，扩容后可以改变，不能用作业务或显示身份。

## diagnostics

```cangjie
public func diagnostics(): EntityTableStats
```

返回实体数、散列表容量与占用情况、最大碰撞组和顶层区域数，不复制实体。较大的 `maxBucketSize` 表明 ID 的散列分布
较差或输入中存在大量碰撞。

## 另请参阅

- [`EntityTableStats`](EntityTableStats.md) — 哈希目录诊断。
- [`EntityUpdate`](EntityUpdate.md) — ID 与实体自变换组成的有序批补丁。
- [`Reducer.forEntity`](Reducer.md#forentity) — 按 ID 组合实体 reducer。
- [`IdentifiedArray`](IdentifiedArray.md) — 同时需要稳定显示顺序的重复 UI 特征。
