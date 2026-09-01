[cui](../../index.md) › [cui.core](index.md) › Bindable

# Bindable

`cui.core` 包中的 public interface

可读、可写并能通知变化的值。交互控件通过它接收状态，因此既可以直接传 [`State`](State.md)，也可以传指向大对象中某个字段的 [`Binding`](Binding.md)。`project` 会从整个模型中取出一个字段，并把对该字段的修改写回原模型；文本框（[`TextField`](../text/TextField.md)）等编辑控件通常用它绑定模型字段。

## 声明

```cangjie
public interface Bindable<T> <: Observable<T>
```

## 继承

- 父接口：[`Observable`](Observable.md)`<T>`。
- 已文档化实现：[`State`](State.md)、[`Binding`](Binding.md)。

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

// 控件式写法：按 Bindable 抽象接收，State 与 Binding 都能传入
func toggle(flag: Bindable<Bool>): Unit {
    flag.update({value => !value})
}

main(): Unit {
    let form = State<Profile>(Profile("林", true))
    let subscribed = form.project(get: {p => p.subscribed}, set: {p, v => Profile(p.name, v)})
    toggle(subscribed) // 修改字段绑定时会重建整个 Profile
    println("${form.value.name} ${form.value.subscribed}")
    // 输出: 林 false
}
```

## 成员概览

**属性**

| 成员 | 说明 |
|---|---|
| [`value`](#value) | 读取或替换当前值。 |

**方法**

| 成员 | 说明 |
|---|---|
| [`get()`](#get) | 读取当前值。 |
| [`update(transform: (T) -> T)`](#update) | 基于一个最新快照变换当前值。 |
| [`project<U>(get!, set!)`](#project) | 返回指向本值中某个成分的双向绑定。 |
| [`project<U>(lens: Lens<T, U>)`](#project-with-lens) | 通过可组合 Lens 返回双向绑定。 |

## 属性

### value

读取或替换当前值。可读写；这是 `Bindable` 相对 [`Observable`](Observable.md) 追加的能力。

```cangjie
mut prop value: T
```

## 方法

### get

读取当前值。接口默认实现，返回 `value`。

```cangjie
func get(): T
```

**返回值** `T` — 当前值。

### update

读取一个最新值，把 `transform` 应用于它并写回结果。`State` 与 `Binding` 都实现此协议；嵌套 Binding 会把局部变换
逐层提升成一次根模型 read-modify-write，而不是在每个投影层重新读取根值。

```cangjie
func update(transform: (T) -> T): Unit
```

**参数**

- `transform`: `(T) -> T` — 从当前快照生成下一值的纯变换；抛出异常时不执行写回。

```cangjie
subscribed.update({value => !value})
```

### project

返回指向本值中某个成分的双向绑定。`get` 抽取成分，`set` 围绕改动后的成分重建整个值——读写始终落在同一个数据源上。可选策略只改变读取侧的观察等价类，不改变写回路径。接口默认实现。

```cangjie
func project<U>(get!: (T) -> U, set!: (T, U) -> T): Binding<U>

func project<U>(
    get!: (T) -> U,
    set!: (T, U) -> T,
    policy!: StateMutationPolicy<U>
): Binding<U>
```

**参数**

- `get!`: `(T) -> U` — 从整体值中抽取成分。
- `set!`: `(T, U) -> T` — 接收 `(整体旧值, 成分新值)`，返回重建后的整体值。
- `policy!`: [`StateMutationPolicy`](StateMutationPolicy.md)`<U>` — 可选的焦点值等价关系；根值只改变其它成分时不推进 Binding revision 或通知观察者。

**返回值** [`Binding`](Binding.md)`<U>` — 指向该成分的双向绑定。

```cangjie
let form = State<Profile>(Profile("林", true))
let name = form.project(get: {p => p.name}, set: {p, v => Profile(v, p.subscribed)})
TextField(name)   // 编辑控件直接读写选中的成分
```

### project with Lens

通过可复用、可组合的 [`Lens`](Lens.md) 创建字段绑定。Lens 应满足 Get-Put、Put-Get、Put-Put 三条定律。Binding
保留 Lens 融合的 `update` 路径；深层组合不会退回逐前缀重复读取。

```cangjie
func project<U>(lens: Lens<T, U>): Binding<U>

func project<U>(lens: Lens<T, U>, policy!: StateMutationPolicy<U>): Binding<U>
```

**返回值** [`Binding`](Binding.md)`<U>` — 指向 Lens 焦点的双向绑定。

## 另请参阅

- [Observable](Observable.md) — 只读父接口。
- [Binding](Binding.md) — `project` 返回的字段绑定类型。
- [Lens](Lens.md) — 可命名、组合并验证定律的双向投影。
