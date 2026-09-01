[cui](../../index.md) › [cui.core](index.md) › DiagnosedStateMutationPolicy

# DiagnosedStateMutationPolicy

`cui.core` 包中的 public class

在不改变目标策略判断结果的前提下，显式记录比较次数、抑制收益、失败和耗时。通过
[`diagnoseStateMutationPolicy`](functions.md#diagnosestatemutationpolicy) 创建；未包装的默认 State、selector、Binding 和派生
节点没有计数器、时钟读取或诊断分支。

## 声明

```cangjie
public class DiagnosedStateMutationPolicy<T> <: StateMutationPolicy<T>
```

## 方法

### equivalent

```cangjie
public func equivalent(previous: T, current: T): Bool
```

调用被包装策略并记录结果与耗时。目标比较抛出异常时，包装器记录失败和耗时后原样重抛，不把失败改成等价或不同。

### diagnostics

```cangjie
public func diagnostics(): StateMutationPolicyDiagnostics
```

返回当前不可变快照，不清空累计值。

### resetDiagnostics

```cangjie
public func resetDiagnostics(): Unit
```

只清空诊断计数与耗时；被包装策略以及已经使用它的 State/派生节点保持不变。

## 示例

```cangjie
let policy = diagnoseStateMutationPolicy<Int64>(structuralEqualityPolicy<Int64>())
let page = State<Int64>(1, policy: policy)

page.value = 1
let snapshot = policy.diagnostics()
// snapshot.comparisons == 1
// snapshot.equivalentResults == 1
```

状态策略应在桌面 UI 线程使用；诊断计数也遵循同一线程封闭约束，不是跨线程聚合器。
