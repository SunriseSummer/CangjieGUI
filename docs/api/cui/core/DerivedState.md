[cui](../../index.md) › [cui.core](index.md) › DerivedState

# DerivedState

`cui.core` 包中的 public class

由一个或多个源计算出的只读可观察状态，用 [`derive`](functions.md#derive)、[`deriveStates`](functions.md#derivestates) 或 [`Observable.map`](Observable.md#map) 创建。求值惰性且带缓存：仅当某个源的修订号在两次读取之间变化才重新计算。没有公开构造函数。

## 声明

```cangjie
public open class DerivedState<T> <: Observable<T>
```

## 继承

- 实现 [`Observable`](Observable.md)`<T>`（只读，无 `value` 赋值）。

类型为 `open` 仅供内核的结果等价专用实现复用缓存协议；构造函数仍为包内可见，应用不能自行构造或继承。

## 说明

派生遵循拉取模型，与可重复执行或 retained 命中的声明式 UI 匹配。由内置 `State`、`Binding` 和 `DerivedState` 组成的图先用 State 写入 epoch 证明“自上次读取后没有任何 State 写入”；证明成立时缓存命中为常数时间，epoch 变化才比较完整源 revision 向量。自定义 `Observable` 没有这项内部能力时始终逐源比较，不牺牲兼容正确性。

框架依赖收集把稳定 `DerivedState` 当作一等惰性节点：作用域只提交一条到该节点的边，节点在边存续期间向声明源订阅“已失效”，上游变化只标脏作用域，不执行 `compute`；下一次真正读取才求值。嵌套派生沿失效边递归连接，自定义 `Observable` 通过其 `observe` 协议加入。若派生是在正在执行的 build/phase 内临时创建，State-backed 节点改用直接源边，使下一次重建可按 State identity 复用既有订阅，而不会围绕短命派生对象每帧拆装整组监听器。这个自适应差异对应用透明，缓存和失效语义相同。

需要在 build 中声明、但希望跨重建保留的派生可放进 [`remember`](functions.md#remember)。remember 工厂内创建的
派生被内核识别为长期节点，因此保持单聚合边与惰性计算，不需要把对象手工提升到页面模型字段；动态源拓扑应让
显式 remember key 随拓扑版本变化，或重建对应 `Keyed` 子树。

数组重载在创建时快照源数组，形成固定的依赖积；之后修改调用方数组不会偷偷改写既有派生的依赖拓扑。需要换源时应创建新的 `DerivedState`。推送式的 [`observe`](#observe) 只在返回的观察句柄存续期间连接失效边，关闭时以逆序清理全部上游；中途连接失败会回滚已连接的边。同一个调度事务修改多个源时，观察回调推迟到所有源通知稳定后并去重，只看到事务最终组合值。每个 observation 持有一个稳定、不可变的 deferred continuation，事务队列只引用它，不为每次失效重新创建 action。

固定重载接受一至五个不同类型的源，并始终生成一个融合节点；四/五源表单或视图模型不需要先构造中间派生。
动态数量入口使用同类型数组，因为当前仓颉没有可用于公开 API 的可变泛型参数包。超过五个异构事实时优先把强相关事实
建模为一个领域值；不要为了绕过元数机械制造深层派生链。

固定一至五源都可在 `derive` 调用中传命名 `policy:`，直接生成带结果等价关系的融合节点。它与先
`derive(...).distinct(policy)` 的可观察结果相同，但不创建第二份派生 identity、revision tracker 或失效转发边。已有
派生和动态数组仍可调用 `.distinct(policy)`。

默认节点只传播“上游可能变化”，保持完全惰性。通过 `Observable.map(..., policy:)` 创建或调用 [`distinct`](#distinct)
得到的节点把结果空间投影到策略定义的等价类：没有订阅者时仍完全惰性；存在 retained/phase 依赖或显式观察者时，
上游提交会计算一次纯投影，只有结果跨越等价类才推进本节点 revision 并向下游传播。等价候选不会替换当前缓存代表元。
这适合从较大模型选择便宜字段；昂贵投影应先拆细源或先做可复用的缓存派生，避免把重计算成本搬到每次上游提交。

全 State-backed 数组派生的第一次求值把 revision 与 value 合并为一次源序遍历；直接 State 还能在一次线程归属/依赖检查后返回同一时刻的 `(value, revision)`。`deriveStates` 为 `Array<State<T>>` 保留静态专用路径；`Array<Observable<T>>` 在运行时全为 State 时也会在构造时自动正规化到同一路径。采样前的 State 写入 epoch 与逐源 revision 共同构成计算前像，只有 `compute` 成功才提交；计算或 getter 内发生的写入仍会使下一次读取重算。含自定义 `Observable` 的数组继续保持“先采全部 revision、再读全部 value”的兼容顺序。

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let done = State<Int64>(3)
    let total = State<Int64>(8)
    let summary: DerivedState<String> = derive(done, total, {d, t => "${d}/${t} 已完成"})
    done.value = 4 // 上游状态变化后，下次读取才重新计算
    println(summary.value)
    // 输出: 4/8 已完成
}
```

## 成员概览

**属性**

| 成员 | 说明 |
|---|---|
| [`value`](#value) | 计算值；任一上游状态在上次读取后变化时，先重新计算。 |
| [`revision`](#revision) | 本派生状态自身的修订号，读取时先按源刷新。 |

**方法**

| 成员 | 说明 |
|---|---|
| [`get()`](#get) | 读取当前值，等价于读 `value`。 |
| [`observe(callback: (T, T) -> Unit)`](#observe) | 观察后续变更，返回可取消的观察句柄。 |
| [`distinct(policy: StateMutationPolicy<T>)`](#distinct) | 只在结果跨越观察等价类时传播变化。 |

## 属性

### value

计算值；任一上游状态在上次读取后变化时，先重新计算。只读；上游状态未变化时直接返回缓存，不重复执行计算闭包。计算抛出异常时不提交捕获的源 revision，后续读取仍会重试；计算期间源发生写入时，下一次读取会再次刷新。

```cangjie
public prop value: T
```

**返回值** `T` — 最新计算结果。

### revision

本派生状态自身的修订号，读取时先按源刷新。只读；普通节点在计算结果真正重算后递增，带等价策略的节点只在结果
跨越等价类时递增。

```cangjie
public prop revision: UInt64
```

**返回值** `UInt64` — 修订号。

## 方法

### get

读取当前值，等价于读 `value`。

```cangjie
public func get(): T
```

**返回值** `T` — 最新计算结果。

### observe

观察后续变更，返回可取消的观察句柄。回调收到 `(旧值, 新值)`；对各源的订阅和稳定 deferred continuation
只维持到观察句柄关闭。一个事务中重复失效按 observation identity 去重；回调重入写源时，同一 continuation
可在当前派发完成后再次进入工作表。

```cangjie
public func observe(callback: (T, T) -> Unit): StateObservation<T>
```

**参数**

- `callback`: `(T, T) -> Unit` — 任一上游状态变化后执行，参数为重新计算前后的结果。

**返回值** [`StateObservation`](StateObservation.md)`<T>` — 调用其 `close()` 同时取消对全部源的订阅。

### distinct

```cangjie
public func distinct(policy: StateMutationPolicy<T>): DerivedState<T>
```

在当前派生图外增加一个观察商节点。`policy` 必须快速、确定、无副作用并满足等价关系；等价的新结果不替换缓存、
不推进 revision、不调用观察者，也不把 retained scope 标脏。已有单源投影优先直接使用 `map(transform, policy:)`，
可少一个节点；`distinct` 适合过滤已经组合好的多源派生图。

## 另请参阅

- [derive](functions.md#derive) — 一至五个异构源、对应融合策略或同类型动态源的兼容派生入口（十一重载）。
- [deriveStates](functions.md#derivestates) — `Array<State<T>>` 的静态专用入口。
- [remember](functions.md#remember) — 在声明式 build 中保留稳定派生身份。
- [Observable.map](Observable.md#map) — 单源派生的便捷形式。
- [StateMutationPolicy](StateMutationPolicy.md) — 定义结果的观察等价类。
- [State](State.md) — 可写的源状态。
