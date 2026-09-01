[cui](../../index.md) › [cui.core](index.md) › Prism

# Prism

`cui.core` 包中的 public struct

从和类型 `S` 的一个分支到载荷 `A` 的可组合光学结构。`extract` 只在源值属于该分支时返回载荷，`embed` 总能从载荷
构造分支；它是枚举/领域 Action 相对于记录字段 [`Lens`](Lens.md) 的对偶。

```cangjie
public struct Prism<S, A>
```

## 定律

良好 Prism 至少满足：

- Embed-Extract：`extract(embed(a)) == Some(a)`。
- Match-Embed：若 `extract(s) == Some(a)`，则 `embed(a) == s`。

框架不要求 `S`/`A` 实现 `Equatable`，因此自定义 Prism 应在模型测试中验证定律。`then` 保持良好 Prism 的定律。
测试可用 [`checkPrismLaws`](../testing/functions.md#checkprismlaws) 分别提供命中/未命中的 source 和 payload witness；
结果逐项区分两个往返，有限样本只用于寻找反例。

## 构造

```cangjie
public init(extract!: (S) -> ?A, embed!: (A) -> S)
```

## 方法

### extract

```cangjie
public func extract(source: S): ?A
```

源值属于目标分支时返回载荷，否则返回 `None`。

### embed

```cangjie
public func embed(value: A): S
```

从载荷构造目标分支。

### then

```cangjie
public func then<B>(next: Prism<A, B>): Prism<S, B>
```

组合嵌套分支：提取按外到内短路，嵌入按内到外构造。

## 示例

```cangjie
let profileAction = Prism<AppAction, ProfileAction>(
    extract: {action => action.profile},
    embed: {action => AppAction(profile: Some(action))}
)
```

## 另请参阅

- [`FeaturePath`](FeaturePath.md) — 把 Action Prism 与状态 Lens 绑定成可复用特征边界。
- [`Reducer`](Reducer.md) — 使用 Prism 组合可选和重复子特征。
