[cui](../../index.md) › [cui.core](index.md) › Reducer

# Reducer

`cui.core` 包中的 public class

把强类型 `Action` 纯解释为模型端态变换。Reducer 只依赖传入的模型与动作，不执行文件、网络、时钟、随机数或
其他外部副作用；外部结果应稍后作为新 Action 回到 UI 线程。

```cangjie
public class Reducer<Model, Action>
```

## 构造

```cangjie
public init(update: (Model, Action) -> Model)
```

## 方法

### reduce

```cangjie
public func reduce(model: Model, action: Action): Model
```

从一个完整模型快照计算下一模型。抛异常时调用方不会得到部分结果；[`ModelStore`](ModelStore.md) 也不会提交。

### then

```cangjie
public func then(next: Reducer<Model, Action>): Reducer<Model, Action>
```

同一 Action 先经过当前 reducer，再把结果交给 `next`。组合满足结合律；若某一步抛异常，后续 reducer 不执行。

### concat

```cangjie
public static func concat(values: Array<Reducer<Model, Action>>): Reducer<Model, Action>
```

按数组顺序组合运行时 reducer 集合。空数组是模型恒等 reducer，单元素直接复用；少于 1024 项保持线性组合，更宽集合
才利用结合律平衡括号。任何 reducer 抛错都会立即停止，绝不执行顺序上更后的分支。

### pullback

```cangjie
public func pullback<RootModel, RootAction>(
    state!: Lens<RootModel, Model>,
    action!: (RootAction) -> ?Action
): Reducer<RootModel, RootAction>

public func pullback<RootModel, RootAction>(
    path: FeaturePath<RootModel, RootAction, Model, Action>
): Reducer<RootModel, RootAction>
```

通过合法 [`Lens`](Lens.md) 和根 Action 投影，把特征 reducer 提升到根模型。Action 投影返回 `None` 时根模型原样
返回；返回局部 Action 时只替换 Lens 焦点，根模型其余部分由 Lens 定律保证保留。优先复用
[`FeaturePath`](FeaturePath.md)，让 reducer 与 Store 使用同一个状态/Action 边界。命中 Action 时 reducer 作为焦点
endomorphism 经 `Lens.update` 一次提升；组合 Lens 每层只遍历一次。

### ifPresent

```cangjie
public func ifPresent<ChildModel, ChildAction>(
    state!: Lens<Model, ?ChildModel>,
    action!: (Action) -> ?ChildAction,
    child!: Reducer<ChildModel, ChildAction>,
    missing!: MissingFeaturePolicy = MissingFeaturePolicy.Reject
): Reducer<Model, Action>
```

`action` 也可传 [`Prism<Action, ChildAction>`](Prism.md)，从而复用同一 Action 分支的提取与嵌入。

把可选 child reducer 组合到当前 parent，固定执行顺序为 child→parent。这样父级在同一 Action 中把弹窗、详情或导航
状态设为 `None` 前，child 仍有最后一次处理机会。Action 命中但 state 已缺失时默认拒绝；确认允许迟到事件时显式传
[`MissingFeaturePolicy.Ignore`](MissingFeaturePolicy.md)。

### forEach

```cangjie
public func forEach<ID, ChildModel, ChildAction>(
    state!: Lens<Model, IdentifiedArray<ID, ChildModel>>,
    action!: (Action) -> ?IdentifiedAction<ID, ChildAction>,
    child!: Reducer<ChildModel, ChildAction>,
    missing!: MissingFeaturePolicy = MissingFeaturePolicy.Reject
): Reducer<Model, Action> where ID <: Hashable & Equatable<ID>
```

`action` 也可传 `Prism<Action, IdentifiedAction<ID, ChildAction>>`。

按稳定 ID 把 child reducer 组合到重复特征集合，同样固定 child→parent；父级可在看到 child 的最终模型后删除目标。
[`IdentifiedArray`](IdentifiedArray.md) 在构造时拒绝重复 ID，child 更新时禁止改变自己的 ID。需要先取得独立的
`Reducer<IdentifiedArray<...>, IdentifiedAction<...>>` 时使用 [`identifiedReducer`](functions.md#identifiedreducer)。

### forEachBatch

```cangjie
public func forEachBatch<ID, ChildModel, ChildAction>(
    state!: Lens<Model, IdentifiedArray<ID, ChildModel>>,
    action!: (Action) -> ?Array<IdentifiedAction<ID, ChildAction>>,
    child!: Reducer<ChildModel, ChildAction>,
    missing!: MissingFeaturePolicy = MissingFeaturePolicy.Reject
): Reducer<Model, Action> where ID <: Hashable & Equatable<ID>
```

`action` 也可传 `Prism<Action, Array<IdentifiedAction<ID, ChildAction>>>`。完整 child Action 数组先按序遍历稳定 ID
集合、产生至多一个集合版本，随后 parent 只运行一次并看到批末模型。遍历不改变显示顺序；重复 ID 保持非交换顺序。
独立集合 lift 使用 [`identifiedBatchReducer`](functions.md#identifiedbatchreducer)。

### forEntity

```cangjie
public func forEntity<ID, ChildModel, ChildAction>(
    state!: Lens<Model, EntityTable<ID, ChildModel>>,
    action!: (Action) -> ?IdentifiedAction<ID, ChildAction>,
    child!: Reducer<ChildModel, ChildAction>,
    missing!: MissingFeaturePolicy = MissingFeaturePolicy.Reject
): Reducer<Model, Action> where ID <: Hashable & Equatable<ID>
```

`action` 也可传 `Prism<Action, IdentifiedAction<ID, ChildAction>>`。它按 ID 更新正规化实体表中的一个 child，执行顺序仍为
child→parent；父 reducer 可以读取更新后的实体再删除关系或实体。独立 table lift 使用
[`entityReducer`](functions.md#entityreducer)。

### forEntities

```cangjie
public func forEntities<ID, ChildModel, ChildAction>(
    state!: Lens<Model, EntityTable<ID, ChildModel>>,
    action!: (Action) -> ?Array<IdentifiedAction<ID, ChildAction>>,
    child!: Reducer<ChildModel, ChildAction>,
    missing!: MissingFeaturePolicy = MissingFeaturePolicy.Reject
): Reducer<Model, Action> where ID <: Hashable & Equatable<ID>
```

`action` 也可传 `Prism<Action, Array<IdentifiedAction<ID, ChildAction>>>`。一个父 Action 中的完整实体批次先按序运行
child reducer、产生至多一个表版本，然后 parent 只运行一次并看到批末模型。重复 ID 保持非交换顺序；缺失默认使
整个组合失败并阻止 parent，Ignore 则逐项跳过。独立 table lift 使用
[`entityBatchReducer`](functions.md#entitybatchreducer)。

### optionalReducer

顶层 [`optionalReducer`](functions.md#optionalreducer) 把独立 child reducer 提升为 `Reducer<?Model, Action>`；
它因当前仓颉工具链对递归泛型成员单态化的限制而不是成员方法，语义与 `ifPresent` 使用的 lift 相同。

### withEffects

```cangjie
public func withEffects<Effect>(): EffectReducer<Model, Action, Effect>
```

把当前 reducer 提升为每次都产生空效果批次的 [`EffectReducer`](EffectReducer.md)。模型归约语义保持不变，便于把
已有纯特征与需要效果的 reducer 组合。

## 另请参阅

- [`ModelStore`](ModelStore.md) — reducer 的状态所有者与 action 入口。
- [`EffectReducer`](EffectReducer.md) — 同时返回惰性效果描述的纯 reducer。
- [`Lens`](Lens.md) — 特征模型到根模型的可组合投影。
- [`Prism`](Prism.md) 与 [`FeaturePath`](FeaturePath.md) — Action 分支和完整特征边界。
- [`IdentifiedArray`](IdentifiedArray.md) 与 [`IdentifiedAction`](IdentifiedAction.md) — 重复子特征的稳定身份。
- [`EntityTable`](EntityTable.md) — 无显示顺序的正规化实体状态。
