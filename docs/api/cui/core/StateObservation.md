[cui](../../index.md) › [cui.core](index.md) › StateObservation

# StateObservation

位于 `cui.core` 包的公开类

由 [`Observable.observe`](Observable.md#observe) 返回的可取消的观察句柄：持有它就持续收到回调，`close()` 后不再收到。实现标准库 `Resource`，可放进 `try (…)` 资源块让观察随作用域自动结束。

## 声明

```cangjie
public class StateObservation<T> <: Resource
```

## 继承

- `Resource`（标准库 `std.core`）——支持 `try (…)` 资源语法；[`close`](#close) 可重复调用，第一次取消观察，后续调用不再改变状态。

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let name = State<String>("草稿")
    let changes = State<Int64>(0) // 计数器包进 State，lambda 才能修改
    let observation: StateObservation<String> = name.observe {_, _ => changes.update {n => n + 1}}
    name.value = "已发布" // 通知一次
    observation.close()
    name.value = "已归档" // 已取消，不再回调
    println("${changes.value} ${observation.isClosed()}")
    // 输出: 1 true
}
```

## 成员概览

**方法**

| 成员 | 说明 |
|---|---|
| [`isClosed()`](#isclosed) | 返回本次观察是否已被取消。 |
| [`close()`](#close) | 取消后续回调。 |

## 方法

### isClosed

返回本次观察是否已被取消。

```cangjie
public func isClosed(): Bool
```

**返回值** `Bool` — 已取消为 `true`。

### close

取消后续回调。重复调用安全，第二次起为空操作。

```cangjie
public func close(): Unit
```

## 另请参阅

- [Observable.observe](Observable.md#observe) — 产生本观察句柄的订阅入口。
- [State](State.md) / [DerivedState](DerivedState.md) / [Binding](Binding.md) — 可被观察的三类状态。
