[cui](../../index.md) › [cui.core](index.md) › StateMutationPolicy

# StateMutationPolicy

`cui.core` 包中的 public interface

定义值空间上的观察等价关系，可用于 [`State`](State.md) 赋值/完整事务，也可用于
[`DerivedState`](DerivedState.md) 与 [`ModelStore.select`](ModelStore.md) 的结果传播。State 单次赋值返回 `true`
时跳过存储替换、revision、通知与界面失效；事务首尾返回 `true` 时，中间 revision 保留但提交不通知。派生结果
返回 `true` 时不替换当前缓存代表元、不推进派生 revision，也不传播下游失效。

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

沿纯投影取得当前等价关系在 `S` 上的逆像：两个 `S` 值等价，当且仅当它们的投影结果按本策略等价。连续 pullback
等价于沿复合投影 pullback；投影或底层比较抛出的异常原样传播。

## 内置策略

- [`structuralEqualityPolicy<T>()`](functions.md#structuralequalitypolicy)：以 `==` 抑制相等写入，要求 `T <: Equatable<T>`。
- [`neverEqualPolicy<T>()`](functions.md#neverequalpolicy)：接受每次赋值，与 `State(value)` 默认行为一致。

不适合或不值得为单个策略声明新类型时，可用 [`stateMutationPolicy`](functions.md#statemutationpolicy) 从闭包创建：

```cangjie
let sameSelection = stateMutationPolicy<Selection>({previous, current => previous.id == current.id})
let selected = rememberState<Selection>(sameSelection) {initialSelection}
```

已有字段策略时可避免重复写双参数比较：

```cangjie
let sameSelection = structuralEqualityPolicy<String>()
    .pullback<Selection>({selection => selection.id})
```

比较函数应定义真正的等价关系（自反、对称、传递）。若只比较部分字段，被忽略字段的变化在观察意义上也会被丢弃；
需要保留候选值但只抑制某些通知时，应把模型拆成不同 State，而不是滥用策略。

自定义策略可在测试中用 [`checkStateMutationPolicyLaws`](../testing/functions.md#checkstatemutationpolicylaws) 检查三个代表值上的
重复性、自反、对称与全部传递蕴含；它提供反例搜索，不把有限样本包装成普遍证明。

用于派生节点时，策略只在节点拥有 retained/phase 依赖或显式观察者时把比较前移到上游通知边界；无人订阅时仍按
读取惰性计算。投影计算与比较失败都不提交派生 revision，后续读取或上游变化仍会重试。

## 显式诊断

需要验证策略是否“比较得够便宜、抑制得够多”时，可用
[`diagnoseStateMutationPolicy`](functions.md#diagnosestatemutationpolicy) 包装目标策略，再从
[`DiagnosedStateMutationPolicy`](DiagnosedStateMutationPolicy.md) 取得不可变
[`StateMutationPolicyDiagnostics`](StateMutationPolicyDiagnostics.md) 快照或重置统计。包装器记录比较、等价/不同结果、失败、
累计耗时与最大耗时；比较失败仍原样抛出。

诊断完全 opt-in：未包装的默认 State、selector、Binding 与派生路径不增加字段、分支或时钟读取。它适合开发期剖析和
针对性运行时采样，不应无差别包装所有策略。

## 事务端点

[`DesktopApp.batch`](../desktop/DesktopApp.md#batch)、事件回调和 `post` 都是原子事务。框架把同一 State 的写入路径
投影到策略定义的等价类：`A → B → A` 的两端等价时不向观察者暴露中间游程，也不让调度器产生空帧。只有一次
有效写入时，setter 已证明两端不等价，提交直接复用该证明；写入两次以上才重新比较首尾。比较在提交期失败时，
已发生的写入不会回滚，框架会保守请求一帧并把异常交还调用方。
