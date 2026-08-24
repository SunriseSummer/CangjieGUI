[cui](../../index.md) › [cui.core](index.md) › LazyViewportController

# LazyViewportController

`cui.core` 包中的 public class

惰性视口的外部滚动控制器。持有可观察偏移，并能按稳定 key 显示条目而无需调用方知道其当前索引或累计高度。控制器应放在应用模型或 `rememberState` 之外的稳定对象中，不要每帧重建。

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

### scrollToKey

```cangjie
public func scrollToKey(
    key: String,
    alignment!: LazyScrollAlignment = LazyScrollAlignment.Nearest
): Unit
```

请求下一帧显示稳定 key。请求状态本身可观察，因此已挂载视口会自动获帧。空 key 抛出 `IllegalArgumentException`。按 key 查找只在请求帧发生，不给稳定滚动帧增加 O(N) 扫描。

### lastTargetFound

```cangjie
public func lastTargetFound(): Bool
```

最近一次已处理请求是否找到 key；请求发出后、视口处理前暂为 `false`。

## 另请参阅

- [LazyScrollAlignment](LazyScrollAlignment.md) — key 在视口中的目标位置。
- [LazyColumn](LazyColumn.md) / [LazyList](LazyList.md) / [LazyRow](LazyRow.md) — 支持本控制器的惰性容器。
