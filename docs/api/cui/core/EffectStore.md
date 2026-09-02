[cui](../../index.md) › [cui.core](index.md) › EffectStore

# EffectStore

位于 `cui.core` 包的公开类

持有单一应用模型并运行纯 [`EffectReducer`](EffectReducer.md)。内核只提交模型和交付效果值，不选择线程池、网络库、
重试、取消或去重策略。

```cangjie
public class EffectStore<Model, Action, Effect> <: Observable<Model>
```

## 构造

```cangjie
public init(initial: Model, reducer: EffectReducer<Model, Action, Effect>)

public init(
    initial: Model,
    reducer: EffectReducer<Model, Action, Effect>,
    policy!: StateMutationPolicy<Model>
)
```

## 读取与观察

```cangjie
public func get(): Model
public prop revision: UInt64
public func observe(callback: (Model, Model) -> Unit): StateObservation<Model>
```

`get` 返回当前完整模型，`revision` 返回底层状态版本。`observe` 观察后续提交，并返回可取消的订阅。

## 选择局部数据

```cangjie
public func select<Value>(selector: (Model) -> Value): DerivedState<Value>
public func select<Value>(
    selector: (Model) -> Value,
    policy!: StateMutationPolicy<Value>
): DerivedState<Value>
public func select<Value>(lens: Lens<Model, Value>): DerivedState<Value>
public func select<Value>(
    lens: Lens<Model, Value>,
    policy!: StateMutationPolicy<Value>
): DerivedState<Value>
```

`select` 创建缓存的只读派生状态。可用闭包或 Lens 选择局部数据；传入策略后，等价结果不会继续传播。

## connect

```cangjie
public func connect(
    handleEffects!: (EffectBatch<Effect>) -> Unit
): ScopedStore<Model, Action>
```

在应用组合根固定一次效果解释器，返回不再暴露 `Effect` 的 [`ScopedStore`](ScopedStore.md)。之后视图可以直接
`dispatch`、`dispatchAll`、创建无需重复 handler 的 action Binding，并继续 `scope` 到局部 Model/Action；每次派发
仍严格执行“完整归约 → 模型提交 → 整批效果交付”。它不是自动效果运行时，只是把显式 handler 部分应用到生产 UI
门面；线程、取消、重试、背压和结果 Action 仍由 handler 管理。

应用通常在组合根调用一次 `connect`，在处理器中遍历效果批次并交给后台执行器。返回的 Store 还可通过 `scope` 缩小到
具体功能，再传给对应子视图。

`connect(h).dispatch(a)` 与 `dispatch(a, handleEffects: h)` 具有相同的提交、效果顺序和失败语义；空批量不调用 `h`。
应在稳定的应用装配位置创建一次门面，不要在每次 build 中重复连接。测试若要直接断言效果值，仍使用返回
`EffectBatch` 的原始 dispatch 重载。

## dispatch

```cangjie
public func dispatch(action: Action): EffectBatch<Effect>

public func dispatch(
    action: Action,
    handleEffects!: (EffectBatch<Effect>) -> Unit
): Unit
```

返回批次的重载先提交模型，再返回尚未解释的效果，适合 reducer 测试或应用自己的 driver。需要执行外部工作时优先使用
`handleEffects` 重载：Reducer 或 State 策略在提交前失败时零提交、零交付；模型 revision 已提交后即使观察者失败，
批次仍交付一次，随后重新抛出最先的提交错误。Handler 失败不会回滚已提交模型，也不会继续其闭包中尚未解释的效果。

## dispatchAll

```cangjie
public func dispatchAll(actions: Array<Action>): EffectBatch<Effect>

public func dispatchAll(
    actions: Array<Action>,
    handleEffects!: (EffectBatch<Effect>) -> Unit
): Unit
```

在一个模型快照上按序归约全部 Action，效果通过持久批次按动作/reducer 顺序拼接，最后只提交模型一次。空数组零写入；
任一 reducer 失败时没有中间模型和效果交付。

## Binding

```cangjie
public func binding<Value>(
    get!: (Model) -> Value,
    action!: (Value) -> Action,
    handleEffects!: (EffectBatch<Effect>) -> Unit
): Binding<Value>

public func binding<Value>(
    get!: (Model) -> Value,
    action!: (Value) -> Action,
    handleEffects!: (EffectBatch<Effect>) -> Unit,
    policy!: StateMutationPolicy<Value>
): Binding<Value>

public func binding<Value>(
    lens: Lens<Model, Value>,
    action!: (Value) -> Action,
    handleEffects!: (EffectBatch<Effect>) -> Unit
): Binding<Value>

public func binding<Value>(
    lens: Lens<Model, Value>,
    action!: (Value) -> Action,
    handleEffects!: (EffectBatch<Effect>) -> Unit,
    policy!: StateMutationPolicy<Value>
): Binding<Value>
```

闭包与 Lens 重载都接受相同的 `action` 和 `handleEffects`。Binding 写入返回 `Unit`，因此本 API 强制显式提供效果交付，不能像
普通 [`ModelStore.binding`](ModelStore.md) 那样省略并静默丢弃。生产视图若有多个 Binding，优先在组合根
[`connect`](#connect) 一次，再使用返回门面的普通 action Binding。`Binding.update` 仍只使用一个根模型快照。
策略重载只过滤读取侧的等价通知；Action 产生的模型提交与效果批次仍完整交付，即使焦点值保持等价。

## 解释器边界

`Effect` 应是应用定义的普通值，例如“读取路径”“保存文档”“记录分析事件”。解释器可以同步处理，也可以启动后台
任务；后台结果必须通过 [`DesktopApp.post`](../desktop/DesktopApp.md#post) 回到 UI 线程，再派发成功/失败 Action。
CUI 刻意不提供自动同步 `send`、隐式任务树或全局中间件，避免把重入顺序、取消和线程语义藏进 Store。

## 另请参阅

- [`EffectBatch`](EffectBatch.md) 与 [`Transition`](Transition.md) — 效果代数和值语义。
- [模型、动作与界面边界](../../../guide/concepts/app-architecture.md) — 完整使用与取舍。
