[cui](../../index.md) › [cui.core](index.md) › StateStore

# StateStore

`cui.core` 包中的 public class

跨声明式重建保留显式键控局部状态的容器：一次完整构建未访问的条目会被移除，与视图卸载语义一致。应用代码通常不直接持有它，而是在 [`DesktopApp`](../desktop/DesktopApp.md) 构建中经 [`rememberState`](functions.md#rememberstate) 使用。

## 声明

```cangjie
public class StateStore
```

## 说明

键在当前 [`Keyed`](Keyed.md) 作用域内解析，因此重复的组件可以使用相同的内部状态名而互不串扰。同一构建内重复使用同一键、或键对应的值类型改变，都会立即抛出异常而不是悄悄返回错误的状态。构建期采用层次化所有权：retained 父边界命中时无需遍历全部后代；只有真实卸载才递归清理。一次根构建的所有权变化、retained 替换与 lifecycle effect 延迟到成功结束后提交，失败构建不会破坏上次已提交的树。宿主外直接调用 `remember` 的条目持久到 `clear()`，不参与构建期卸载判定。

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let store = StateStore()
    let draft = store.remember<String>("draft") {"晨会纪要"}
    let dirty = store.remember<Bool>("dirty") {false}
    draft.value = "晨会纪要 v2"
    dirty.value = true
    println("${draft.value} ${dirty.value}")
    store.clear() // 移除全部保留值
    // 输出: 晨会纪要 v2 true
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init()`](#init) | 创建一个空的状态存储容器。 |

**方法**

| 成员 | 说明 |
|---|---|
| [`remember<T>(key: String, initial: () -> T)`](#remember) | 返回当前作用域下键 `key` 对应的状态，首次使用时以 `initial` 创建。 |
| [`remember<T>(key: String, policy: StateMutationPolicy<T>, initial: () -> T)`](#remember) | 以显式观察等价策略首次创建键控状态。 |
| [`clear()`](#clear) | 移除全部保留状态并关闭挂载的 lifecycle effect。 |

## 构造函数

### init

**由编译器生成：** 仓颉会为所有实例字段均有初值且未声明构造函数的类提供该无参构造函数。

创建一个空的状态存储容器。新容器没有已保留的状态或活动作用域。

```cangjie
public init()
```

## 方法

### remember

返回当前作用域下键 `key` 对应的状态，首次使用时以 `initial` 创建。后续构建以同一键调用会取回同一个 [`State`](State.md) 实例，`initial` 不再执行。

```cangjie
public func remember<T>(key: String, initial: () -> T): State<T>
```

```cangjie
public func remember<T>(key: String, policy: StateMutationPolicy<T>, initial: () -> T): State<T>
```

**参数**

- `key`: `String` — 状态标识键，不得为空；实际存储键还带上当前 `Keyed` 作用域前缀。
- `policy`: [`StateMutationPolicy`](StateMutationPolicy.md)`<T>` — 仅在首次创建时采用的观察等价策略。
- `initial`: `() -> T` — 首次使用时的初值工厂。

**返回值** [`State`](State.md)`<T>` — 保留的状态实例。

**异常**

- `IllegalArgumentException` — 键为空。
- `IllegalStateException` — 同一作用域同一构建内键重复，或键对应的值类型改变。

后续使用同一键时返回原 State；与 `initial` 相同，新传入的 `policy` 不会替换首次创建时的配置。

### clear

移除全部保留的状态值并按子树/声明逆序关闭 lifecycle effect。下一次 `remember` 将重新以 `initial` 创建；
cleanup 抛异常时仍继续清理其余资源，最后重抛首个异常，失败 Resource 保留供下次 `clear` 重试。

```cangjie
public func clear(): Unit
```

## 另请参阅

- [rememberState](functions.md#rememberstate) — 活动构建中访问本容器的包级入口。
- [Keyed](Keyed.md) — 为键提供稳定作用域的组件。
