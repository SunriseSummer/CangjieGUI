[cui](../../index.md) › [cui.core](index.md) › ScopedStore

# ScopedStore

`cui.core` 包中的 public class

根 [`ModelStore`](ModelStore.md) 或已连接 [`EffectStore`](EffectStore.md) 的特征局部门面。它只暴露局部 `Model` 和
局部 `Action`，状态读取仍来自根模型，写入仍由根 reducer 完成；不会创建第二份可写状态或局部 setter。

```cangjie
public class ScopedStore<Model, Action> <: Observable<Model>
```

实例由 `ModelStore.scope`、`EffectStore.connect` 或另一个 `ScopedStore.scope` 创建，不能直接构造。

## 示例

```cangjie
let profile = app.scope<Profile, ProfileAction>(
    state: profileLens,
    action: {action => AppAction.profile(action)},
    policy: structuralEqualityPolicy<Profile>()
)

let name = profile.binding<String>(
    lens: profileNameLens,
    action: {value => ProfileAction.rename(value)}
)

TextField(name)
Button("重置", {=> profile.dispatch(ProfileAction.reset())})
```

子视图只需要认识 `Profile`、`ProfileAction` 和 `ScopedStore<Profile, ProfileAction>`，无需依赖根模型或根 Action。

## 读取与观察

```cangjie
public func get(): Model
public prop revision: UInt64
public func observe(callback: (Model, Model) -> Unit): StateObservation<Model>
```

有真实状态投影时，值来自缓存只读节点，`revision` 是局部投影自己的修订号；`EffectStore.connect` 的 identity 门面
直接共享根 revision，直到第一次真正 scope。默认 scope 在根 revision 改变后传播“可能变化”，显式等价策略可让
未改变的局部商类保持 revision 和视图分支不动。

## Action

```cangjie
public func dispatch(action: Action): Unit
public func dispatchAll(actions: Array<Action>): Unit
```

`dispatch` 把局部 Action 逐层提升后交给根 Store。`dispatchAll` 按序提升并直接折叠到同一个根模型事务：不为每层
scope 构造中间 Action 数组，空数组零工作，成功只提交一次根 revision，任一 reducer 调用失败则没有部分提交。

单 Action 的提升成本与 scope 深度线性相关。批量路径的 Action 映射工作是 `O(深度 × Action 数)`，但附加存储只与
scope 深度相关。无策略的嵌套状态投影会融合到一个 Derived 节点：稳定缓存读取为常数路径，根变化后的首次求值只
执行组合投影；显式等价策略是不可穿透的商边界，后续投影从该节点重新开始融合。通常应让视图边界保持浅而有业务
意义，不要用大量恒等 scope 代替真正的特征建模。

## 选择

```cangjie
public func select<Value>(selector: (Model) -> Value): DerivedState<Value>
public func select<Value>(lens: Lens<Model, Value>): DerivedState<Value>

public func select<Value>(
    selector: (Model) -> Value,
    policy!: StateMutationPolicy<Value>
): DerivedState<Value>

public func select<Value>(
    lens: Lens<Model, Value>,
    policy!: StateMutationPolicy<Value>
): DerivedState<Value>
```

这些方法与 `ModelStore.select` 语义相同，但 selector 的输入已经是局部模型。普通 scope 链会把局部投影和末端 selector
继续组合到一个 [`DerivedState`](DerivedState.md)，而不是重新接在 scope 节点后；显式商边界仍不可穿透。所得节点继续
共享同一根事实。

## 继续聚焦

```cangjie
public func scope<LocalModel, LocalAction>(
    state!: (Model) -> LocalModel,
    action!: (LocalAction) -> Action
): ScopedStore<LocalModel, LocalAction>

public func scope<LocalModel, LocalAction>(
    state!: (Model) -> LocalModel,
    action!: (LocalAction) -> Action,
    policy!: StateMutationPolicy<LocalModel>
): ScopedStore<LocalModel, LocalAction>

public func scope<LocalModel, LocalAction>(
    path: FeaturePath<Model, Action, LocalModel, LocalAction>
): ScopedStore<LocalModel, LocalAction>
```

`state` 也可传 `Lens<Model, LocalModel>`，并有相同的策略重载。嵌套 scope 组合状态投影和 Action 提升；若 Lens 满足
Get-Put、Put-Get、Put-Put，嵌套状态边界与组合 Lens 的读取一致。Action 提升应是确定、无副作用的总函数。
也可传 [`FeaturePath`](FeaturePath.md)；其 `then` 会同时组合 Lens 与 Prism，避免深层 Store 和 reducer 各自维护一套
路由。路径重载同样支持显式 `policy`。

## Binding

```cangjie
public func binding<Value>(
    get!: (Model) -> Value,
    action!: (Value) -> Action
): Binding<Value>

public func binding<Value>(
    get!: (Model) -> Value,
    action!: (Value) -> Action,
    policy!: StateMutationPolicy<Value>
): Binding<Value>

public func binding<Value>(
    lens: Lens<Model, Value>,
    action!: (Value) -> Action
): Binding<Value>

public func binding<Value>(
    lens: Lens<Model, Value>,
    action!: (Value) -> Action,
    policy!: StateMutationPolicy<Value>
): Binding<Value>
```

控件写入先构造局部 Action，再沿 scope 链提升到根 reducer。`Binding.update` 只读取一次当前局部模型，并保留根模型
其他特征；它不授予局部模型写权限。策略重载把 scope、字段投影和最终等价关系融合到最近的商边界，兄弟 Action
不会产生空字段通知；写入与效果交付路径保持不变。

## 生命周期与边界

ScopedStore 的投影和派发闭包会保持根状态路径可达；它本身没有需要关闭的订阅。只有 `observe` 返回的
[`StateObservation`](StateObservation.md) 需要由调用方关闭。Store 仍遵守 UI 线程约束。

由 `EffectStore.connect` 创建时，解释器已在组合根显式固定；局部派发仍会在模型提交后把完整根效果批次交付一次，
不会静默丢弃。解释器失败时已提交模型不回滚，提交观察者失败时仍先交付批次再重抛首错。

## 另请参阅

- [`ModelStore`](ModelStore.md) — 根状态所有者与 scope 创建入口。
- [`EffectStore`](EffectStore.md#connect) — 固定效果解释器并创建相同的局部 UI 门面。
- [`Reducer`](Reducer.md) — 通过 Lens pullback 把局部更新规则提升到根模型。
- [`Lens`](Lens.md) — 可组合、可验证定律的状态投影。
- [`Prism`](Prism.md) 与 [`FeaturePath`](FeaturePath.md) — Action 分支与完整特征路径。
