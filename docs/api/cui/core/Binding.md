[cui](../../index.md) › [cui.core](index.md) › Binding

# Binding

位于 `cui.core` 包的公开类

指向另一个可绑定值中某个字段的双向绑定，用 [`Bindable.project`](Bindable.md#project) 或 Store 的 `binding` 创建。读取时从原值取出该字段；写入时用 Lens 或 Action 回到原值，因此数据源始终只有一个。策略重载可让读取侧只观察焦点值的等价类，而不削弱写权限边界。没有公开构造函数。

## 声明

```cangjie
public class Binding<T> <: Bindable<T>
```

## 继承

- 实现 [`Bindable`](Bindable.md)`<T>`，并经由它实现 [`Observable`](Observable.md)`<T>`——因此字段绑定本身还能继续 `project` 或 `map`。

## 示例

```cangjie verify
package docexample

import cui.*

struct Profile {
    let name: String
    let subscribed: Bool
    init(name: String, subscribed: Bool) {
        this.name = name
        this.subscribed = subscribed
    }
}

main(): Unit {
    let form = State<Profile>(Profile("林", true))
    let name: Binding<String> = form.project(get: {p => p.name}, set: {p, v => Profile(v, p.subscribed)})
    name.value = "苏" // 写入重建整个 Profile 并赋回源
    println("${form.value.name} ${form.value.subscribed}")
    // 输出: 苏 true
}
```

## 成员概览

**属性**

| 成员 | 说明 |
|---|---|
| [`value`](#value) | 读取或替换绑定到的字段。 |
| [`revision`](#revision) | 源的修订号。 |

**方法**

| 成员 | 说明 |
|---|---|
| [`update(transform: (T) -> T)`](#update) | 用一次根模型更新变换绑定字段。 |
| [`observe(callback: (T, T) -> Unit)`](#observe) | 观察后续变化并返回可取消的订阅。 |

## 属性

### value

读取或替换绑定到的字段。读取时通过 `get` 从原值取出字段；写入时通过 `set` 重建整个原值并写回，因此观察原值的代码也会收到通知。

```cangjie
public mut prop value: T
```

### revision

读取投影的修订号。默认 Binding 与源同步，源的任何赋值（包括其它成分的变化）都会推进；由带 `policy` 的 `project`/Store `binding` 创建时，只有焦点值跨越策略等价类才推进。

```cangjie
public prop revision: UInt64
```

**返回值** `UInt64` — 与源同步的修订号。

## 方法

### update

用 `transform` 修改当前字段。对于链式 `project` 产生的嵌套 Binding，框架会组合所有写回函数，并且只读取、写入根
`Bindable` 一次。通过组合 Lens 创建时，每层 Lens 也只访问一次。同一次修改始终基于同一个模型快照；变换或任一投影
抛异常时，根值不会写回。

```cangjie
public func update(transform: (T) -> T): Unit
```

**参数**

- `transform`: `(T) -> T` — 字段当前值到字段下一值的变换。

### observe

观察后续变化并返回可取消的订阅。回调收到字段的 `(旧值, 新值)`。默认 Binding 在原值每次被接受赋值时触发；策略 Binding 只在字段跨越显式等价类时触发，等价候选也不会替换缓存代表元。策略必须快速、确定、无副作用并满足等价关系。

```cangjie
public func observe(callback: (T, T) -> Unit): StateObservation<T>
```

**参数**

- `callback`: `(T, T) -> Unit` — 原始值变化后执行，参数为字段更新前后的值。

**返回值** [`StateObservation`](StateObservation.md)`<T>` — 调用其 `close()` 停止后续回调。

## 另请参阅

- [Bindable.project](Bindable.md#project) — 创建字段绑定的入口。
- [State](State.md) — 最常见的原始状态。
