[cui](../../index.md) › [cui.core](index.md) › DerivedState

# DerivedState

位于 `cui.core` 包的公开类

由一个或多个源计算出的只读可观察状态，用 [`derive`](functions.md#derive)、[`deriveStates`](functions.md#derivestates) 或 [`Observable.map`](Observable.md#map) 创建。求值惰性且带缓存：仅当某个源的修订号在两次读取之间变化才重新计算。没有公开构造函数。

## 声明

```cangjie
public open class DerivedState<T> <: Observable<T>
```

## 继承

- 实现 [`Observable`](Observable.md)`<T>`（只读，无 `value` 赋值）。

类型为 `open` 仅供内核的结果等价专用实现复用缓存协议；构造函数仍为包内可见，应用不能自行构造或继承。

## 说明

`DerivedState` 按需计算。第一次读取会执行计算函数；之后只要源状态没有变化，就直接返回缓存。源变化时先标记结果可能过期，直到下一次读取才重新计算。

框架会把稳定的派生状态作为一个依赖节点管理。读取派生值的界面只依赖这个节点，不必分别登记每个上游状态。上游变化只使相关界面失效，不会提前执行计算函数。

在构建函数中长期使用复杂派生图时，可以用 [`remember`](functions.md#remember) 保留对象。普通一次性派生无需手工缓存。源集合会在创建派生状态时固定；之后替换调用方数组中的元素不会改变既有依赖，需要换源时应创建新的派生状态。

`derive` 支持一至五个不同类型的固定源，也支持同类型 `Observable` 数组。直接持有 `Array<State<T>>` 时使用 `deriveStates`。超过五个不同类型的源时，通常应先把强相关事实整理成有业务含义的模型，而不是继续嵌套无名派生层。

默认派生状态在上游可能变化时向下游传播失效。若计算结果经常保持不变，可以给 `map` 或固定源 `derive` 传比较策略，也可以对已有派生调用 [`distinct`](#distinct)。比较和投影应快速、纯净；昂贵计算应通过更合适的状态边界或缓存解决。

显式观察同样遵守事务规则：一个事务修改多个源时，回调只在全部源稳定后运行一次，并看到最终组合结果。关闭观察句柄会取消全部上游订阅。

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
| [`distinct(policy: StateMutationPolicy<T>)`](#distinct) | 只在结果跨越观察等价类时传播变化。 |

## 属性

### value

计算值；任一上游状态在上次读取后变化时，先重新计算。只读；上游状态未变化时直接返回缓存，不重复执行计算闭包。计算抛出异常时不提交捕获的源 revision，后续读取仍会重试；计算期间源发生写入时，下一次读取会再次刷新。

```cangjie
public prop value: T
```

**返回值** `T` — 最新计算结果。

### revision

本派生状态自身的修订号，读取时先按源刷新。只读；普通节点在计算结果真正重算后递增，带等价策略的节点只在结果
跨越等价类时递增。

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

观察后续结果变化，返回可取消的观察句柄。回调收到 `(旧值, 新值)`。同一事务中的多次源变化会合并，回调只看到稳定后的结果；关闭句柄会同时取消全部上游订阅。

```cangjie
public func observe(callback: (T, T) -> Unit): StateObservation<T>
```

**参数**

- `callback`: `(T, T) -> Unit` — 任一上游状态变化后执行，参数为重新计算前后的结果。

**返回值** [`StateObservation`](StateObservation.md)`<T>` — 调用其 `close()` 同时取消对全部源的订阅。

### distinct

```cangjie
public func distinct(policy: StateMutationPolicy<T>): DerivedState<T>
```

为当前派生结果增加比较策略。`policy` 必须快速、确定、无副作用，并满足等价关系。策略认为新旧结果相同时，不替换缓存、不推进修订号，也不通知下游。单源投影优先直接使用 `map(transform, policy:)`；`distinct` 适合已经组合好的多源派生。

## 另请参阅

- [derive](functions.md#derive) — 一至五个异构源、对应融合策略或同类型动态源的兼容派生入口（十一重载）。
- [deriveStates](functions.md#derivestates) — `Array<State<T>>` 的静态专用入口。
- [remember](functions.md#remember) — 在声明式 build 中保留稳定派生身份。
- [Observable.map](Observable.md#map) — 单源派生的便捷形式。
- [StateMutationPolicy](StateMutationPolicy.md) — 定义哪些结果在观察意义上相同。
- [State](State.md) — 可写的源状态。
