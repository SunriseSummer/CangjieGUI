[cui](../../index.md) › [cui.core](index.md) › LazyViewportController

# LazyViewportController

位于 `cui.core` 包的公开类

惰性视口的外部滚动控制器。持有可观察偏移，并能按当前索引或稳定 key 显示条目而无需调用方知道累计高度。控制器应放在应用模型或 `rememberState` 之外的稳定对象中，不要每帧重建。

## 声明

```cangjie
public class LazyViewportController
```

## 构造函数

```cangjie
public init(initialOffset!: Float32 = 0.0)
```

负偏移按 0 处理。一个控制器同一时刻应只连接一个同轴惰性视口。

## 属性与方法

### offset

```cangjie
public prop offset: Float32
```

当前逻辑像素偏移，只读快照。

### state

```cangjie
public func state(): State<Float32>
```

返回控制器持有的可观察偏移，供动画、联动或诊断读取。

### jumpTo

```cangjie
public func jumpTo(offset: Float32): Unit
```

跳到绝对偏移；惰性视口在布局时按内容范围裁剪。

该调用会取消尚未处理的 key/index 请求，并立即把 `lastTargetFound` 恢复为 `true`；取消不会构造 key 索引。

### scrollToIndex

```cangjie
public func scrollToIndex(
    index: Int64,
    alignment!: LazyScrollAlignment = LazyScrollAlignment.Nearest
): Unit
```

请求下一帧显示当前结构中的第 `index` 项。固定 extent 列表为 O(1) 定位，变高列表由 extent 前缀索引 O(log N)
定位；两者都不会为查找目标而扫描全部 key。负索引立即抛出 `IllegalArgumentException`；超出当前条目数的索引由
已挂载视口处理，并令 `lastTargetFound` 为 `false`。

索引表示“当前槽位”而非业务身份：若请求与处理之间可能插入、删除或重排，应使用 `scrollToKey`；若搜索、分页或
表格模型已经得到当前索引，直接使用本方法，避免把索引转成 key 后再构造反向表。

### scrollToKey

```cangjie
public func scrollToKey(
    key: String,
    alignment!: LazyScrollAlignment = LazyScrollAlignment.Nearest
): Unit
```

请求下一帧显示稳定 key。请求状态本身可观察，因此已挂载视口会自动获帧。空 key 抛出 `IllegalArgumentException`。
同一结构版本第一次按 key 请求会 O(N) 构造 key→index 反向表，后续请求复用它；稳定滚动帧没有 O(N) 扫描。
key 回调抛错时请求不会被标记为已处理，下一帧可以原子重试。

### lastTargetFound

```cangjie
public func lastTargetFound(): Bool
```

最近一次已处理请求是否找到 key 或合法范围内的 index；请求发出后、视口处理前暂为 `false`。

## 另请参阅

- [LazyScrollAlignment](LazyScrollAlignment.md) — key 在视口中的目标位置。
- [LazyColumn](LazyColumn.md) / [LazyList](LazyList.md) / [LazyRow](LazyRow.md) — 支持本控制器的惰性容器。
