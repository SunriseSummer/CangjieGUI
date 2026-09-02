[cui](../../index.md) › [cui.core](index.md) › EntityTableStats

# EntityTableStats

位于 `cui.core` 包的公开结构体

[`EntityTable`](EntityTable.md) 的确定性结构诊断，不包含实体值。

```cangjie
public struct EntityTableStats {
    public let entities: Int64
    public let buckets: Int64
    public let occupiedBuckets: Int64
    public let maxBucketSize: Int64
    public let regions: Int64
}
```

| 字段 | 含义 |
|---|---|
| `entities` | 当前实体数。 |
| `buckets` | 2 的幂逻辑 bucket 数，包括空 bucket。 |
| `occupiedBuckets` | 至少含一个实体的 bucket 数。 |
| `maxBucketSize` | 最大完整哈希碰撞链长度。 |
| `regions` | 更新时需要复制的顶层目录引用数。 |

连续增删后 `buckets` 可以高于当前实体需求，因为删除刻意不触发 O(N) 缩容。需要释放容量时可从 `toArray()` 显式重建
表；这应是低频维护动作，而不是 reducer 热路径。
