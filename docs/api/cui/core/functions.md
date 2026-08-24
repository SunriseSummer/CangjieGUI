[cui](../../index.md) › [cui.core](index.md) › 函数

# 函数 — cui.core

`cui.core` 的包级函数：状态派生、声明式列表助手、虚拟化网格、构建与焦点协议工具。

### derive

返回从一到多个源计算出的只读派生状态。四个重载按源的数量与形态区分：单源、双源、三源，以及同类型源的数组形态（源数量动态或超过固定元数时用——例如把一组逐项计数器聚合成总数）。`compute` 按源序收到当前值。

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
public func derive<A, T>(sources: Array<Observable<A>>, compute: (Array<A>) -> T): DerivedState<T>
```

**参数**

- `source`: [`Observable`](Observable.md)`<A>` — 单源重载的输入源。
- `first`: [`Observable`](Observable.md)`<A>` — 双源或三源重载的第一个输入源。
- `second`: [`Observable`](Observable.md)`<B>` — 双源或三源重载的第二个输入源。
- `third`: [`Observable`](Observable.md)`<C>` — 三源重载的第三个输入源。
- `sources`: `Array<Observable<A>>` — 同类型源数组。
- `compute`: `(A) -> T` / `(A, B) -> T` / `(A, B, C) -> T` / `(Array<A>) -> T` — 与所选重载对应的纯计算函数，按参数顺序收到各源当前值。

**返回值** [`DerivedState`](DerivedState.md)`<T>` — 惰性、带缓存的只读派生值；只有源修订号变动才重算。

```cangjie
let subtotal = derive<Int64, Int64, Int64>(price, quantity, {p, q => p * q})
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

### rememberState

返回由活动 [`DesktopApp`](../desktop/DesktopApp.md) 构建保留的局部状态。重复或条件挂载的状态请放进 [`Keyed`](Keyed.md)，标识独立于位置。空键抛 `IllegalArgumentException`；在活动构建之外调用、或违反键标识规则时抛 `IllegalStateException`。

```cangjie
public func rememberState<T>(key: String, initial: () -> T): State<T>
```

**参数**

- `key`: `String` — 当前 `Keyed` 作用域内唯一的非空键。
- `initial`: `() -> T` — 首次创建时的初值工厂。

**返回值** [`State`](State.md)`<T>` — 跨声明式重建保留的状态。

**异常**

- `IllegalArgumentException` — `key` 为空。
- `IllegalStateException` — 在活动构建之外调用；同作用域键重复；同键值类型改变。

### mountEffect

在当前声明身份挂载一次有清理能力的副作用。`setup` 不在 builder 执行中立即调用，而是在整个根构建体成功后
准备；构建随后失败会关闭已准备资源且不替换旧 effect。边界卸载、应用清理或同键 effect 被替换时关闭返回的
`Resource`。

```cangjie
public func mountEffect(key: String, setup: () -> Resource): Unit
```

`key` 在当前 `Keyed` / `RetainedSubtree` scope 内必须非空且唯一。setup 属于提交阶段，不能在其中调用
`rememberState`、effect 或继续声明 UI。只需 cleanup 闭包时返回 [`EffectCleanup`](EffectCleanup.md)。

### lifecycleEffect

`mountEffect` 的 revision 版本。revision 不变时保留当前 Resource；变化时先成功建立新 Resource，再关闭旧
Resource，因此 setup 失败不会破坏此前已提交的 effect。cleanup 抛异常时框架继续清理兄弟资源、保留失败资源
供下次重试，并在提交后把首个异常抛给宿主。

```cangjie
public func lifecycleEffect(key: String, revision: UInt64, setup: () -> Resource): Unit
```

```cangjie
lifecycleEffect("selection-observer", selection.revision) {
    selection.observe({_, value => analytics.recordSelection(value)})
}
```

普通对象、主题或服务配置不会自动成为 effect revision；调用方应把会改变 setup 捕获语义的输入合成到 revision。

### subscribeFrame

为自定义 Widget 在当前构建登记一个合成帧回调。应在组件构造函数中调用；普通重建会重新登记，retained
边界命中会重放已保存的登记。静态组件不要订阅，框架不再把合成 `Frame` 广播给整棵树。仅需包装现有内容时
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

## 另请参阅

- [`State`](State.md) / [`DerivedState`](DerivedState.md) — 派生函数的源与产物。
- [`Keyed`](Keyed.md) — `ForEach` 底层的标识容器。
