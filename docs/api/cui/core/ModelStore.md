[cui](../../index.md) › [cui.core](index.md) › ModelStore

# ModelStore

`cui.core` 包中的 public class

强类型单向应用模型：界面观察或选择 `Model`，把用户意图转换为 `Action`，只有纯 [`Reducer`](Reducer.md) 能构造
下一模型。它内部只有一个 [`State`](State.md)，不会为 selector 或字段 Binding 复制事实。

```cangjie
public class ModelStore<Model, Action> <: Observable<Model>
```

## 构造

```cangjie
public init(
    initial: Model,
    reducer: Reducer<Model, Action>
)
```

```cangjie
public init(
    initial: Model,
    reducer: Reducer<Model, Action>,
    policy!: StateMutationPolicy<Model>
)
```

```cangjie
public init(initial: Model, update!: (Model, Action) -> Model)
```

```cangjie
public init(
    initial: Model,
    update!: (Model, Action) -> Model,
    policy!: StateMutationPolicy<Model>
)
```

默认保持 `State` 的“每次 dispatch 都是事件”语义；模型有稳定等价关系时传
[`structuralEqualityPolicy`](functions.md#structuralequalitypolicy) 或领域策略。

## 示例

```cangjie
let counter = ModelStore<Int64, Int64>(0, update: {model, delta => model + delta})
let doubled = counter.select<Int64>(
    {model => model * 2},
    policy: structuralEqualityPolicy<Int64>()
)
counter.dispatch(1)
counter.dispatchAll([2, 3])
// counter.get() == 6；doubled.get() == 12
```

## 属性与观察

```cangjie
public prop revision: UInt64
public func get(): Model
public func observe(callback: (Model, Model) -> Unit): StateObservation<Model>
```

这些成员直接投影内部单一 State，并遵守相同 UI 线程、事务合并、观察顺序和异常隔离契约。

## Action

### dispatch

```cangjie
public func dispatch(action: Action): Unit
```

从最新模型快照执行一次 reducer 并提交。Reducer 抛异常时不写入。

### dispatchAll

```cangjie
public func dispatchAll(actions: Array<Action>): Unit
```

按数组顺序在一个局部模型快照上折叠全部 Action，最后只写 State 一次。空数组零写入；任一步失败时没有中间模型、
revision 或通知。若多项意图本质上是一个领域事件，优先定义一个表达完整事件的 Action；该方法适合已有动作序列、
重放、导入和测试。

## 选择与绑定

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

selector 是缓存的只读 [`DerivedState`](DerivedState.md)，不是第二份状态。默认重载保持完全惰性，但根模型任一
revision 都会向依赖 selector 的作用域传播“可能变化”。显式策略重载会在 Store 提交时计算纯 selector；结果与
缓存等价时不推进 selector revision、不通知也不重建无关作用域。便宜字段或小元组通常适合结构等价；昂贵筛选应
先缩小模型边界或建立可复用的缓存派生。selector 和策略都必须确定且无副作用。

## 特征 scope

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

`state` 还可传 [`Lens`](Lens.md)`<Model, LocalModel>`，并有相同的策略重载。scope 把根 Store 变成只认识局部模型和
局部 Action 的 [`ScopedStore`](ScopedStore.md)：子视图不再携带根类型，局部 Action 经 `action` 提升后仍由同一个
根 reducer 解释。它不复制状态，也不开放局部 setter。

默认 scope 完全惰性；根模型任一 revision 都会传播“可能变化”。字段、小值对象等有便宜等价关系时传显式策略，
无关根 Action 就不会推进局部 revision 或重建读取该 scope 的界面分支。嵌套 scope 会组合状态投影和 Action 提升；
无策略状态投影融合为一个 Derived 节点，显式策略则保留为不可跨越的商边界。`dispatchAll` 直接融合到一次根事务，
不创建逐层中间 Action 数组。

[`FeaturePath`](FeaturePath.md) 重载从同一个值取得状态 Lens 与 Action Prism 的嵌入方向；它还提供带 `policy` 的重载。
同一路径可先用于局部 reducer 的 `pullback`，再用于根 Store 的 `scope`，消除两处闭包不一致的可能。

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

为输入控件创建 action-driven Binding：读取和观察来自模型投影，写入值先转换成 Action 再经过 reducer。
`Binding.update` 在一个根模型快照上计算焦点变化并只执行一次 reducer，不开放绕过 Action 的根模型 setter。
策略重载把读取投影与结果等价关系融合为一个商节点；无关 Action 不推进 Binding revision 或通知控件，但写入仍始终
派发 Action，绝不会因观察等价而绕过或吞掉 reducer。

## 另请参阅

- [`Reducer`](Reducer.md) — 纯更新、顺序组合与特征 pullback。
- [`FeaturePath`](FeaturePath.md) — reducer 与 Store 共用的特征边界。
- [`ScopedStore`](ScopedStore.md) — 隐藏根类型的特征局部门面与嵌套组合。
- [模型、动作与界面边界](../../../guide/concepts/app-architecture.md) — 何时采用 store，何时保留局部 `rememberState`。
