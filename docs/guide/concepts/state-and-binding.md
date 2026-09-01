[CUI 指南](../index.md) › 状态与绑定

# 状态、绑定与派生值

## 先用一句话说明

状态保存一份可变化的事实，绑定把其中可写的一部分交给控件，派生值只从现有事实计算而不再保存副本。

这套数据模型建立在[声明式构建与应用生命周期](composition-and-lifecycle.md)之上：构建函数可以反复执行，事实却必须由构建过程之外的稳定存储继续持有。

对应的正式类型是 `State<T>`、`Binding<T>`/`Bindable<T>` 与 `DerivedState<T>`。先问“事实在哪里、谁能修改、能否从别的值算出”，再选择类型；不要因为某个控件构造函数需要绑定就到处复制状态。

## 为什么重要

表单、选择列表和主从编辑器最容易出现双份数据：模型里有姓名，文本框旁又维护一个字符串；列表有选中 id，详情面板再复制一份选中对象。两份值必须手工同步，过滤、删除或取消编辑时很快分叉。单一事实来源让所有控件和提示读取同一个值，派生信息随之更新。

状态所有权也决定复用。页面级模型可以在多个控件间共享；`rememberState` 适合与声明位置绑定的局部交互状态；`Binding.project` 让一个字段可写，却仍由整体模型持有。只读控件只需要 `Observable`，不应获得不必要的修改权限。

## 工作模型

`State<T>` 可读可写。默认构造的状态接受每次赋值并推进 revision；事务外立即通知观察者，`DesktopApp.batch`、事件回调或 `post` 动作的事务内则推迟到提交点，同一个 `State` 只报告“事务前值 → 最终值”。显式等价策略还会消去首尾等价的净零路径，因此一次操作临时改变又恢复值时不会产生空通知和空帧；中间有效赋值的 revision 仍保留为写入证据。这让多个源的 `DerivedState.observe` 只看到稳定结果，不会先看到一半新、一半旧的中间组合。UI 状态应在桌面 UI 线程修改。

观察者按注册顺序运行。一次通知的参与集合在开始时封闭：回调中取消尚未运行的观察者会跳过它，新注册者从下一次赋值开始接收；若回调立即再次写同一 `State`，这次嵌套写入就是“下一次”，会看到当时最新的参与集合。框架用稳定下标窗口与延迟删除实现这组语义，不会为每次写入复制整张监听表；应用通常无需依赖可重入写入，但自定义状态适配器可以据此确定地推理。

观察者异常采用“稳定后报告”：一个回调失败不会阻止同一 State 的后续监听器，也不会阻止事务里其他 State、
Derived observer 或失败回调在抛错前产生的新写入。框架保留最先发生的异常，继续运行工作队列直到不动点，完成
依赖失效和延迟删除后再抛出。这样日志、业务插件或用户回调的错误不能饿死后面的 UI 依赖；异常仍明确返回给
发起写入的代码，并未被吞掉。只有观察环超过收敛上限或内部不变量损坏才会立即中止。

频繁出现空写时，可在构造时选择 `structuralEqualityPolicy<T>()`，从源头跳过相等赋值；局部状态可直接写成
`rememberState<String>(structuralEqualityPolicy<String>()) {""}`。模型没有合适的 `Equatable` 时，用
`stateMutationPolicy<T>({previous, current => ...})` 表达领域等价关系。默认策略仍保留“每次赋值都是事件”的兼容
语义，一次性的相等判断也可用 `setIfChanged`。策略只回答“两个值在观察意义上是否等价”，应满足自反、对称、
传递；不要把业务校验或副作用塞进它。

领域策略不是写完闭包就自动成为等价关系。测试中用 `checkStateMutationPolicyLaws(policy, first:, second:, third:)`
检查代表值的重复性、自反、对称和传递；它会给出逐律结果，并把比较异常原样交给测试。有限三值矩阵只能找到反例，
应覆盖同类、异类和临界值，条件允许时再交给属性生成器重复采样。

如果领域等价只取决于稳定 ID 或一个小字段，先建立字段策略，再用 `.pullback<Model>({model => model.id})` 拉回整体
值空间。这样 State、Store 与 selector 可复用同一个投影定义，也避免两次手写 `previous/current` 字段访问。被投影
丢弃的信息确实不会更新存储；仍需显示这些信息时应拆分 State，而不是扩大等价类。

如果不确定某个策略是否划算，可在开发期用 `diagnoseStateMutationPolicy(policy)` 显式包装它，并查看比较次数、等价
命中、不同结果、失败、累计和最大耗时。比较抛出的异常仍会原样传播；未包装的普通 State/selector/Binding 不承担
计数或时钟开销。诊断的关键问题不是“命中率高不高”本身，而是省下的通知、派生计算与帧工作是否大于比较成本。

任何会改变当前或下一帧可见/可交互结果的持久事实都必须经过 `State`（或由它派生的 `Binding`/`DerivedState`）。`DesktopApp` 会先 build/layout，再逐个派发离散事件；每个事件事务若写入状态，会在下一个事件路由前稳定重建，最后再 draw。因此按下事件打开的浮层可以接住紧随其后的键盘事件，而不会继续使用过期树。按钮回调若只改普通模型 `var`，当前树中的 `Label` 仍保存事件前构造的文字，而且调度器不知道还需一帧；结果常表现为“点一次没反应，下一次输入才显示上次结果”。

`Binding<T>` 不是第二份值，而是通向原模型中某个字段的双向绑定。`Bindable.project` 可直接接收 `get`/`set`，也可接收能复用和组合的 `Lens<S, A>`。Lens 的三个基本定律是 Get-Put（写回刚读出的值不改变整体）、Put-Get（写入后能读回该值）和 Put-Put（连续写入等价于只保留最后一次）；满足它们，嵌套字段组合后才不会产生隐藏同步规则。例如 `State<Profile>` 可以生成姓名字段的绑定；文本框修改姓名时，其他字段仍从原模型保留。

对当前值做 read-modify-write 时使用 `Bindable.update`。嵌套 `project(...).project(...)` 会把焦点上的端态变换
`A → A` 逐层提升为根模型上的一次 `S → S`：根 Bindable 只读取、写入一次，所有 Lens setter 都消费同一个模型
快照。这样既避免手写 `binding.value = transform(binding.value)`，也不会让深层字段写入随投影深度重复读取根模型。
变换抛异常时没有根写入；根 State 的观察者只收到一次整体变化。

预先用 `Lens.then` 组合路径时也遵循同一原则：`Lens.update(source, transform)` 把端态变换沿路径一次提升，组合
`set`/`update` 不会反复读取已经经过的前缀。因而可以按业务含义命名和复用深层 Lens，而无需在“清晰路径”与
“逐层 Binding 性能”之间二选一。

当整体模型频繁改变、控件只关心一个便宜字段时，可给 `project` 或 Store `binding` 传 `policy:`。这不会把字段复制成
第二个 State：Lens/Action 写入仍回到唯一根模型，只有 Binding 的读取、revision、观察和 UI 依赖被投影到字段商空间
`A/~`。因此兄弟字段变化不再要求控件手工比较 `(旧值, 新值)`；策略判等也不能吞掉 Action 或 Effect。默认重载保持
“源接受一次变化，Binding 就可能变化”的兼容语义。

`DerivedState<T>` 从一个或多个可观察值计算，只读。总价、筛选结果数、按钮是否启用等值若能由事实算出，就不应另存。派生值减少同步代码，也让依赖关系可见。

`derive` 的固定重载支持一至五个异构源，四/五源仍融合为一个惰性节点；同类型动态集合使用数组重载或
`deriveStates`。这覆盖常见表单有效性、连接状态、权限与待处理任务等联合条件，无需为了第四个事实创建中间
`DerivedState`。如果长期需要组合更多异构源，通常说明这些事实应先聚合成一个有业务含义的模型，而不是继续扩大
无名参数列表。

默认派生只知道“上游 revision 变了”，所以会先传播可能失效，再在下次读取时惰性重算。若一个较大模型派生出很多
独立字段，可用 `source.map({model => model.field}, policy: structuralEqualityPolicy<Field>())`，或给
`ModelStore.select` 传同样的策略。存在 UI/观察订阅时，框架在上游事务端点计算这个便宜投影；字段仍等价就不标脏
对应作用域。固定一至五源可直接写 `derive(..., policy: policy)`，避免 `derive(...).distinct(policy)` 产生第二个
响应节点；对已经组合好的派生或动态数组派生仍调用 `.distinct(policy)`。这不是免费的深比较：投影和策略会在每次相关上游提交
时运行，因此只适合快速纯函数；昂贵过滤优先拆 State/Store 边界，或先构造可复用的缓存派生。

派生实例表示一个固定源积上的纯映射：数组重载会在创建时快照源序列，不能靠事后替换数组元素动态改依赖。内置 State 图的稳定读取先用全局写入 epoch 作“没有写入”的否定证书，再在必要时比较完整 revision 向量；这不是把所有状态合并成一个全局脏位。稳定派生在构建/布局依赖图中是一个惰性节点，任意宽度只占一条直接边，上游写入只传播失效、不提前求值。声明 body 内临时创建的 State-backed 派生自动保留直接源边，以复用跨重建 State identity；开发者无需为性能选择不同 API。自定义 `Observable` 用 `observe` 接入节点，并在读取时继续精确比较 revision。

宽数组派生第一次求值会把 State-backed 源的 value/revision 合并采样，减少为了缓存正确性重复遍历同一源积；采样仍位于 `compute` 之前，写入 epoch 也在遍历前固定，因此计算中自写、异常重试和无关 State 写入都保持确定语义。直接持有 `Array<State<T>>` 时用 `deriveStates`，避免泛型不协变带来的手工擦除，并保留静态专用采样；已有 `Array<Observable<T>>` 若运行时全为 State，也会自动正规化到该路径。自定义 Observable 不启用融合，避免改变其 getter 的既有调用顺序。

`remember { ... }` 在固定声明位置保留任意稳定对象，`rememberState { ... }` 是创建可写 State 的便捷形式；它们与 keyless effect 不必发明字符串键，并共享同一位置形状。槽数量、值类型以及 remembered value / mount effect / revisioned effect 的声明种类都在提交前验证，漂移会回滚并报错。条件、循环或可重排内容改用显式 key、`Keyed` 或带业务 key 的 `ForEach`。显式键在同一作用域必须非空、唯一且类型稳定；未再挂载的 keyed 条目会随子树移除。`rememberState` 的策略与初值都是首次创建配置；重建时不会替换已保留 State 的策略，构造昂贵的策略对象应先用 `remember` 保留。

在 build 中组合昂贵或宽的派生图时，用 `remember<DerivedState<T>> { derive... }` 保留图身份。框架会把工厂内创建的
派生识别成长期惰性节点；例如 256 个 State 源仍只向当前作用域提交一条依赖边。普通一次性纯计算无需 remember，
需要确定清理的订阅或资源则使用 lifecycle effect，而不是依赖对象被丢弃。

## 选择与取舍

- **外部模型/State**：业务事实、多个页面共享、需要持久化或测试的值。
- **rememberState**：某个声明位置的展开、临时输入、局部选择等界面状态。
- **remember**：跨重建复用但本身不需要可写通知的控制器、格式化器、动画对象或派生图。
- **Binding/project**：控件要修改整体模型中的一个字段，但所有权仍在整体；宽根模型的便宜字段可增加读取等价策略。
- **Lens**：同一个字段投影会跨控件或嵌套模型复用，需要组合并独立验证读写定律。
- **DerivedState/map/derive/deriveStates**：总数、有效性、过滤结果等可从现有事实计算的值；同类型 State 数组优先 `deriveStates`；大模型的便宜字段 selector 可显式增加结果等价策略。
- **普通 let**：一次构建内的纯计算结果，不需要观察或跨构建保留。
- **普通 var**：仅限不会独立改变界面的内部算法细节；若它的变化会影响 build、layout、draw、命中或可用状态，就应改为 `State`，或确保同一事务必然还有对应的 `State` 写入作为失效信号。优先前者，避免隐式耦合。

选择时先写出所有权句子：“联系人列表由页面模型持有；搜索框绑定查询；过滤结果从两者派生。”如果一句话里出现“然后同步到”，通常说明存在重复状态。

## 应用这个模型

表单可用三个局部状态保存输入与提示：

```cangjie role=contrast
let name = rememberState<String> {""}
let accepted = rememberState<Bool>(structuralEqualityPolicy<Bool>()) {false}
let canSubmit = derive(name, accepted) {n, ok => !n.trimAscii().isEmpty() && ok}
```

`TextField(name)` 与 `Checkbox(..., accepted)` 获得可写值，按钮只读取 `canSubmit` 决定是否可用。无需在按钮点击时维护第四个“表单是否有效”的状态；它本来就是前两项的函数。

对于整体模型，为需要编辑的字段创建双向绑定：

```cangjie role=trace
let nameBinding = profile.project(
    get: {p => p.name},
    set: {p, value => Profile(value, p.subscribed)}
)
```

投影需要复用或嵌套时，把它命名为 Lens：

```cangjie role=trace
let profileName = Lens<Profile, String>(
    get: {p => p.name},
    set: {p, value => Profile(value, p.subscribed)}
)
let nameBinding = profile.project(profileName)
nameBinding.update({name => name.trimAscii()})
```

对实现了 `Equatable` 的模型和焦点，可在 `cui.testing` 中用一行 `checkLensLaws` 得到 Get-Put、Put-Get、Put-Put
三项结果。组合 Lens 只在每个组成 Lens 都合法时继承这些定律，因此直接父路径和最终组合路径都应保留代表性 witness。

处理一次用户意图的多项写入时显式成批提交：

```cangjie role=trace
app.batch {
    profile.value = loadedProfile
    saveStatus.value = "已载入"
}
```

所有直接状态观察者在批次结束时收到最终值；由多个源组成的派生观察者也只运行一次。若显式策略判定批次前后等价，
该 State 的直接和派生观察者都不运行，界面也不为它额外构建一帧。界面自动事件回调与 `post` 动作已经处于事务内，
通常不必再嵌套 `batch`。

## 常见误解

- **“Binding 是 State 的副本。”** 它转发读写，不独立保存事实。
- **“所有计算结果都应该是 State。”** 可推导值另存会产生同步责任。
- **“keyless rememberState 可以放进任意条件或未键控循环。”** 它是位置身份，固定结构最省心；动态结构必须提供稳定业务键。
- **“观察者会立即收到当前值。”** 观察回调面向后续变化；首次显示应直接读取当前值。
- **“batch 只减少重绘，观察者仍会看到每个中间值。”** 同一状态的通知会合并，派生观察者在源状态稳定后运行。
- **“任意 get/set 都是合法字段 Binding。”** 自定义投影若破坏 Lens 三定律，控件写回可能悄悄改动无关字段；应测试定律。
- **“在任意后台线程写 UI 状态都可以。”** 桌面 UI 状态应回到 UI 线程更新。
- **“模型对象还活着，改普通 var 后界面自然会看到。”** 已构建组件不会自动回读普通字段，普通写入也不会通知帧调度器；所有可见事实必须可观察。

## 相关 API

- [`State`](../../api/cui/core/State.md)、[`Binding`](../../api/cui/core/Binding.md)、[`Lens`](../../api/cui/core/Lens.md)、[`DerivedState`](../../api/cui/core/DerivedState.md) — 状态与投影角色。
- [`DiagnosedStateMutationPolicy`](../../api/cui/core/DiagnosedStateMutationPolicy.md) — 按需测量策略抑制收益、失败与耗时。
- [`Bindable.project`](../../api/cui/core/Bindable.md#project) — 从整体模型创建字段双向绑定。
- [`remember`](../../api/cui/core/functions.md#remember)、[`rememberState`](../../api/cui/core/functions.md#rememberstate)、[`derive`](../../api/cui/core/functions.md#derive) 与 [`deriveStates`](../../api/cui/core/functions.md#derivestates) — 声明式构建中的稳定对象、局部状态与派生状态。

## 下一步

继续读[模型、动作与界面边界](app-architecture.md)，把状态所有权扩展成可测试的应用结构。

完成[设置表单](../tutorials/settings-form.md)，把输入、校验和提示放进单一数据流。动态项目需要稳定身份时，继续[构建数据列表](../how-to/data-list.md)。
