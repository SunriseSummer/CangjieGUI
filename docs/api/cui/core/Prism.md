[cui](../../index.md) › [cui.core](index.md) › Prism

# Prism

位于 `cui.core` 包的公开结构体

描述枚举或领域 Action 的某个分支。`extract` 在源值属于目标分支时取出其中的数据，`embed` 用数据构造该分支。
`then` 可继续组合嵌套分支；记录或模型字段使用 [`Lens`](Lens.md)。

```cangjie
public struct Prism<S, A>
```

## 定律

良好 Prism 至少满足：

- Embed-Extract：`extract(embed(a)) == Some(a)`。
- Match-Embed：若 `extract(s) == Some(a)`，则 `embed(a) == s`。

框架不要求 `S`/`A` 实现 `Equatable`，因此自定义 Prism 应在模型测试中验证定律。`then` 保持良好 Prism 的定律。
测试可用 [`checkPrismLaws`](../testing/functions.md#checkprismlaws) 分别提供命中值、未命中值和分支数据。结果会逐项检查
两个往返关系；有限样本只能帮助发现反例。

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

## 使用方式

为 `AppAction` 的资料分支创建 Prism 时，`extract` 在命中后返回 `ProfileAction`，`embed` 把
`ProfileAction` 重新包装成 `AppAction`。同一个 Prism 可由 Reducer 和 `FeaturePath` 复用。

## 另请参阅

- [`FeaturePath`](FeaturePath.md) — 把 Action Prism 与状态 Lens 绑定成可复用特征边界。
- [`Reducer`](Reducer.md) — 使用 Prism 组合可选和重复子特征。
