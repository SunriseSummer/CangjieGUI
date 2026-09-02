[cui](../../index.md) › [cui.core](index.md) › FeaturePath

# FeaturePath

位于 `cui.core` 包的公开结构体

把根状态到特征状态的总 [`Lens`](Lens.md) 与根 Action 对应分支的 [`Prism`](Prism.md) 保存为一个可组合边界。
Reducer 用 Lens 的读写和 Prism 的提取进行 pullback；Store 用 Lens 的读取和 Prism 的嵌入建立局部门面。两侧复用同一个
值，避免分别手写的闭包悄悄指向不同 Action 分支。

```cangjie
public struct FeaturePath<RootModel, RootAction, Model, Action>
```

## 字段与构造

```cangjie
public let state: Lens<RootModel, Model>
public let action: Prism<RootAction, Action>

public init(
    state!: Lens<RootModel, Model>,
    action!: Prism<RootAction, Action>
)
```

## then

```cangjie
public func then<ChildModel, ChildAction>(
    next: FeaturePath<Model, Action, ChildModel, ChildAction>
): FeaturePath<RootModel, RootAction, ChildModel, ChildAction>
```

同时组合状态 Lens 与 Action Prism。合法路径的组合满足结合律，深层特征不需要重新编写根类型路由。

## 使用方式

用指向局部模型的 Lens 和指向局部 Action 分支的 Prism 创建路径。随后把同一个路径传给 reducer 的 `pullback` 和
Store 的 `scope`，即可保证两侧使用一致的状态与动作边界。

`FeaturePath` 适用于状态必然存在的特征。状态本身可缺失或按稳定 ID 重复时，分别使用
[`Reducer.ifPresent`](Reducer.md#ifpresent) 或 [`Reducer.forEach`](Reducer.md#foreach)，并把 Action Prism 直接传给
它们。

## 另请参阅

- [`Prism`](Prism.md) — 和类型分支的提取与嵌入。
- [`ModelStore`](ModelStore.md#特征-scope) 与 [`ScopedStore`](ScopedStore.md#继续聚焦) — 运行时特征聚焦。
