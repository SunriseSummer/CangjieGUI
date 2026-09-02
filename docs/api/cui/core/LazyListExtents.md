[cui](../../index.md) › [cui.core](index.md) › LazyListExtents

# LazyListExtents

位于 `cui.core` 包的公开类

供 `LazyList` 管理频繁变化的行高。内部使用前缀和索引，单行更新、位置查询和可见范围定位都是 O(log N)，避免
普通 `heightOf` 回调在每帧扫描全部行。

## 声明

```cangjie
public class LazyListExtents
```

## 构造函数

```cangjie
public init(heights: Array<Float32>, spacing!: Float32 = 0.0)
```

高度和间距以逻辑像素计，负值按 0。模型由 UI 线程持有；挂载后在其他线程调用更新会受到 [`State`](State.md) 的线程约束保护。

## 属性与方法

### count

```cangjie
public prop count: Int64
```

当前行数。

### heightAt

```cangjie
public func heightAt(row: Int64): Float32
```

返回一行当前高度；索引越界抛出数组边界异常。

### update

```cangjie
public func update(row: Int64, height: Float32): Bool
```

O(log N) 更新一行并请求一帧。值实际变化返回 `true`；相同值不调度。索引越界抛出 `IllegalArgumentException`。

### reset

```cangjie
public func reset(heights: Array<Float32>, spacing!: Float32 = 0.0): Unit
```

在插入、删除或重排后以 O(N) 重建全部行高索引，并请求一帧。配合稳定 key，连接的 [`LazyList`](LazyList.md)
会保持顶部条目的屏幕位置。

## 使用方式

先用初始高度数组和间距创建模型，再把它传给 `LazyList`，同时提供稳定 key。单条消息展开时只需调用
`update(expandedIndex, 120.0)`；框架只更新对应索引路径，不扫描其他行。

## 另请参阅

- [LazyList](LazyList.md) — 接受本模型的可变高惰性列表。
- [LazyViewportController](LazyViewportController.md) — 按稳定 key 定位。
