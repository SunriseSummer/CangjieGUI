[cui](../../index.md) › [cui.core](index.md) › State

# State

位于 `cui.core` 包的公开类

保存一份可读写、可观察的数据。修改 `value` 会通知依赖它的界面和观察者；只读展示可以接收 [`Observable`](Observable.md)，输入控件可以接收 [`Bindable`](Bindable.md)。`State` 进入桌面应用后归该应用的 UI 线程所有，不是并发容器。

## 声明

```cangjie
public class State<T> <: Bindable<T>
```

## 继承

- 实现 [`Bindable`](Bindable.md)`<T>`，并经由它实现 [`Observable`](Observable.md)`<T>`。

## 常用规则

- 默认构造器把每次赋值都视为变化，包括相等值。经常出现空写时，创建状态时传 [`structuralEqualityPolicy`](functions.md#structuralequalitypolicy)；只判断一次时可用 [`setIfChanged`](#setifchanged)。
- 一次事件、`post` 动作或 [`DesktopApp.batch`](../desktop/DesktopApp.md#batch) 中多次写同一状态，观察者只收到“事务开始前的值 → 最终值”。由多个源组成的派生状态也只在所有写入稳定后通知。
- 显式比较策略如果认为事务前后的值相同，则不通知观察者，也不请求新帧。修订号仍记录每次被策略接受的赋值，因此它表示写入版本，不等于通知次数。
- 观察者按注册顺序运行。注册时不会立即回调；在一次通知中新增的观察者从下一次变化开始接收。
- 某个观察者抛出异常时，框架仍会完成其余观察者和依赖失效，再把最先发生的异常交还调用方。
- 状态进入应用后，读写、注册观察和关闭观察句柄都应在所属 UI 线程进行。后台结果通过 [`DesktopApp.post`](../desktop/DesktopApp.md#post) 投递。

## 线程所有权

`State` 可以先在一个线程中创建和顺序准备，再交给桌面应用。绑定应用后，不得由多个线程并发访问。同一线程中的另一个应用只有在原应用没有活动事务时才能接管该状态；事务期间转交会被拒绝。

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

例如，为选中下标使用 `structuralEqualityPolicy<Int64>()` 后，重复写入同一下标不会触发界面更新。

## 属性

### revision

每次被比较策略接受的赋值后递增。默认构造器接受相等值；显式策略可以跳过等价值。该属性只读，派生状态和界面依赖用它判断值是否可能变化。

```cangjie
public prop revision: UInt64
```

**返回值** `UInt64` — 修订号；到达最大值后回绕到 0。

### value

读取或替换当前值。事务外的有效赋值会立即通知观察者；事务内的多次写入会合并为一次“初始值 → 最终值”通知。显式策略认为两者等价时不通知。

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

观察后续变更，返回可取消的观察句柄。回调收到 `(旧值, 新值)`，注册时不会立即调用。在回调中新增的观察者从下一次变化开始接收；关闭尚未运行的观察者会让它跳过当前通知。某个回调失败时，其余活动观察者仍会运行，之后再抛出最先发生的异常。状态绑定应用后，注册和 `close()` 都必须在所属 UI 线程执行。

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
