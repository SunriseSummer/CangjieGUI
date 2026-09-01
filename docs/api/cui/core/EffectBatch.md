[cui](../../index.md) › [cui.core](index.md) › EffectBatch

# EffectBatch

`cui.core` 包中的 public struct

不可变、有序的领域效果描述批次。它不执行文件、网络、线程或计时工作；应用基础设施通过 [`forEach`](#foreach)
解释这些普通值。

```cangjie
public struct EffectBatch<Effect>
```

## 构造

```cangjie
public init()
public init(effect: Effect)
public init(effects: Array<Effect>)
```

数组构造会快照输入；之后修改调用方数组不改变批次。空构造是 [`then`](#then) 的单位元。

## 成员

```cangjie
public prop size: Int64
public func isEmpty(): Bool
public func then(next: EffectBatch<Effect>): EffectBatch<Effect>
public func forEach(visit: (Effect) -> Unit): Unit
public func toArray(): Array<Effect>
public func map<Mapped>(transform: (Effect) -> Mapped): EffectBatch<Mapped>
```

### then

按 `this` 后接 `next` 的顺序组合，复杂度为 O(1)。实现保存持久引用拼接树；空批次直接返回另一侧，不分配拼接节点。
组合满足结合律，但 `Effect` 的解释器仍应按顺序执行。

### forEach

以显式工作栈按声明顺序访问每个效果，深拼接不会递归耗尽调用栈。回调抛错时立即停止，其余效果尚未被解释。

### toArray / map

`toArray` 返回独立有序数组。`map` 保持顺序并转换效果空间，供 [`EffectReducer.pullback`](EffectReducer.md#pullback)
把特征效果提升为根效果。

## 另请参阅

- [`Transition`](Transition.md) — 模型端态与效果批次的乘积。
- [`EffectStore`](EffectStore.md) — 提交模型后交付批次。
