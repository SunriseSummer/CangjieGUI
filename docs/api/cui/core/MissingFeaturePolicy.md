[cui](../../index.md) › [cui.core](index.md) › MissingFeaturePolicy

# MissingFeaturePolicy

`cui.core` 包中的 public enum

当子 Action 到达时，可选子状态已是 `None`、keyed 元素或正规化实体已经删除，决定 reducer 的处理方式。

```cangjie
public enum MissingFeaturePolicy {
    | Reject
    | Ignore
}
```

- `Reject`：默认值，抛 `IllegalStateException`，使生命周期、取消或 Action 路由错误立即可见；父 reducer 不运行。
- `Ignore`：子 reducer 不运行、不产生效果，父 reducer 仍可处理同一个根 Action。只用于确认允许迟到的异步结果、
  取消竞态或幂等删除等领域语义。

显式 Ignore 是 Option 函子把 `None` 保持为 `None` 的普通映射；默认 Reject 在其外增加诊断守卫。不要用 Ignore 掩盖
错误 ID、提前关闭或未取消的长期任务。

## 另请参阅

- [`Reducer`](Reducer.md#ifpresent) — 可选与 keyed 特征组合。
- [`EffectReducer`](EffectReducer.md#ifpresent) — 带效果的相同边界。
