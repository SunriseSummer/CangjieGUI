[cui](../../index.md) › [cui.core](index.md) › IdentifiedArray

# IdentifiedArray

`cui.core` 包中的 public struct

同时保存稳定 ID、显示顺序和不可变版本的 keyed 集合。它面向重复子特征 reducer 与 keyed UI：位置可以因排序、
插入或删除改变，Action 始终按业务 ID 路由。

```cangjie
public struct IdentifiedArray<ID, Element>
    where ID <: Hashable & Equatable<ID>
```

## 构造

```cangjie
public init(elements: Array<Element>, id!: (Element) -> ID)
```

构造时快照输入数组并验证 ID 唯一；重复 ID 抛 `IllegalArgumentException`。元素本身应采用不可变值模型，框架不会
深复制任意引用对象。

内部顺序存储是 32 元素分块持久向量。超过 32 项时保留 ID→位置 HashMap；小集合只保留分块并线性匹配，避免长期
支付索引对象。单元素替换共享未改变块和只读索引，只复制外层块表及一个块。

## 读取

```cangjie
public prop size: Int64
public func isEmpty(): Bool
public func at(index: Int64): Element
public func get(id: ID): ?Element
public func indexOf(id: ID): ?Int64
public func toArray(): Array<Element>
```

`at` 为 O(1)；超过 32 项的 ID 查找期望 O(1)，小集合最多扫描 32 项。`toArray` 返回隔离的顺序快照并为 O(N)。

## 持久修改

```cangjie
public func updating(
    id: ID,
    transform: (Element) -> Element
): ?IdentifiedArray<ID, Element>

public func appending(element: Element): IdentifiedArray<ID, Element>
public func removing(id: ID): ?IdentifiedArray<ID, Element>
```

`updating` 在 ID 缺失时返回 `None`；transform 抛异常时不分配新块，原版本保持可用。返回元素的 ID 必须仍等于目标
ID，否则抛 `IllegalArgumentException`。更新复制约 `N/32 + 32` 个引用；append/remove 会改变结构或索引，当前为
O(N)。原集合始终保持不变。

一个领域 Action 要按序更新多个稳定 ID 时，使用 [`identifiedBatchReducer`](functions.md#identifiedbatchreducer) 或
父级 [`Reducer.forEachBatch`](Reducer.md#foreachbatch)。批次不改变集合结构和显示顺序，因此复用同一个 ID→位置索引，
只复制一次外层 chunk 表和每个触及 chunk；调用者无需管理可变 builder。

```cangjie
let rows = IdentifiedArray<RowId, Row>(source, id: {row => row.id})
let next = rows.updating(targetId, {row => row.renamed("新名称")}).getOrThrow()
```

## 另请参阅

- [`IdentifiedAction`](IdentifiedAction.md) — 按 ID 路由到元素的 Action。
- [`EntityTable`](EntityTable.md) — 不需要显示顺序的正规化持久实体表。
- [`Reducer`](Reducer.md#foreach) — 子先于父的 keyed reducer 组合。
- [`MissingFeaturePolicy`](MissingFeaturePolicy.md) — Action 找不到目标时的显式策略。
