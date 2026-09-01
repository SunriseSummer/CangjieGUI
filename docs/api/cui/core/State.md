[cui](../../index.md) › [cui.core](index.md) › State

# State

`cui.core` 包中的 public class

可写的单一数据源可观察状态：对 `value` 的有效赋值会推进修订号。事务外立即通知观察者；应用事件、`post` 或 [`DesktopApp.batch`](../desktop/DesktopApp.md#batch) 事务内，同一状态只在提交时通知一次。显式策略若判定事务首尾等价，则不通知也不请求新帧。只读展示走 [`Observable`](Observable.md) 抽象，双向输入走 [`Bindable`](Bindable.md)。`State` 是线程封闭对象，不是并发容器。

## 声明

```cangjie
public class State<T> <: Bindable<T>
```

## 继承

- 实现 [`Bindable`](Bindable.md)`<T>`，并经由它实现 [`Observable`](Observable.md)`<T>`。

## 说明

默认构造器把相等赋值也视为变化；要长期跳过空写，在构造时传 [`structuralEqualityPolicy`](functions.md#structuralequalitypolicy)，一次性判断可用 [`setIfChanged`](#setifchanged)。事务内多次写同一状态时，观察者收到 `(事务前值, 最终值)`；显式策略若判定两端等价（例如 `A → B → A`），整条路径不产生通知或帧失效。中间被策略接受的赋值仍各自推进 revision，因此 revision 是写入证据，不是提交通知计数。多个源的派生观察者等全部源稳定后只执行一次。通知按注册顺序遍历开始通知时已有的观察者；回调中取消尚未到达的观察者会使其跳过，中途新增的观察者从下一次赋值开始接收（同一回调触发的嵌套赋值也属于下一次）。单个回调抛异常不会阻断后续活动观察者；事务还会继续排空其他 State、Derived observer 及失败回调在抛出前产生的新写入，到达不动点后才重抛最先发生的用户异常。这样业务观察者不能截断框架依赖失效。这组语义不要求每次通知复制监听者数组。状态可以先在工作线程构造和顺序准备，再移交 UI；不可由多个线程并发访问。它进入运行中的界面后会绑定该应用的 UI 调度器，错误线程上的访问应改用 [`DesktopApp.post`](../desktop/DesktopApp.md#post)。同线程应用可在旧调度器空闲后顺序接管 State；旧事务仍活动时嵌套转交会被拒绝，避免两个原子边界交叉。

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let count = State<Int64>(1)
    let doubled = count.map<Int64> {n => n * 2} // 派生只读状态
    count.value = 21
    println(doubled.get())
    // 输出: 42
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init(value: T)`](#init) | 以初始值构造一个状态。 |
| [`init(value: T, policy!: StateMutationPolicy<T>)`](#init-with-policy) | 以显式等价策略构造状态。 |

**属性**

| 成员 | 说明 |
|---|---|
| [`revision`](#revision) | 每次被策略接受的赋值后递增。 |
| [`value`](#value) | 读取或替换当前值。 |

**方法**

| 成员 | 说明 |
|---|---|
| [`update(transform: (T) -> T)`](#update) | 用 `transform` 的结果替换当前值。 |
| [`observe(callback: (T, T) -> Unit)`](#observe) | 观察后续变更，返回可取消的观察句柄。 |

**扩展成员**

| 成员 | 说明 |
|---|---|
| [`setIfChanged(next: T)`](#setifchanged) | 仅当 `next` 与当前值不同才赋值，返回是否发生了赋值。 |

## 构造函数

### init

以初始值构造一个状态。默认接受包括相等值在内的每次赋值；构造本身不触发通知。

```cangjie
public init(value: T)
```

**参数**

- `value`: `T` — 初始值。

### init with policy

以显式 [`StateMutationPolicy`](StateMutationPolicy.md) 构造状态。策略判定旧值与候选值等价时，赋值、revision、通知和界面失效都会跳过。

```cangjie
public init(value: T, policy!: StateMutationPolicy<T>)
```

```cangjie
let selection = State<Int64>(0, policy: structuralEqualityPolicy<Int64>())
```

## 属性

### revision

每次被策略接受的赋值后递增。默认构造器接受相等值；显式策略可抑制等价写入。只读；[`DerivedState`](DerivedState.md) 与脏帧检测按它判断值是否可能变化。

```cangjie
public prop revision: UInt64
```

**返回值** `UInt64` — 修订号；到达最大值后回绕到 0。

### value

读取或替换当前值。可读写；有效赋值推进修订号与写入代号。事务外立即以 `(旧值, 新值)` 回调；事务内推迟并合并为 `(首次旧值, 最终新值)`。显式策略判定这两个端点等价时不回调，默认策略仍保留一次事件式回调。

```cangjie
public mut prop value: T
```

## 方法

### update

用 `transform` 的结果替换当前值。等价于 `state.value = transform(state.value)` 的一次读-改-写。线程归属检查发生在调用 `transform` 之前，错误线程不会读取旧值或执行用户代码。

```cangjie
public func update(transform: (T) -> T): Unit
```

**参数**

- `transform`: `(T) -> T` — 接收当前值并返回新值。

### observe

观察后续变更，返回可取消的观察句柄。回调收到 `(旧值, 新值)`，注册时不会立即调用。一次通知只访问它开始时已有且到达时仍有效的观察者；回调中新增的观察者不会倒流收到当前变化。某个回调失败时其后的活动观察者仍会运行；调度事务内还会继续其他源和派生观察者，到达稳定状态后重抛第一个失败。状态绑定应用后，注册和句柄 `close()` 都必须在所属 UI 线程执行；取消被拒绝时句柄仍保持打开，可回到 UI 线程重试。

```cangjie
public func observe(callback: (T, T) -> Unit): StateObservation<T>
```

**参数**

- `callback`: `(T, T) -> Unit` — 事务外在赋值后执行；事务内在提交点执行一次。

**返回值** [`StateObservation`](StateObservation.md)`<T>` — 调用其 `close()` 停止后续回调。

## 扩展成员

### setIfChanged

仅当 `next` 与当前值不同才赋值，返回是否发生了赋值。来自 `extend<T> State<T> where T <: Equatable<T>`，仅当 `T <: Equatable<T>` 时可用；用它避免空写打扰观察者。

```cangjie
public func setIfChanged(next: T): Bool
```

**参数**

- `next`: `T` — 候选新值，以 `==` 与当前值比较。

**返回值** `Bool` — 发生赋值为 `true`；值相等、未赋值为 `false`。

## 另请参阅

- [Observable](Observable.md) — 只读可观察抽象，`map` 派生的入口。
- [Bindable](Bindable.md) — 可读写抽象与 `project` 字段绑定。
- [StateMutationPolicy](StateMutationPolicy.md) — 可替换的写入等价关系。
- [StateStore](StateStore.md) / [rememberState](functions.md#rememberstate) — 跨声明式重建保留的键控局部状态。
- [derive](functions.md#derive) — 从多个源计算派生状态。
