[cui](../../index.md) › [cui.core](index.md) › Transition

# Transition

位于 `cui.core` 包的公开结构体

一次纯归约的完整结果：下一个模型与稍后解释的有序 [`EffectBatch`](EffectBatch.md)。构造 Transition 不执行效果。

```cangjie
public struct Transition<Model, Effect> {
    public let model: Model
    public let effects: EffectBatch<Effect>
}
```

## 构造

```cangjie
public init(model: Model)
public init(model: Model, effect!: Effect)
public init(model: Model, effects!: EffectBatch<Effect>)
```

第一个重载表示没有外部工作，第二个表示一个效果，第三个复用已有批次。

## mapEffects

```cangjie
public func mapEffects<Mapped>(
    transform: (Effect) -> Mapped
): Transition<Model, Mapped>
```

保持模型与效果顺序，只转换效果描述。转换失败时原 Transition 不变。

## 另请参阅

- [`EffectReducer`](EffectReducer.md) — 产生 Transition 的纯 reducer。
- [`EffectStore`](EffectStore.md) — 原子提交 Transition 的模型部分。
