[cui](../../index.md) › [cui.core](index.md) › DerivedState

# DerivedState

`cui.core` 包中的 public class

由一个或多个源计算出的只读可观察状态，用 [`derive`](functions.md#derive) 或 [`Observable.map`](Observable.md#map) 创建。求值惰性且带缓存：仅当某个源的修订号在两次读取之间变化才重新计算。没有公开构造函数。

## 声明

```cangjie
public class DerivedState<T> <: Observable<T>
```

## 继承

- 实现 [`Observable`](Observable.md)`<T>`（只读，无 `value` 赋值）。

## 说明

派生遵循拉取模型，与可重复执行或 retained 命中的声明式 UI 匹配：在界面构建函数内派生时，每次实际执行只花一次闭包调用，跳过的 retained scope 不会重新创建它，且不给上游长期注册监听器。推送式的 [`observe`](#observe) 只在返回的观察句柄的存续期间订阅各源，观察句柄关闭即全部退订，源的监听列表不会积累构建期订阅者。

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let done = State<Int64>(3)
    let total = State<Int64>(8)
    let summary: DerivedState<String> = derive(done, total, {d, t => "${d}/${t} 已完成"})
    done.value = 4 // 上游状态变化后，下次读取才重新计算
    println(summary.value)
    // 输出: 4/8 已完成
}
```

## 成员概览

**属性**

| 成员 | 说明 |
|---|---|
| [`value`](#value) | 计算值；任一上游状态在上次读取后变化时，先重新计算。 |
| [`revision`](#revision) | 本派生状态自身的修订号，读取时先按源刷新。 |

**方法**

| 成员 | 说明 |
|---|---|
| [`get()`](#get) | 读取当前值，等价于读 `value`。 |
| [`observe(callback: (T, T) -> Unit)`](#observe) | 观察后续变更，返回可取消的观察句柄。 |

## 属性

### value

计算值；任一上游状态在上次读取后变化时，先重新计算。只读；上游状态未变化时直接返回缓存，不重复执行计算闭包。

```cangjie
public prop value: T
```

**返回值** `T` — 最新计算结果。

### revision

本派生状态自身的修订号，读取时先按源刷新。只读；只在计算结果真正重算过后递增。

```cangjie
public prop revision: UInt64
```

**返回值** `UInt64` — 修订号。

## 方法

### get

读取当前值，等价于读 `value`。

```cangjie
public func get(): T
```

**返回值** `T` — 最新计算结果。

### observe

观察后续变更，返回可取消的观察句柄。回调收到 `(旧值, 新值)`；对各源的订阅只维持到观察句柄关闭。

```cangjie
public func observe(callback: (T, T) -> Unit): StateObservation<T>
```

**参数**

- `callback`: `(T, T) -> Unit` — 任一上游状态变化后执行，参数为重新计算前后的结果。

**返回值** [`StateObservation`](StateObservation.md)`<T>` — 调用其 `close()` 同时取消对全部源的订阅。

## 另请参阅

- [derive](functions.md#derive) — 一到多源的派生入口（四个重载）。
- [Observable.map](Observable.md#map) — 单源派生的便捷形式。
- [State](State.md) — 可写的源状态。
