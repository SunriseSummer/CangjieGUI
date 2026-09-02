[cui](../../index.md) › [cui.core](index.md) › StateMutationPolicy

# StateMutationPolicy

位于 `cui.core` 包的公开接口

决定两个值在界面更新中是否可视为相同。它可用于 [`State`](State.md)、[`DerivedState`](DerivedState.md) 和
[`ModelStore.select`](ModelStore.md)。`equivalent` 返回 `true` 时，框架不会传播这次变化；用于 `State` 单次赋值时，
也不会替换已保存的值或增加版本号。

同一事务多次写入一个 `State` 时，框架在提交前比较事务开始值和结束值。两端等价就不通知观察者，但事务中已经发生的
中间版本变化不会倒退。

## 声明

```cangjie
public interface StateMutationPolicy<T>
```

## 方法

### equivalent

```cangjie
func equivalent(previous: T, current: T): Bool
```

比较已存值与候选值。实现应快速、确定且无副作用；它是状态变化的等价关系，不是业务校验器。

### pullback

```cangjie
func pullback<S>(project: (S) -> T): StateMutationPolicy<S>
```

把当前策略应用到 `S` 的投影结果。两个 `S` 值的投影结果等价时，新策略就认为它们等价。投影函数和底层比较函数中的
异常会原样传播。

## 内置策略

- [`structuralEqualityPolicy<T>()`](functions.md#structuralequalitypolicy)：以 `==` 抑制相等写入，要求 `T <: Equatable<T>`。
- [`neverEqualPolicy<T>()`](functions.md#neverequalpolicy)：接受每次赋值，与 `State(value)` 默认行为一致。

不值得为单个策略声明新类型时，可用 [`stateMutationPolicy`](functions.md#statemutationpolicy) 从闭包创建。例如，
`Selection` 可以只比较 `id`，再把策略传给 `rememberState`。如果已有字符串相等策略，也可以通过 `pullback` 将它应用到
`Selection.id`。

比较函数应定义真正的等价关系（自反、对称、传递）。若只比较部分字段，被忽略字段的变化在观察意义上也会被丢弃；
需要保留候选值但只抑制某些通知时，应把模型拆成不同 State，而不是滥用策略。

自定义策略可用 [`checkStateMutationPolicyLaws`](../testing/functions.md#checkstatemutationpolicylaws) 检查一组代表值上的
确定性、自反性、对称性和传递性。有限样本只能帮助发现问题。

用于派生状态时，有观察者或界面依赖的节点会在上游通知到达时比较结果；无人使用的节点仍在下次读取时才计算。投影或
比较失败不会提交新版本，后续读取或上游变化时可以重试。

## 显式诊断

需要验证策略是否“比较得够便宜、抑制得够多”时，可用
[`diagnoseStateMutationPolicy`](functions.md#diagnosestatemutationpolicy) 包装目标策略，再从
[`DiagnosedStateMutationPolicy`](DiagnosedStateMutationPolicy.md) 取得不可变
[`StateMutationPolicyDiagnostics`](StateMutationPolicyDiagnostics.md) 快照或重置统计。包装器记录比较、等价/不同结果、失败、
累计耗时与最大耗时；比较失败仍原样抛出。

诊断只在显式包装后启用，不会增加其他状态、选择器、Binding 或派生路径的运行成本。它适合开发期分析和定点采样，
不应无差别包装所有策略。

## 事务端点

[`DesktopApp.batch`](../desktop/DesktopApp.md#batch)、事件回调和 `post` 都会形成一次事务。例如
`A → B → A` 的开始值与结束值等价，观察者不会看到中间值，调度器也不会安排空帧。提交时比较失败不会回滚已经写入的值；
框架会保守地请求一帧，并把异常交还调用方。
