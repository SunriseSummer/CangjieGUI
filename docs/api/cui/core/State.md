[cui](../../index.md) › [cui.core](index.md) › State

# State

`cui.core` 包中的 public class

可写的单一数据源可观察状态：对 `value` 赋值会推进修订号，并在调用线程上同步通知全部观察者。只读展示走 [`Observable`](Observable.md) 抽象，双向输入走 [`Bindable`](Bindable.md)，因此一个 `State` 能同时驱动两类控件。`State` 是线程封闭对象，不是并发容器。

## 声明

```cangjie
public class State<T> <: Bindable<T>
```

## 继承

- 实现 [`Bindable`](Bindable.md)`<T>`，并经由它实现 [`Observable`](Observable.md)`<T>`。

## 说明

赋相等的值同样推进修订号并触发通知；要跳过空写，用扩展方法 [`setIfChanged`](#setifchanged)（要求 `T <: Equatable<T>`）。通知遍历监听者快照：在回调中取消观察或注册新观察都是安全的，回调中新注册的观察者只会看到之后的赋值。状态可以先在工作线程构造和顺序准备，再移交 UI；不可由多个线程并发访问。它进入运行中的界面后会绑定该应用的 UI 调度器，错误线程上的读取、写入、`update`、观察注册或取消都会抛出 `IllegalStateException`，应改用 [`DesktopApp.post`](../desktop/DesktopApp.md#post)。应用循环按自己的原子失效代数跳过无变化帧；进程级 [`currentStateGeneration`](functions.md#currentstategeneration) 仅保留为兼容诊断。

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let count = State<Int64>(1)
    let doubled = count.map<Int64> {n => n * 2} // 派生只读状态
    count.value = 21 // 赋值同步通知观察者
    println(doubled.get())
    // 输出: 42
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init(value: T)`](#init) | 以初始值构造一个状态。 |

**属性**

| 成员 | 说明 |
|---|---|
| [`revision`](#revision) | 每次赋值后递增，赋相等的值也递增。 |
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

以初始值构造一个状态。构造本身不触发任何通知。

```cangjie
public init(value: T)
```

**参数**

- `value`: `T` — 初始值。

## 属性

### revision

每次赋值后递增，赋相等的值也递增。只读；[`DerivedState`](DerivedState.md) 与脏帧检测按它判断值是否可能变化。

```cangjie
public prop revision: UInt64
```

**返回值** `UInt64` — 修订号；到达最大值后回绕到 0。

### value

读取或替换当前值。可读写；赋值会推进修订号与全局写入代号，并以 `(旧值, 新值)` 在调用线程上同步回调每个观察者。

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

观察后续变更，返回可取消的观察句柄。回调收到 `(旧值, 新值)`，注册时不会立即调用。状态绑定应用后，注册和句柄 `close()` 都必须在所属 UI 线程执行；取消被拒绝时句柄仍保持打开，可回到 UI 线程重试。

```cangjie
public func observe(callback: (T, T) -> Unit): StateObservation<T>
```

**参数**

- `callback`: `(T, T) -> Unit` — 每次赋值后在调用线程上同步执行。

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
- [StateStore](StateStore.md) / [rememberState](functions.md#rememberstate) — 跨声明式重建保留的键控局部状态。
- [derive](functions.md#derive) — 从多个源计算派生状态。
