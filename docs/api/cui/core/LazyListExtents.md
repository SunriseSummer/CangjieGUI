[cui](../../index.md) › [cui.core](index.md) › LazyListExtents

# LazyListExtents

`cui.core` 包中的 public class

高频可变行高的外部 extent 模型。内部使用 Fenwick 索引：单行更新、前缀位置和可见范围定位为 O(log N)，避免普通 `heightOf` 闭包每帧扫描全部行。

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

在插入、删除或重排后 O(N) 重建全部 extent，并请求一帧。配合稳定 key，连接的 [`LazyList`](LazyList.md) 会保持顶部条目像素锚定。

## 示例

```cangjie
let heights = LazyListExtents(Array<Float32>(100000, {_ => 48.0}), spacing: 4.0)
LazyList(heights, key: {index => messages[index].id}, id: "messages") {
    index => MessageRow(messages[index])
}

// 一条消息展开：只更新 Fenwick 路径，不扫描其余 99999 行。
let _ = heights.update(expandedIndex, 120.0)
```

## 另请参阅

- [LazyList](LazyList.md) — 接受本模型的可变高惰性列表。
- [LazyViewportController](LazyViewportController.md) — 按稳定 key 定位。
