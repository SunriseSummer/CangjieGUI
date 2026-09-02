[cui](../../index.md) › [cui.core](index.md) › ScopedStore

# ScopedStore

位于 `cui.core` 包的公开类

根 [`ModelStore`](ModelStore.md) 或已连接 [`EffectStore`](EffectStore.md) 的局部视图。它只暴露某个功能需要的
`Model` 和 `Action`；状态仍从根模型读取，写入仍由根 reducer 完成，不会创建第二份可写状态。

```cangjie
public class ScopedStore<Model, Action> <: Observable<Model>
```

实例由 `ModelStore.scope`、`EffectStore.connect` 或另一个 `ScopedStore.scope` 创建，不能直接构造。

## 使用方式

根 Store 可通过资料 Lens 和 Action 转换函数得到 `ScopedStore<Profile, ProfileAction>`，再从局部 Store 创建姓名
Binding 交给 `TextField`。重置按钮只需派发局部 Action；子视图无需认识根模型和根 Action。

## 读取与观察

```cangjie
public func get(): Model
public prop revision: UInt64
public func observe(callback: (Model, Model) -> Unit): StateObservation<Model>
```

经过 `scope` 后，值来自缓存的只读派生状态，`revision` 表示局部结果的版本。`EffectStore.connect` 返回的初始视图
直接共享根版本，直到首次缩小状态范围。默认 scope 在根版本变化时传播“可能变化”；传入等价策略后，局部结果没有变化
就不会增加版本或重建对应界面。

## Action

```cangjie
public func dispatch(action: Action): Unit
public func dispatchAll(actions: Array<Action>): Unit
```

`dispatch` 把局部 Action 逐层转换后交给根 Store。`dispatchAll` 按顺序转换，并在同一个根模型事务中处理：不会为每层
scope 创建中间数组，空数组不执行操作，成功时只提交一次；任一 reducer 失败都不会产生部分提交。

单 Action 的提升成本与 scope 深度线性相关。批量路径的 Action 映射工作是 `O(深度 × Action 数)`，但附加存储只与
scope 深度相关。没有等价策略时，嵌套的状态投影会合并到一个 `DerivedState`；稳定读取直接使用缓存，根状态变化后才
重新执行组合投影。每个显式策略独立过滤该层的变化，后续投影从这里继续组合。scope 应对应清晰的业务边界，避免创建
大量不缩小模型的无意义层级。

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

这些方法与 `ModelStore.select` 相同，但选择器的输入已经是局部模型。普通 scope 链会把此前投影和最终选择器合并到
一个 [`DerivedState`](DerivedState.md)；显式策略仍在各自层级过滤变化。所有派生状态继续共享同一个根模型。

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
    state!: Lens<Model, LocalModel>,
    action!: (LocalAction) -> Action
): ScopedStore<LocalModel, LocalAction>

public func scope<LocalModel, LocalAction>(
    state!: Lens<Model, LocalModel>,
    action!: (LocalAction) -> Action,
    policy!: StateMutationPolicy<LocalModel>
): ScopedStore<LocalModel, LocalAction>

public func scope<LocalModel, LocalAction>(
    path: FeaturePath<Model, Action, LocalModel, LocalAction>
): ScopedStore<LocalModel, LocalAction>

public func scope<LocalModel, LocalAction>(
    path: FeaturePath<Model, Action, LocalModel, LocalAction>,
    policy!: StateMutationPolicy<LocalModel>
): ScopedStore<LocalModel, LocalAction>
```

嵌套 scope 组合状态投影和 Action 提升；若 Lens 满足
Get-Put、Put-Get、Put-Put，嵌套 scope 与组合 Lens 的读取结果一致。Action 转换函数应确定、无副作用，并处理所有输入。
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

控件写入先构造局部 Action，再沿 scope 链转换为根 Action。`Binding.update` 只读取一次当前局部模型，并保留根模型
其他部分；它不会绕过 reducer 直接修改局部模型。策略重载会过滤字段值未变化的通知，但不改变 Action 处理和效果交付。

## 生命周期与边界

ScopedStore 的投影和派发闭包会保持根状态路径可达；它本身没有需要关闭的订阅。只有 `observe` 返回的
[`StateObservation`](StateObservation.md) 需要由调用方关闭。Store 仍遵守 UI 线程约束。

由 `EffectStore.connect` 创建时，解释器已在组合根显式固定；局部派发仍会在模型提交后把完整根效果批次交付一次，
不会静默丢弃。解释器失败时已提交模型不回滚，提交观察者失败时仍先交付批次再重抛首错。

## 另请参阅

- [`ModelStore`](ModelStore.md) — 根状态所有者与 scope 创建入口。
- [`EffectStore`](EffectStore.md#connect) — 固定效果处理器并创建相同的局部 Store。
- [`Reducer`](Reducer.md) — 通过 Lens pullback 把局部更新规则提升到根模型。
- [`Lens`](Lens.md) — 可组合、可验证定律的状态投影。
- [`Prism`](Prism.md) 与 [`FeaturePath`](FeaturePath.md) — Action 分支与完整特征路径。
