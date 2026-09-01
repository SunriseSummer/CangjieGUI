[cui](../../index.md) › [cui.core](index.md) › 函数

# 函数 — cui.core

`cui.core` 的包级函数：状态派生、声明式列表助手、虚拟化网格、构建与焦点协议工具。

### stateMutationPolicy

把一个等价比较闭包包装为 [`StateMutationPolicy`](StateMutationPolicy.md)。比较函数应快速、确定、无副作用，
并满足自反、对称、传递；它描述的是观察等价类，不是输入校验。

```cangjie
public func stateMutationPolicy<T>(equivalent: (T, T) -> Bool): StateMutationPolicy<T>
```

```cangjie
let byIdentity = stateMutationPolicy<Item>({previous, current => previous.id == current.id})
```

### structuralEqualityPolicy

返回以 `Equatable.==` 判定候选值是否等价的 [`StateMutationPolicy`](StateMutationPolicy.md)。用于长期跳过状态空写，比在每个调用点重复 `setIfChanged` 更不易遗漏。

```cangjie
public func structuralEqualityPolicy<T>(): StateMutationPolicy<T> where T <: Equatable<T>
```

```cangjie
let page = State<Int64>(1, policy: structuralEqualityPolicy<Int64>())
```

### neverEqualPolicy

返回把每次赋值都视为变化的策略，与 `State(value)` 的默认兼容行为一致。它主要用于要求显式注入策略的通用工厂。

```cangjie
public func neverEqualPolicy<T>(): StateMutationPolicy<T>
```

### diagnoseStateMutationPolicy

给一个状态等价策略增加显式诊断，返回可读取、重置不可变统计快照的包装器。包装器不改变比较结果；底层比较失败会先
计数和计时，再原样抛出。只有调用此函数并使用返回策略的路径才读取时钟和维护计数，普通策略保持零诊断开销。

```cangjie
public func diagnoseStateMutationPolicy<T>(
    policy: StateMutationPolicy<T>
): DiagnosedStateMutationPolicy<T>
```

```cangjie
let policy = diagnoseStateMutationPolicy<Int64>(structuralEqualityPolicy<Int64>())
let page = State<Int64>(1, policy: policy)
page.value = 1
let snapshot = policy.diagnostics()
```

### derive

返回从一到多个源计算出的只读派生状态。十一重载包含：一至五个可异构的固定源、这些固定源各自带命名
`policy:` 的融合结果商，以及同类型
`Observable` 的数组形态（源数量动态或超过固定元数时用——例如把一组逐项计数器聚合成总数）。固定四/五源仍只
创建一个融合派生节点，不需要嵌套中间 `DerivedState`。`compute` 按源序收到当前值。数组重载会在创建时快照源数组；
派生实例的依赖拓扑固定，之后修改调用方数组不改变它，需要换源时请创建新的派生实例。运行时全为 `State` 的擦除数组
会在构造时自动转入专用采样路径，已有调用无需迁移。数组结果需要商映射时在构造结果上调用 `.distinct(policy)`。

```cangjie
public func derive<A, T>(source: Observable<A>, compute: (A) -> T): DerivedState<T>
```

```cangjie
public func derive<A, B, T>(first: Observable<A>, second: Observable<B>, compute: (A, B) -> T): DerivedState<T>
```

```cangjie
public func derive<A, B, C, T>(
    first: Observable<A>,
    second: Observable<B>,
    third: Observable<C>,
    compute: (A, B, C) -> T
): DerivedState<T>
```

```cangjie
public func derive<A, B, C, D, T>(
    first: Observable<A>,
    second: Observable<B>,
    third: Observable<C>,
    fourth: Observable<D>,
    compute: (A, B, C, D) -> T
): DerivedState<T>
```

```cangjie
public func derive<A, B, C, D, E, T>(
    first: Observable<A>,
    second: Observable<B>,
    third: Observable<C>,
    fourth: Observable<D>,
    fifth: Observable<E>,
    compute: (A, B, C, D, E) -> T
): DerivedState<T>
```

```cangjie
public func derive<A, T>(sources: Array<Observable<A>>, compute: (Array<A>) -> T): DerivedState<T>
```

固定一至五源另有以下融合策略重载（中间元数遵循相同参数顺序）：

```cangjie
public func derive<A, T>(
    source: Observable<A>,
    compute: (A) -> T,
    policy!: StateMutationPolicy<T>
): DerivedState<T>

public func derive<A, B, T>(
    first: Observable<A>,
    second: Observable<B>,
    compute: (A, B) -> T,
    policy!: StateMutationPolicy<T>
): DerivedState<T>

public func derive<A, B, C, T>(
    first: Observable<A>,
    second: Observable<B>,
    third: Observable<C>,
    compute: (A, B, C) -> T,
    policy!: StateMutationPolicy<T>
): DerivedState<T>

public func derive<A, B, C, D, T>(
    first: Observable<A>,
    second: Observable<B>,
    third: Observable<C>,
    fourth: Observable<D>,
    compute: (A, B, C, D) -> T,
    policy!: StateMutationPolicy<T>
): DerivedState<T>

public func derive<A, B, C, D, E, T>(
    first: Observable<A>,
    second: Observable<B>,
    third: Observable<C>,
    fourth: Observable<D>,
    fifth: Observable<E>,
    compute: (A, B, C, D, E) -> T,
    policy!: StateMutationPolicy<T>
): DerivedState<T>
```

**参数**

- `source`: [`Observable`](Observable.md)`<A>` — 单源重载的输入源。
- `first`: [`Observable`](Observable.md)`<A>` — 二至五源重载的第一个输入源。
- `second`: [`Observable`](Observable.md)`<B>` — 二至五源重载的第二个输入源。
- `third`: [`Observable`](Observable.md)`<C>` — 三至五源重载的第三个输入源。
- `fourth`: [`Observable`](Observable.md)`<D>` — 四/五源重载的第四个输入源。
- `fifth`: [`Observable`](Observable.md)`<E>` — 五源重载的第五个输入源。
- `sources`: `Array<Observable<A>>` — 同类型源数组；创建时快照其元素与顺序。
- `compute`: 与所选固定元数或数组重载对应的纯计算函数，按参数顺序收到各源当前值。
- `policy`: [`StateMutationPolicy`](StateMutationPolicy.md)`<T>` — 固定源策略重载的结果等价关系；等价结果不推进派生 revision 或通知下游。

**返回值** [`DerivedState`](DerivedState.md)`<T>` — 惰性、带缓存的只读派生值；只有源修订号变动才重算。

```cangjie
let subtotal = derive<Int64, Int64, Int64>(price, quantity, {p, q => p * q})
```

```cangjie
let canSubmit = derive(name, accepted, online, pending,
    {text, ok, connected, requests => !text.isEmpty() && ok && connected && requests == 0},
    policy: structuralEqualityPolicy<Bool>())
```

### deriveStates

返回从同类型 `State` 数组计算出的只读派生状态。仓颉泛型数组不协变，直接持有
`Array<State<A>>` 时使用此入口，无需先构造 `Array<Observable<A>>`。它在创建时快照源数组，并以静态
`State` 路径采样 value/revision、建立失效边；语义与数组形态的 [`derive`](#derive) 相同。

```cangjie
public func deriveStates<A, T>(sources: Array<State<A>>, compute: (Array<A>) -> T): DerivedState<T>
```

**参数**

- `sources`: `Array<State<A>>` — 同类型可写状态数组；创建时快照其元素与顺序。
- `compute`: `(Array<A>) -> T` — 按源序接收当前值的纯计算函数。

**返回值** [`DerivedState`](DerivedState.md)`<T>` — 惰性、带缓存的只读派生值。

```cangjie
let counters = [State<Int64>(1), State<Int64>(2), State<Int64>(3)]
let total = deriveStates<Int64, Int64>(counters, {values =>
    var result: Int64 = 0
    for (value in values) {
        result += value
    }
    result
})
```

### ForEach

为每个数据项声明一棵键控子树。`key` 须逐项唯一且稳定，局部状态与控件标识随数据项穿越重排与删除。

```cangjie
public func ForEach<T>(items: Iterable<T>, key!: (T) -> String, body!: (T) -> Unit): Unit
```

**参数**

- `items`: `Iterable<T>` — 数据序列。
- `key!`: `(T) -> String` — 逐项唯一且稳定的键。
- `body!`: `(T) -> Unit` — 逐项界面构建函数。

```cangjie
ForEach(tasks, key: {task => task.id}) {task => taskRow(task)}
```

### ForEachIndexed

以位置为标识、为每个数据项声明一棵键控子树。项可能插入、删除或重排时优先用带稳定键的 [`ForEach`](#foreach)。

```cangjie
public func ForEachIndexed<T>(items: Iterable<T>, body!: (Int64, T) -> Unit): Unit
```

**参数**

- `items`: `Iterable<T>` — 数据序列。
- `body!`: `(Int64, T) -> Unit` — 收到 `(下标, 数据项)` 的界面构建函数。

### LazyGrid

垂直滚动的虚拟化网格：`data` 排成 `columns` 等宽列并按行开窗，海量均匀单元格（照片墙、卡片网格）只花一屏的成本。由成熟部件组合而成——每个虚拟化行是一个至多 `columns` 格的 [`Grid`](Grid.md)，铺在垂直 [`LazyColumn`](LazyColumn.md) 上，因此无需独立的水平滚动。行内单元格按位置键控，逐格局部状态跟随槽位——须跨数据重排存活的状态请上提。

```cangjie
public func LazyGrid<T>(
    data: Array<T>,
    columns: Int64,
    itemHeight: Float32,
    spacing!: Float32 = 0.0,
    columnSpacing!: Float32 = 0.0,
    scroll!: ?State<Float32> = None,
    id!: ?String = None,
    item!: (T) -> Unit
): LazyColumn
```

**参数**

- `data`: `Array<T>` — 单元格数据。
- `columns`: `Int64` — 列数；小于 1 按 1 处理。
- `itemHeight`: `Float32` — 固定行高，逻辑像素。
- `spacing!`: `Float32` — 行间距。默认 `0.0`。
- `columnSpacing!`: `Float32` — 单元格列间距。默认 `0.0`。
- `scroll!`: `?State<Float32>` — 外部持有的滚动偏移；默认值为 `None`，改用局部状态。
- `id!`: `?String` — 容器标识；默认值为 `None`，按构建位置派生。
- `item!`: `(T) -> Unit` — 单元格构建器。

**返回值** [`LazyColumn`](LazyColumn.md) — 承载网格行的虚拟化列表。

```cangjie
LazyGrid(photos, 4, 160.0, spacing: 12.0, columnSpacing: 12.0) { photo => photoCell(photo) }
```

### currentStateGeneration

兼容诊断用的进程级原子状态写代数。任何 [`State`](State.md) 赋值都会推进它，但桌面循环不再依赖该全局值：每个应用由独立 [`FrameScheduler`](FrameScheduler.md) 判断失效，避免多窗口互相触发重建。运行中的状态绑定所属 UI 线程；后台结果应通过 [`DesktopApp.post`](../desktop/DesktopApp.md#post) 投递。

```cangjie
public func currentStateGeneration(): UInt64
```

**返回值** `UInt64` — UI 线程每次状态赋值都会推进的写代数；到达 `UInt64.Max` 后回绕到零。

### remember

在活动声明式构建中保留任意稳定值。固定结构可用 keyless 重载；条件、循环和重排结构使用显式键，并结合
[`Keyed`](Keyed.md) / `ForEach`。工厂只在首次成功挂载时执行，之后返回同一值；失败构建不会提交新值。

```cangjie
public func remember<T>(factory: () -> T): T
```

```cangjie
public func remember<T>(key: String, factory: () -> T): T
```

它适合控制器、格式化器、动画对象以及稳定 [`DerivedState`](DerivedState.md) 图。`remember` 只管理值的挂载身份，
不会自动调用任意对象的 `close()`；需要确定清理的 `Resource` 使用 [`mountEffect`](#mounteffect) 或
[`lifecycleEffect`](#lifecycleeffect)。remembered 派生在构造时被标记为长期节点，在 build/phase 依赖图中只提交
一条惰性失效边。

```cangjie
let total = remember<DerivedState<Int64>> {
    deriveStates<Int64, Int64>(counters, {values => values.size})
}
```

**异常** `IllegalStateException` — 在活动构建之外调用；同一显式键重复；同一键/位置槽的值类型变化；keyless
槽数量在仍挂载的同一作用域中变化。

### rememberState

返回由活动 [`DesktopApp`](../desktop/DesktopApp.md) 构建保留的局部可写状态，是通用 [`remember`](#remember) 对 `State<T>` 的便捷封装。固定、无条件的声明可省略字符串键，按当前声明作用域中的位置槽保留；后续构建若增减同一位置作用域的槽数，框架拒绝整次构建并保留上次成功状态，避免同类型状态静默错位。条件、循环、插入、删除或重排内容使用显式键，并放进 [`Keyed`](Keyed.md) / `ForEach`，让标识独立于位置。

```cangjie
public func rememberState<T>(initial: () -> T): State<T>
```

```cangjie
public func rememberState<T>(key: String, initial: () -> T): State<T>
```

```cangjie
public func rememberState<T>(policy: StateMutationPolicy<T>, initial: () -> T): State<T>
```

```cangjie
public func rememberState<T>(key: String, policy: StateMutationPolicy<T>, initial: () -> T): State<T>
```

**参数**

- `key`: `String` — 显式键重载中，当前 `Keyed` 作用域内唯一的非空键。
- `policy`: [`StateMutationPolicy`](StateMutationPolicy.md)`<T>` — 首次创建 State 时采用的观察等价策略。
- `initial`: `() -> T` — 首次创建时的初值工厂。

**返回值** [`State`](State.md)`<T>` — 跨声明式重建保留的状态。

**异常**

- `IllegalArgumentException` — `key` 为空。
- `IllegalStateException` — 在活动构建之外调用；同作用域键重复；同键/位置槽值类型改变；keyless 位置槽数量在仍挂载的同一作用域中发生变化。

```cangjie
let query = rememberState<String>(structuralEqualityPolicy<String>()) {""}
let selected = rememberState<Int64>(
    "selected",
    stateMutationPolicy<Int64>({previous, current => previous == current})
) {-1}
```

`policy` 与 `initial` 一样是首次创建配置；后续重建返回原 `State`，不会替换其策略。昂贵的自定义策略对象可先用
[`remember`](#remember) 保留。未传策略的两个既有重载继续把每次赋值视为变化。

### mountEffect

在当前声明身份挂载一次有清理能力的副作用。`setup` 不在 builder 执行中立即调用，而是在整个根构建体成功后
准备；构建随后失败会关闭已准备资源且不替换旧 effect。边界卸载、应用清理或同键 effect 被替换时关闭返回的
`Resource`。固定、无条件的声明可用 keyless 重载；条件、循环和重排结构使用显式键与 `Keyed`/`ForEach`。

```cangjie
public func mountEffect(setup: () -> Resource): Unit
```

```cangjie
public func mountEffect(key: String, setup: () -> Resource): Unit
```

keyless effect 与 `remember`/`rememberState` 共用受守卫的位置形状；槽数或声明种类改变时，setup 执行前即拒绝
并回滚整次构建。`key` 在当前 `Keyed` / `RetainedSubtree` scope 内必须非空且唯一。setup 属于提交阶段，不能在
其中调用 `remember`、`rememberState`、effect 或继续声明 UI。只需 cleanup 闭包时返回
[`EffectCleanup`](EffectCleanup.md)。
该 API 是静态挂载声明：自动组合可在稳定帧复用已提交声明而不重新执行祖先 builder；State 驱动的条件删除仍会
标脏并正常卸载 Resource。

### lifecycleEffect

`mountEffect` 的 revision 版本。revision 不变时保留当前 Resource；变化时先成功建立新 Resource，再关闭旧
Resource，因此 setup 失败不会破坏此前已提交的 effect。cleanup 抛异常时框架继续清理兄弟资源、保留失败资源
供下次重试，并在提交后把首个异常抛给宿主。

```cangjie
public func lifecycleEffect(revision: UInt64, setup: () -> Resource): Unit
```

```cangjie
public func lifecycleEffect(key: String, revision: UInt64, setup: () -> Resource): Unit
```

```cangjie
lifecycleEffect("selection-observer", selection.revision) {
    selection.observe({_, value => analytics.recordSelection(value)})
}
```

固定声明可省略字符串键：

```cangjie
lifecycleEffect(selection.revision) {
    selection.observe({_, value => analytics.recordSelection(value)})
}
```

普通对象、主题或服务配置不会自动成为 effect revision；调用方应把会改变 setup 捕获语义的输入合成到 revision。
显式 revision 也会保留自动祖先的访问要求，因此普通外部值变化不会被静态组合命中冻结。

### subscribeFrame

为自定义 Widget 在当前构建登记一个合成帧回调。应在组件构造函数中调用；普通重建会重新登记，retained
边界命中会 O(1) 采用已保存的不可变有序片段。回调仍逐帧按声明顺序执行；静态组件不要订阅，框架不再把合成
`Frame` 广播给整棵树。仅需包装现有内容时
优先使用 [`FrameHandler`](FrameHandler.md)，它还会自动请求后续帧。

```cangjie
public func subscribeFrame(callback: (UiContext, FrameInfo) -> Unit): Unit
```

**参数**

- `callback`: `(UiContext, FrameInfo) -> Unit` — 每个实际渲染帧调用一次；回调自行决定是否 `requestFrame()`。

### broadcastEvent

把不可消费的广播阶段转发给一个组件，并有意丢弃其 `handle` 返回值。该函数只适合合成 `Frame` 或自定义宿主定义的同类 fan-out 阶段；普通键鼠、文本和拖放输入必须直接调用 `widget.handle(ctx, event)` 并遵守返回的消费结果，否则后层控件可能重复响应。

```cangjie
public func broadcastEvent(widget: Widget, ctx: UiContext, event: UiEvent): Unit
```

**参数**

- `widget`: [`Widget`](Widget.md) — 接收广播的组件。
- `ctx`: [`UiContext`](UiContext.md) — 当前事件上下文。
- `event`: `UiEvent` — 不允许由单个组件截断的广播事件。

### drawFocusRing

绘制键盘焦点环：贴着控件的强调色圆角描边，画在边界外 2 像素处，读作独立于控件自身边缘的光晕。每个可聚焦控件都画它（以 `showFocusRing` 闸门，只在键盘焦点时显示），Tab 导航在按钮、开关与输入框上获得统一可见的指示。公开导出使应用自定义组件画出与内置控件相同的环。

```cangjie
public func drawFocusRing(ctx: UiContext, rect: Rect, radius: Float32): Unit
```

**参数**

- `ctx`: [`UiContext`](UiContext.md) — 当前帧上下文。
- `rect`: `Rect` — 控件矩形；环画在其外 2 像素。
- `radius`: `Float32` — 控件自身的圆角半径；环用 `radius + 2`。

### emit

把新构造的组件注册进最内层打开的构建块。每个组件构造函数都调用它。在任何块之外（比如为存储复用而构建的组件）是无操作，组件保持普通值语义；把已有组件显式摆进块里也用它：`VStack { for (w in built) { emit(w) } }`。

```cangjie
public func emit(widget: Widget): Unit
```

**参数**

- `widget`: [`Widget`](Widget.md) — 要收集的组件。

### focusableControlIdentity

一步完成按构建顺序分配标识并注册为焦点项。公开导出使应用自定义组件与内置控件一样加入 Tab 顺序：在构造函数里以稳定基名调用，然后在 `handle`/`draw` 中配对 `ctx.hasFocus(id)` / `ctx.showFocusRing(id)`。构建期外返回基名原值、不注册。

```cangjie
public func focusableControlIdentity(base: String): String
```

**参数**

- `base`: `String` — 稳定基名（如 `"Button:保存"`）；同名者按声明顺序去重。

**返回值** `String` — 本次构建中唯一的焦点标识。

### claimHoverIfInside

当 MouseMove 落在 `frame` 内时，为 `id` 申请悬停状态和指定的指针形状。控件通常在 `handle` 开头调用它且不消费事件；事件继续经过各层，桌面应用对象最终采用最上层控件的申请（见 [`UiContext.claimHover`](UiContext.md#claimhover)）。公开导出供应用自定义组件使用，在 `draw` 中配合 `ctx.isHovered(id)` 判断悬停状态。

```cangjie
public func claimHoverIfInside(ctx: UiContext, event: UiEvent, frame: Rect, id: String, shape: CursorShape): Unit
```

**参数**

- `ctx`: [`UiContext`](UiContext.md) — 当前帧上下文。
- `event`: `UiEvent` — 正在处理的事件；只有 `MouseMove` 参与。
- `frame`: `Rect` — 控件矩形。
- `id`: `String` — 接收悬停的控件 id。
- `shape`: [`CursorShape`](CursorShape.md) — 希望的指针形状。

### optionalReducer

把 child reducer 提升到可选状态。纯与效果版本按参数类型重载：

```cangjie
public func optionalReducer<Model, Action>(
    reducer: Reducer<Model, Action>,
    missing!: MissingFeaturePolicy = MissingFeaturePolicy.Reject
): Reducer<?Model, Action>

public func optionalReducer<Model, Action, Effect>(
    reducer: EffectReducer<Model, Action, Effect>,
    missing!: MissingFeaturePolicy = MissingFeaturePolicy.Reject
): EffectReducer<?Model, Action, Effect>
```

`Some` 对 child reducer 做普通映射；`None` 默认抛异常，显式 Ignore 返回 `None` 和空效果。该 lift 保持 child
reducer 的异常原子性及效果顺序。父模型组合通常直接使用 [`Reducer.ifPresent`](Reducer.md#ifpresent) 或
[`EffectReducer.ifPresent`](EffectReducer.md#ifpresent)。

### identifiedReducer

把 child reducer 提升到按稳定 ID 路由的不可变有序集合。纯与效果版本按参数类型重载：

```cangjie
public func identifiedReducer<ID, Model, Action>(
    reducer: Reducer<Model, Action>,
    missing!: MissingFeaturePolicy = MissingFeaturePolicy.Reject
): Reducer<IdentifiedArray<ID, Model>, IdentifiedAction<ID, Action>>
    where ID <: Hashable & Equatable<ID>

public func identifiedReducer<ID, Model, Action, Effect>(
    reducer: EffectReducer<Model, Action, Effect>,
    missing!: MissingFeaturePolicy = MissingFeaturePolicy.Reject
): EffectReducer<IdentifiedArray<ID, Model>, IdentifiedAction<ID, Action>, Effect>
    where ID <: Hashable & Equatable<ID>
```

目标 ID 存在时只替换该持久集合元素；child 改变自身 ID、ID 缺失或 child reducer 失败都不会产生部分集合版本。
缺失时默认拒绝，显式 Ignore 返回原集合和空效果。

### identifiedBatchReducer

把一个显式有序 `IdentifiedAction` 数组解释为一次稳定顺序集合归约。纯与效果版本按 child reducer 类型重载：

```cangjie
public func identifiedBatchReducer<ID, Model, Action>(
    reducer: Reducer<Model, Action>,
    missing!: MissingFeaturePolicy = MissingFeaturePolicy.Reject
): Reducer<IdentifiedArray<ID, Model>, Array<IdentifiedAction<ID, Action>>>
    where ID <: Hashable & Equatable<ID>

public func identifiedBatchReducer<ID, Model, Action, Effect>(
    reducer: EffectReducer<Model, Action, Effect>,
    missing!: MissingFeaturePolicy = MissingFeaturePolicy.Reject
): EffectReducer<IdentifiedArray<ID, Model>, Array<IdentifiedAction<ID, Action>>, Effect>
    where ID <: Hashable & Equatable<ID>
```

同一 ID 的 Action 按数组顺序复合，完整遍历至多产生一个 `IdentifiedArray` 版本，显示顺序与 ID→位置索引保持不变。
Effect 按 child Action 顺序连接；Reject 在缺失、异常或 ID 改变时不返回部分结果，Ignore 只跳过缺失项。singleton
直接复用单元素路径，两个及以上 Action 进入不可逃逸的 chunk 编辑会话，每个触及 chunk 最多复制一次。

父级组合使用 [`Reducer.forEachBatch`](Reducer.md#foreachbatch) 或
[`EffectReducer.forEachBatch`](EffectReducer.md#foreachbatch)。它和 [`entityBatchReducer`](#entitybatchreducer) 的差别是：
前者保留稳定显示顺序，后者面向无顺序的正规化关系表。

### entityReducer

把 child reducer 提升到按 ID 路由的正规化 [`EntityTable`](EntityTable.md)。纯与效果版本按参数类型重载：

```cangjie
public func entityReducer<ID, Model, Action>(
    reducer: Reducer<Model, Action>,
    missing!: MissingFeaturePolicy = MissingFeaturePolicy.Reject
): Reducer<EntityTable<ID, Model>, IdentifiedAction<ID, Action>>
    where ID <: Hashable & Equatable<ID>

public func entityReducer<ID, Model, Action, Effect>(
    reducer: EffectReducer<Model, Action, Effect>,
    missing!: MissingFeaturePolicy = MissingFeaturePolicy.Reject
): EffectReducer<EntityTable<ID, Model>, IdentifiedAction<ID, Action>, Effect>
    where ID <: Hashable & Equatable<ID>
```

目标实体存在时只产生一个持久 table 版本；child 改变自身 ID、缺失或 reducer 失败都不会提交部分结果。父模型通常用
[`Reducer.forEntity`](Reducer.md#forentity) 或 Effect 对应方法保持 child→parent 顺序。

### entityBatchReducer

把一个显式有序 `IdentifiedAction` 数组解释为一次正规化实体表归约。纯与效果版本按 child reducer 类型重载：

```cangjie
public func entityBatchReducer<ID, Model, Action>(
    reducer: Reducer<Model, Action>,
    missing!: MissingFeaturePolicy = MissingFeaturePolicy.Reject
): Reducer<EntityTable<ID, Model>, Array<IdentifiedAction<ID, Action>>>
    where ID <: Hashable & Equatable<ID>

public func entityBatchReducer<ID, Model, Action, Effect>(
    reducer: EffectReducer<Model, Action, Effect>,
    missing!: MissingFeaturePolicy = MissingFeaturePolicy.Reject
): EffectReducer<EntityTable<ID, Model>, Array<IdentifiedAction<ID, Action>>, Effect>
    where ID <: Hashable & Equatable<ID>
```

数组顺序是语义的一部分：重复 ID 的后一个 Action 读取前一个归约结果；Effect 也按同一顺序连接。整个批次最多产生
一个 `EntityTable` 版本。缺失 ID 默认拒绝且没有模型或效果结果；Ignore 只跳过缺失项并继续其余 Action。≤8 项走
无中间集合的逐次快路，较大批次进入不可逃逸的目录编辑会话，调用者不需要选择策略。

父模型的一次领域 Action 要携带实体 Action 数组时，通常使用 [`Reducer.forEntities`](Reducer.md#forentities) 或
[`EffectReducer.forEntities`](EffectReducer.md#forentities) 保持完整 child 批次→parent 顺序。不要把任意连续根 Action
偷偷重排为此 API：其他 reducer 可能需要观察每个 Action 之间的模型。

## 另请参阅

- [`State`](State.md) / [`DerivedState`](DerivedState.md) — 派生函数的源与产物。
- [`Keyed`](Keyed.md) — `ForEach` 底层的标识容器。
- [`IdentifiedArray`](IdentifiedArray.md) — reducer 侧的稳定身份持久集合。
- [`EntityTable`](EntityTable.md) — reducer 侧的正规化实体表。
