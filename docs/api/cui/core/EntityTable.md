[cui](../../index.md) › [cui.core](index.md) › EntityTable

# EntityTable

`cui.core` 包中的 public struct

面向正规化应用模型的不可变实体表。实体按唯一业务 ID 访问；一次更新产生新版本并共享所有未修改的目录、page 和
bucket，因此 reducer 失败或历史快照不会看到部分写入。它不提供显示顺序契约；界面顺序应单独保存为 ID 数组或
[`IdentifiedArray`](IdentifiedArray.md)。

```cangjie
public struct EntityTable<ID, Entity>
    where ID <: Hashable & Equatable<ID>
```

## 构造与不变量

```cangjie
public init(entities: Array<Entity>, id!: (Entity) -> ID)
```

构造会快照输入数组；重复 ID 抛出 `IllegalArgumentException`。`updating` 的 transform 改变实体 ID 时同样抛出
`IllegalArgumentException`，transform 自身异常原样传播，源版本保持不变。ID 的 `Hashable` 与 `Equatable` 实现必须
一致；散列碰撞保持正确，但会增加对应 bucket 的线性比较，可用 [`diagnostics`](#diagnostics) 发现。

## 大小与查询

```cangjie
public prop size: Int64
public func isEmpty(): Bool
public func get(id: ID): ?Entity
public func contains(id: ID): Bool
```

查询沿三层 32 路目录定位一个小 bucket，再按相等性处理完整哈希碰撞。相比原生可变 `HashMap`，它为持久快照和结构
共享支付额外读取成本；需要在一帧中反复读取同一实体时，应通过 `ModelStore.select` 建立缓存 selector。

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
- 普通修改只复制顶层区域引用表、一个 region page、一个 bucket page 和目标 bucket。
- 插入越过负载阈值时 O(N) 重建更宽目录；删除不自动缩容，避免高频增删抖动，并保留历史版本共享。

## 批量更新

```cangjie
public func updatingAll(
    updates: Array<EntityUpdate<ID, Entity>>
): ?EntityTable<ID, Entity>
```

按数组顺序原子应用全部补丁。相同 ID 的后续变换读取前一个结果；任一 ID 缺失时返回 `None`，变换自身异常原样
传播，ID 改变时抛出 `IllegalArgumentException`。所有情况下调用者持有的源版本都不变，也不会得到部分结果。
空数组返回当前版本。实现会根据批次
大小在逐次路径复制和不可逃逸的内部批会话之间自适应；较大批次只复制一次顶层目录，并用与 32 路目录同构的位图
保证每个触及的 region、page 和 bucket 最多复制一次。

## 快照

```cangjie
public func toArray(): Array<Entity>
```

返回隔离数组，但顺序只是当前 hash bucket 遍历顺序，扩容后可以改变，不能用作业务或显示身份。

## diagnostics

```cangjie
public func diagnostics(): EntityTableStats
```

返回实体数、逻辑 bucket 数、占用 bucket、最大碰撞 bucket 和顶层 region 数，不复制实体。较大的
`maxBucketSize` 表明 ID hash 低位分布较差或存在恶意碰撞。

## 另请参阅

- [`EntityTableStats`](EntityTableStats.md) — 哈希目录诊断。
- [`EntityUpdate`](EntityUpdate.md) — ID 与实体自变换组成的有序批补丁。
- [`Reducer.forEntity`](Reducer.md#forentity) — 按 ID 组合实体 reducer。
- [`IdentifiedArray`](IdentifiedArray.md) — 同时需要稳定显示顺序的重复 UI 特征。
