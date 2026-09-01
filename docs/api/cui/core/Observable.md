[cui](../../index.md) › [cui.core](index.md) › Observable

# Observable

`cui.core` 包中的 public interface

可读、可观察值的抽象：读取当前值、暴露修订号、订阅变更，并可 `map` 出派生状态。[`State`](State.md) 是其可写实现，[`DerivedState`](DerivedState.md) 是只读实现；只做展示的组件按 `Observable` 接收状态，两类实现都能驱动。

## 声明

```cangjie
public interface Observable<T>
```

## 继承

- 子接口：[`Bindable`](Bindable.md)（追加可写能力）。
- 已文档化实现：[`State`](State.md)、[`DerivedState`](DerivedState.md)、[`Binding`](Binding.md)。

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let words = State<Int64>(120)
    // 以 Observable 抽象持有：展示方只读，不关心来源是否可写
    let display: Observable<String> = words.map<String> {n => "${n} 字"}
    words.value = 254
    println(display.get())
    // 输出: 254 字
}
```

## 成员概览

**属性**

| 成员 | 说明 |
|---|---|
| [`revision`](#revision) | 只要值可能已变化就递增。 |

**方法**

| 成员 | 说明 |
|---|---|
| [`get()`](#get) | 读取当前值。 |
| [`observe(callback: (T, T) -> Unit)`](#observe) | 观察后续变更，返回可取消的观察句柄。 |
| [`map<U>(transform: (T) -> U)`](#map) | 返回一个只读状态，其值为对本值应用 `transform` 的结果。 |
| [`map<U>(transform: (T) -> U, policy: StateMutationPolicy<U>)`](#map) | 创建按结果等价类过滤失效的派生状态。 |

## 属性

### revision

只要值可能已变化就递增。只读；派生状态与脏帧检测据此判断是否需要重算或重绘。

```cangjie
prop revision: UInt64
```

**返回值** `UInt64` — 修订号。

## 方法

### get

读取当前值。

```cangjie
func get(): T
```

**返回值** `T` — 当前值。

### observe

观察后续变更，返回可取消的观察句柄。回调收到 `(旧值, 新值)`，注册时不会立即调用。

```cangjie
func observe(callback: (T, T) -> Unit): StateObservation<T>
```

**参数**

- `callback`: `(T, T) -> Unit` — 值变化后执行。

**返回值** [`StateObservation`](StateObservation.md)`<T>` — 调用其 `close()` 停止后续回调。

### map

返回一个只读状态，其值为对本值应用 `transform` 的结果。接口默认实现，基于 [`derive`](functions.md#derive)：惰性求值、按本值的修订号缓存。

```cangjie
func map<U>(transform: (T) -> U): DerivedState<U>

func map<U>(
    transform: (T) -> U,
    policy!: StateMutationPolicy<U>
): DerivedState<U>
```

**参数**

- `transform`: `(T) -> U` — 由当前值计算派生值。
- `policy`: [`StateMutationPolicy`](StateMutationPolicy.md)`<U>` — 可选的结果观察等价关系。传入后，有订阅者时会在上游提交点计算投影；等价结果不推进派生 revision，也不传播 retained 失效。

**返回值** [`DerivedState`](DerivedState.md)`<U>` — 跟随本值的只读派生状态。

## 另请参阅

- [Bindable](Bindable.md) — 在可观察值基础上增加写入与字段绑定能力的子接口。
- [derive](functions.md#derive) — 从多个源计算派生状态。
- [StateMutationPolicy](StateMutationPolicy.md) — State 与派生结果共用的观察等价关系。
