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

`State<T>` 可读可写。每次赋值都会推进 revision 并同步通知观察者；UI 状态应在桌面 UI 线程修改。`setIfChanged` 只在相等性判断发现变化时写入，适合避免无意义通知，但不要拿它替代业务校验。

任何会改变当前或下一帧可见/可交互结果的持久事实都必须经过 `State`（或由它派生的 `Binding`/`DerivedState`）。`DesktopApp` 会先 build/layout，再派发本批事件；只有 `State` 写推进应用级 `FrameScheduler` 代数时，宿主才会在 draw 前稳定重建。按钮回调若只改普通模型 `var`，当前树中的 `Label` 仍保存事件前构造的文字，而且调度器不知道还需一帧；结果常表现为“点一次没反应，下一次输入才显示上次结果”。

`Binding<T>` 不是第二份值，而是通向原模型中某个字段的双向绑定。`Bindable.project` 用 `get` 从整体取字段，用 `set` 根据新字段重建整体。例如 `State<Profile>` 可以生成姓名字段的绑定；文本框修改姓名时，其他字段仍从原模型保留。这个模式比“编辑时复制全部模型、每按一个键再同步”更清楚。

`DerivedState<T>` 从一个或多个可观察值计算，只读。总价、筛选结果数、按钮是否启用等值若能由事实算出，就不应另存。派生值减少同步代码，也让依赖关系可见。

`rememberState(key)` 把局部状态放进应用状态存储。键在同一作用域必须非空、唯一且类型稳定；一次构建中重复同键会报错，未再访问的条目会随离开构建树而移除。动态列表需要稳定的数据键，否则项目重排后局部状态可能跟错行。

## 选择与取舍

- **外部模型/State**：业务事实、多个页面共享、需要持久化或测试的值。
- **rememberState**：某个声明位置的展开、临时输入、局部选择等界面状态。
- **Binding/project**：控件要修改整体模型中的一个字段，但所有权仍在整体。
- **DerivedState/map/derive**：总数、有效性、过滤结果等可从现有事实计算的值。
- **普通 let**：一次构建内的纯计算结果，不需要观察或跨构建保留。
- **普通 var**：仅限不会独立改变界面的内部算法细节；若它的变化会影响 build、layout、draw、命中或可用状态，就应改为 `State`，或确保同一事务必然还有对应的 `State` 写入作为失效信号。优先前者，避免隐式耦合。

选择时先写出所有权句子：“联系人列表由页面模型持有；搜索框绑定查询；过滤结果从两者派生。”如果一句话里出现“然后同步到”，通常说明存在重复状态。

## 应用这个模型

表单可用三个局部状态保存输入与提示：

```cangjie role=contrast
let name = rememberState<String>("form.name") {""}
let accepted = rememberState<Bool>("form.accepted") {false}
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

## 常见误解

- **“Binding 是 State 的副本。”** 它转发读写，不独立保存事实。
- **“所有计算结果都应该是 State。”** 可推导值另存会产生同步责任。
- **“rememberState 的键只是调试名称。”** 键决定跨构建身份，动态内容必须稳定且唯一。
- **“观察者会立即收到当前值。”** 观察回调面向后续变化；首次显示应直接读取当前值。
- **“在任意后台线程写 UI 状态都可以。”** 桌面 UI 状态应回到 UI 线程更新。
- **“模型对象还活着，改普通 var 后界面自然会看到。”** 已构建组件不会自动回读普通字段，普通写入也不会通知帧调度器；所有可见事实必须可观察。

## 相关 API

- [`State`](../../api/cui/core/State.md)、[`Binding`](../../api/cui/core/Binding.md)、[`DerivedState`](../../api/cui/core/DerivedState.md) — 三类数据角色。
- [`Bindable.project`](../../api/cui/core/Bindable.md#project) — 从整体模型创建字段双向绑定。
- [`rememberState`](../../api/cui/core/functions.md#rememberstate) 与 [`derive`](../../api/cui/core/functions.md#derive) — 声明式构建中的局部与派生状态。

## 下一步

继续读[模型、动作与界面边界](app-architecture.md)，把状态所有权扩展成可测试的应用结构。

完成[设置表单](../tutorials/settings-form.md)，把输入、校验和提示放进单一数据流。动态项目需要稳定身份时，继续[构建数据列表](../how-to/data-list.md)。
