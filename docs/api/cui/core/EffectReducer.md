[cui](../../index.md) › [cui.core](index.md) › EffectReducer

# EffectReducer

`cui.core` 包中的 public class

把 `Action` 纯解释为 [`Transition<Model, Effect>`](Transition.md)：既计算下一模型，也返回惰性的领域效果描述。
Reducer 本身不能读文件、取时钟、生成随机数、启动任务或修改外部对象。

```cangjie
public class EffectReducer<Model, Action, Effect>
```

## 构造与归约

```cangjie
public init(update: (Model, Action) -> Transition<Model, Effect>)
public func reduce(model: Model, action: Action): Transition<Model, Effect>
```

归约失败时调用方得不到部分 Transition；[`EffectStore`](EffectStore.md) 不提交模型，也不交付此前构造的效果。

## then

```cangjie
public func then(
    next: EffectReducer<Model, Action, Effect>
): EffectReducer<Model, Action, Effect>
```

同一 Action 先经过当前 reducer，再把模型交给 `next`；效果按当前、`next` 的顺序 O(1) 拼接。纯 reducer 下组合满足
结合律。

## concat

```cangjie
public static func concat(
    values: Array<EffectReducer<Model, Action, Effect>>
): EffectReducer<Model, Action, Effect>
```

把运行时集合组合成同一个有序模型/效果归约。空积返回原模型与空效果；少于 1024 项线性，更宽集合平衡括号。模型端态、
效果遍历顺序和首错短路均与逐项 `then` 相同。

## pullback

```cangjie
public func pullback<RootModel, RootAction, RootEffect>(
    state!: Lens<RootModel, Model>,
    action!: (RootAction) -> ?Action,
    effect!: (Effect) -> RootEffect
): EffectReducer<RootModel, RootAction, RootEffect>

public func pullback<RootModel, RootAction, RootEffect>(
    path: FeaturePath<RootModel, RootAction, Model, Action>,
    effect!: (Effect) -> RootEffect
): EffectReducer<RootModel, RootAction, RootEffect>
```

通过合法 Lens 提升模型，通过可选 Action 投影路由动作，并把特征效果映射到根效果空间。未命中 Action 是模型恒等、
空效果的 Transition。`FeaturePath` 重载让 Effect reducer 与 Store 复用同一个状态/Action 边界。组合 Lens 的模型
读取与重建保持线性遍历，不会重复展开每个前缀。

## ifPresent

```cangjie
public func ifPresent<ChildModel, ChildAction, ChildEffect>(
    state!: Lens<Model, ?ChildModel>,
    action!: (Action) -> ?ChildAction,
    child!: EffectReducer<ChildModel, ChildAction, ChildEffect>,
    effect!: (ChildEffect) -> Effect,
    missing!: MissingFeaturePolicy = MissingFeaturePolicy.Reject
): EffectReducer<Model, Action, Effect>
```

`action` 也可传 `Prism<Action, ChildAction>`。

先运行可选 child，再运行 parent；child 效果先映射到根效果空间并排在 parent 效果之前。缺失状态默认拒绝且 parent
不运行、不产生效果；显式 Ignore 时 child 是模型恒等与空效果，parent 仍处理根 Action。

## forEach

```cangjie
public func forEach<ID, ChildModel, ChildAction, ChildEffect>(
    state!: Lens<Model, IdentifiedArray<ID, ChildModel>>,
    action!: (Action) -> ?IdentifiedAction<ID, ChildAction>,
    child!: EffectReducer<ChildModel, ChildAction, ChildEffect>,
    effect!: (ChildEffect) -> Effect,
    missing!: MissingFeaturePolicy = MissingFeaturePolicy.Reject
): EffectReducer<Model, Action, Effect>
    where ID <: Hashable & Equatable<ID>
```

`action` 也可传 `Prism<Action, IdentifiedAction<ID, ChildAction>>`。

按稳定 ID 运行一个集合元素的 child reducer，随后运行 parent，效果顺序固定为 child→parent。独立容器 lift 使用
[`identifiedReducer`](functions.md#identifiedreducer) 的 EffectReducer 重载。

## forEachBatch

```cangjie
public func forEachBatch<ID, ChildModel, ChildAction, ChildEffect>(
    state!: Lens<Model, IdentifiedArray<ID, ChildModel>>,
    action!: (Action) -> ?Array<IdentifiedAction<ID, ChildAction>>,
    child!: EffectReducer<ChildModel, ChildAction, ChildEffect>,
    effect!: (ChildEffect) -> Effect,
    missing!: MissingFeaturePolicy = MissingFeaturePolicy.Reject
): EffectReducer<Model, Action, Effect>
    where ID <: Hashable & Equatable<ID>
```

`action` 也可传 Prism。所有 child Action 先按数组顺序更新稳定 ID 集合并连接 child effects，parent 随后运行一次，
所以 parent effect 位于全部 child effects 之后。Reject 或 child 失败不会返回部分 Transition；Ignore 只跳过缺失项。

## forEntity

```cangjie
public func forEntity<ID, ChildModel, ChildAction, ChildEffect>(
    state!: Lens<Model, EntityTable<ID, ChildModel>>,
    action!: (Action) -> ?IdentifiedAction<ID, ChildAction>,
    child!: EffectReducer<ChildModel, ChildAction, ChildEffect>,
    effect!: (ChildEffect) -> Effect,
    missing!: MissingFeaturePolicy = MissingFeaturePolicy.Reject
): EffectReducer<Model, Action, Effect>
    where ID <: Hashable & Equatable<ID>
```

`action` 也可传 Prism。目标实体先归约并产生 child 效果，parent 随后看到新实体版本；效果顺序固定为 child→parent。
缺失实体默认拒绝且 parent 不运行，显式 Ignore 才允许 parent 继续。

## forEntities

```cangjie
public func forEntities<ID, ChildModel, ChildAction, ChildEffect>(
    state!: Lens<Model, EntityTable<ID, ChildModel>>,
    action!: (Action) -> ?Array<IdentifiedAction<ID, ChildAction>>,
    child!: EffectReducer<ChildModel, ChildAction, ChildEffect>,
    effect!: (ChildEffect) -> Effect,
    missing!: MissingFeaturePolicy = MissingFeaturePolicy.Reject
): EffectReducer<Model, Action, Effect>
    where ID <: Hashable & Equatable<ID>
```

`action` 也可传 Prism。完整 child Action 批次先更新实体并按 Action 顺序连接全部 child effects，随后 parent 只运行
一次；parent effect 因而位于所有 child effects 之后。Reject、child 异常或 ID 改变都不会返回部分 Transition；
Ignore 只跳过缺失实体。

## 另请参阅

- [`Reducer.withEffects`](Reducer.md#witheffects) — 把无效果 reducer 提升到本类型。
- [`EffectStore`](EffectStore.md) — 状态所有者与效果交付边界。
- [`IdentifiedArray`](IdentifiedArray.md) — 保持稳定身份和持久版本的有序集合。
- [`FeaturePath`](FeaturePath.md) — 同时组合状态 Lens 与 Action Prism。
- [`EntityTable`](EntityTable.md) — 正规化实体的持久哈希目录。
