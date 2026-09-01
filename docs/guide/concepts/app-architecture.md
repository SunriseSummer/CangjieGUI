[CUI 指南](../index.md) › 应用结构

# 模型、动作与界面边界

## 先用一句话说明

模型保存事实，动作完成一次业务变化，界面只显示事实并把用户意图交给动作。

这套边界建立在[状态、绑定与派生值](state-and-binding.md)之上。状态解决“值放在哪里”，应用结构继续回答“谁可以修改它、文件和后台任务放在哪里、怎样让主要规则可以脱离窗口测试”。

## 为什么重要

计数器可以把全部代码写在按钮回调里；记事本、任务看板或进程工具却不行。若打开文件、修改数组、校验、Toast 文案和控件声明挤在同一个构建闭包中，读者很快会遇到三类问题：同一动作被按钮和快捷键复制；错误路径没有恢复 busy 状态；纯业务规则只能启动窗口后测试。

CUI 不要求特定目录模板，但真实示例反复体现同一职责分工。`model.cj` 保存事实和可测试规则，`views.cj` 声明控件，`file_actions.cj` 或 `worker.cj` 处理外部系统，`main.cj` 组装依赖和运行应用。文件名可以变化，依赖方向不应反转：模型不寻找按钮，文件层不直接操纵旧控件对象。

## 工作模型

把一次交互看成单向闭环：控件产生“选择任务”或“保存文档”意图；动作函数读取模型、验证并提交一次状态变化；构建函数再次读取模型，呈现新的列表、详情或错误。派生值只从事实计算，避免动作还要同步标题、计数和按钮启用状态。

当同一特征已有多个输入入口、多个字段必须原子变化，或动作序列需要测试/重放时，可用
`ModelStore<Model, Action>` 固化这个闭环。界面只能 `get`/`select` 模型并 `dispatch` Action；纯 `Reducer` 从一个
完整快照构造下一模型。输入控件通过 action-driven Binding 把候选值转换为 Action，而不是获得绕过 reducer 的
根模型 setter。小页面仍可直接使用几个 State 和普通动作方法，不需要为架构统一付固定样板成本。

基础设施是文件对话框、文件系统、剪贴板、进程和后台工作等会失败、会等待或需要关闭的边界。动作可以调用基础设施，但要把结果转换成模型理解的成功/失败值。后台闭包不能直接写 UI `State`；它向线程安全信箱发布普通数据，再由 UI 帧收取。

一个可维护项目可以采用以下依赖方向：

- `model.cj`：领域值、`State`/`ModelStore`、纯查询和纯 Reducer；
- `actions.cj`：选择、删除、保存完成/失败等强类型领域事件，以及启动外部工作的用例；
- `views.cj`：读取模型，声明 Label、Table、TextArea、Modal；
- `desktop.cj`：对话框、剪贴板、文件和后台适配；
- `main.cj`：创建模型、长期服务、主题和 `DesktopApp`。

## 选择与取舍

小页面不必为了“架构”创建五个空文件。先在一个文件里保持函数边界；当模型需要纯测试、多个输入入口共享动作，或基础设施需要替换时再拆文件。拆分依据是变化原因，而不是每个类型一个文件。

局部展开、临时选择等只服务一个声明位置的值仍可使用 `rememberState`。业务任务、文档正文、待保存路径等需要跨页面或被测试的事实放进显式模型。外部请求句柄由明确所有者保存，完成后清理；不要让每次构建重新发起请求。

`ModelStore` 不是“所有状态都全局化”的许可。按特征或共享生命周期建立 store；能从模型计算的值使用 `select`，
只影响一个声明位置的状态留在 `rememberState`。Reducer 必须纯；文件、网络、时钟和后台任务在动作层启动，结果再
通过 `DesktopApp.post` 或帧信箱变成成功/失败 Action。

根模型较宽时，普通 selector 会在任一 Action 后传播“可能变化”。对字段、枚举、小元组等便宜结果，给 `select`
传 `structuralEqualityPolicy` 或领域等价策略，可以让未跨越结果等价类的 Action 停在 selector 节点，不重建读取它的
界面分支。策略不是深比较补丁：昂贵筛选仍应先拆分特征 Store 或建立缓存派生，selector 与比较器必须保持纯且快速。

静态的少量 reducer 直接用 `then` 最清楚；只有插件或运行时模块发现产生了 reducer 数组时，才用
`Reducer.concat(parts)` / `EffectReducer.concat(parts)`。它们保持数组顺序、首错短路和效果顺序，并只在集合超过
1024 项时才平衡调用树，不让普通特征组合为极端规模支付间接成本。

拆分 reducer 还不够：若子视图继续接收 `ModelStore<AppModel, AppAction>`，它仍会反复写根字段 selector 和
`AppAction.profile(...)` 包装，并能看见不属于自己的根类型。应在组合根创建一次 `FeaturePath`，把局部状态 Lens 和
Action 分支 Prism 配成 reducer/Store 共用的边界：

```cangjie role=contrast
let profilePath = FeaturePath<AppModel, AppAction, Profile, ProfileAction>(
    state: profileLens,
    action: Prism<AppAction, ProfileAction>(
        extract: {action => action.profile},
        embed: {action => AppAction(profile: Some(action))}
    )
)
let appReducer = profileReducer.pullback<AppModel, AppAction>(profilePath)
let profile = app.scope<Profile, ProfileAction>(
    profilePath,
    policy: structuralEqualityPolicy<Profile>()
)

func profileView(store: ScopedStore<Profile, ProfileAction>): Unit {
    Label(store.get().name)
    Button("重置", {=> store.dispatch(ProfileAction.reset())})
}
```

子视图现在只思考本特征的状态空间和事件词汇；scope 不复制 State，也不允许直接改局部模型。它可继续嵌套，
`dispatchAll` 会把整批局部 Action 直接融合进一个根事务。默认 scope 保持惰性兼容语义；若局部模型小且比较便宜，
在特征边界声明一次等价策略，可让其他特征的根 Action 不再重建这棵子树。`FeaturePath.then` 会同时组合 Lens 与
Prism，深层子特征只声明自己的直接父边界；同一路径驱动 reducer 的 `pullback` 与 Store 的 `scope` 后，不再需要
人工保证两处闭包指向同一个 Action 分支。自定义路径应分别用 `checkLensLaws(path.state, ...)` 与
`checkPrismLaws(path.action, ...)` 检查状态三定律、Action 嵌入/提取往返；Prism 的 source witness 应同时覆盖命中与
未命中的根 Action。

末端只读字段继续用 `scoped.select(...)`；实现会把普通 scope 投影和 selector 合成一个根派生节点，到显式 policy
商边界才停止。输入控件使用 `binding(..., policy: ...)` 可获得同样的局部通知隔离，同时写入仍沿 Action 路由到根
reducer。策略只优化观察频率，不是取消、授权或效果过滤机制。

动态子特征还需要处理“此刻可能不存在”和“同一种特征有很多实例”。不要在每个根 reducer 分支手写 Option 解包、
线性扫描行 ID、复制数组和回写。可选详情使用 `ifPresent`，重复行使用 `IdentifiedArray` 与 `forEach`：

```cangjie role=contrast
let appReducer = parentReducer
    .ifPresent<Editor, EditorAction>(
        state: editorLens,
        action: editorActionPrism,
        child: editorReducer
    )
    .forEach<RowId, Row, RowAction>(
        state: rowsLens,
        action: rowActionPrism,
        child: rowReducer
    )
```

两种组合都先运行 child、再运行 parent。于是关闭编辑器或删除行的同一个 Action 中，child 能先完成校验、归约或效果
描述，parent 再读取最终 child 状态并移除它。Action 命中但状态已缺失默认抛异常，使取消/生命周期错误可见；只有领域
明确允许迟到结果时才传 `MissingFeaturePolicy.Ignore`。`IdentifiedArray` 构造时拒绝重复 ID，child 更新不能改变自身
ID；排序或删除不会把旧 Action 错投给同一位置的新行。

若一个领域事件要同时更新多行，让父 Action 携带 `Array<IdentifiedAction<ID, ChildAction>>`，用 `forEachBatch`
组合，或对独立集合使用 `identifiedBatchReducer`。它保持显示顺序、重复 ID 的 Action 顺序和 child effects 顺序，
同时只生成一个集合版本；singleton 自动复用单元素路径，批次无需开发者选择性能开关。

`IdentifiedArray` 适合有序 UI 子特征，不是所有关系数据的万能容器。大量跨实体关系应按 ID 正规化为独立
`EntityTable<ID, Entity>`，关系和显示顺序只保存 ID：同一个用户、文档或任务只有一份事实，修改不再递归复制每个
嵌套引用。实体 Action 可用 `forEntity`/`entityReducer` 按 ID 路由，并保持与重复 UI 特征相同的 child→parent、
缺失 Reject/Ignore 语义。

`EntityTable` 的普通更新只复制浅层 32 路目录路径和目标 hash bucket，旧模型版本继续共享其余实体。它不承诺
`toArray()` 顺序；列表应另存有序 ID，视图用 ID 查询实体。原生可变 HashMap 的读取仍更便宜，因此一帧反复读取同一
实体时用 `store.select({model => model.entities.get(id)})` 建立缓存 selector；`diagnostics()` 可发现异常碰撞和增删后
保留容量。只有十几项且不需要持久快照/路由时，普通 Array 或局部 HashMap 更轻。

同一个 Action 要修改多个实体时，用 `EntityUpdate` 数组和 `updatingAll` 表达一个有序原子批次，不要在业务代码中
维护临时可变 HashMap 或暴露半成品。重复 ID 按声明顺序复合；缺失、异常或 ID 改变都不产生部分表版本。框架对小批次
使用普通持久更新，对较大批次把可变性限制在不可逃逸的内部会话中，开发者不需要选择或管理 transient 生命周期。

若这些变化本来就是 child Action，让父领域 Action 携带 `Array<IdentifiedAction<ID, ChildAction>>`，再用
`forEntities` 组合 child reducer；独立表可用 `entityBatchReducer`。它保持重复 ID、Reject/Ignore 和 Effect 顺序，
child 批次只产生一个表版本，parent 在批末运行一次。不要把若干任意根 Action 交给框架自动重排：同一个根 Action
可能被多个 reducer 当作领域事件解释，parent 也可能需要观察相邻 Action 之间的模型；只有显式批 Action 才证明了
“整批 child→一次 parent”的语义边界。

当 Action 除了改变模型还需要“读取文件”“保存文档”或“请求服务”时，不要在 reducer 中直接执行。用
`EffectReducer<Model, Action, Effect>` 返回 `Transition<Model, Effect>`：模型立即保持可测试，Effect 是应用定义的
普通描述值。`EffectStore.dispatch` 先提交模型，再返回 `EffectBatch`；生产入口也可传 `handleEffects`，明确把整个
批次交给文件/网络适配器。应用有多个视图或 Binding 时，在组合根 `connect` 一次解释器，之后向界面传普通
`ScopedStore<Model, Action>`；局部视图不再重复 handler，也看不到根 Effect 类型。框架刻意不自动运行或同步回送
Action，因此解释器的并发、取消、重试和背压不会藏进 Store。

```cangjie role=contrast
class LoadState {
    let status: String
    init(status: String) { this.status = status }
}

let reducer = EffectReducer<LoadState, String, String>({model, action =>
    if (action == "load") {
        Transition<LoadState, String>(LoadState("加载中"), effect: "read-tasks")
    } else {
        Transition<LoadState, String>(model)
    }
})
let effectStore = EffectStore<LoadState, String, String>(LoadState("就绪"), reducer)
let tasks = effectStore.connect(handleEffects: {effects =>
    effects.forEach({command => worker.submit(command)})
})

tasks.dispatch("load")
```

后台 worker 完成后仍用 `DesktopApp.post({=> ... })` 在 UI 线程派发成功/失败 Action。返回批次的重载适合测试；
需要真实执行时优先用 `handleEffects` 重载，它能在模型已经提交但观察者随后失败时仍交付一次效果。Binding 的写入
返回 `Unit`，所以根 `EffectStore.binding` 强制要求显式 handler，不能忘记处理效果；连接后的普通 ScopedStore
Binding 复用组合根已固定的解释器，不再逐控件传递。

## 应用这个模型

下面的对照把可测试规则与控件声明分开。`complete` 只是模型动作，界面可以让按钮、菜单和快捷键都调用它：

```cangjie role=contrast
class TaskModel {
    let selectedId = State<String>("")
    let status = State<String>("请选择任务")

    func select(id: String): Unit {
        selectedId.value = id
        status.value = "已选择 ${id}"
    }
}

func taskToolbar(model: TaskModel): Unit {
    Button("选择 alpha", {=> model.select("alpha")})
    Label(model.status.value)
}
```

当动作和字段继续增长时，同一边界可升级为强类型 store，而不改变控件“只发意图”的角色：

```cangjie role=contrast
class TaskState {
    let selectedId: String
    let status: String

    init(selectedId: String, status: String) {
        this.selectedId = selectedId
        this.status = status
    }
}

let tasks = ModelStore<TaskState, String>(
    TaskState("", "请选择任务"),
    update: {_, id => TaskState(id, "已选择 ${id}")}
)

Button("选择 alpha", {=> tasks.dispatch("alpha")})
Label(tasks.get().status)
```

真实项目通常把 `String` 换成 Action 枚举或带载荷的领域类型。多个已有 Action 必须作为一次原子导入/重放时用
`dispatchAll`；若它们本来表达同一个业务事件，优先定义一个完整 Action，让 reducer 一次完成全部字段变化。

下面的跟踪片段显示边界间只传普通值。工作线程发布结果；UI 帧中的动作才更新状态。失败也应走同一个 `publish`，这样 busy 不会永久停住：

```cangjie role=trace
// desktop/worker：不持有 UI State。
let _ = spawn {
    try {
        mailbox.publish(loadSnapshot())
    } catch (error: Exception) {
        mailbox.publish("加载失败：${error.message}")
    }
}

// views：FrameHandler 回调位于 UI 帧。
FrameHandler(onFrame: {_ =>
    match (mailbox.collect()) {
        case Some(result) => model.status.value = result
        case None => ()
    }
}) { renderWorkbench(model) }
```

这两段的关键不是类名，而是依赖方向：基础设施把结果交给动作，动作更新模型，视图读取模型。控件对象不进入后台闭包，线程锁内不做耗时工作。

## 常见误解

- **“多文件自然等于解耦。”** 若 views 仍直接操作文件、model 仍引用控件，换文件名不会改善边界。
- **“所有状态都应放进一个巨型模型。”** 状态应提升到读写它的最低共同所有者，局部交互不必污染应用模型。
- **“用了 ModelStore 后可以在 reducer 里读文件或启动线程。”** Reducer 必须可重复执行且无副作用；外部工作完成后再 dispatch 结果 Action。
- **“EffectReducer 会自动运行 Effect。”** Effect 只是值；EffectStore 只提交和交付，应用基础设施决定怎样解释并用 `DesktopApp.post` 返回结果。
- **“connect 把 EffectStore 变成了隐式异步运行时。”** connect 只固定一个显式批次 handler；它不决定线程、取消、重试或反馈循环。
- **“连续 dispatch 很多细粒度 Action 就等价于一个领域事件。”** 中间状态会增加 revision 和推理负担；优先完整事件，已有序列才用 `dispatchAll` 原子折叠。
- **“拆了 feature reducer，子视图继续拿根 Store 也算隔离。”** 更新规则虽拆开，根模型和根 Action 仍泄漏；在组合根创建 ScopedStore 才完成运行时边界。
- **“集合 Action 可以携带位置索引。”** 排序、过滤或删除后位置会指向另一对象；跨帧 Action 必须携带稳定业务 ID。
- **“迟到 child Action 一律静默忽略更稳健。”** 它通常意味着取消或生命周期错误；默认 Reject，只有领域明确允许时才 Ignore。
- **“动作函数只能由按钮调用。”** 动作描述业务意图，按钮、菜单、快捷键和测试都可以调用。
- **“错误只需打印到终端。”** 桌面用户需要模型中的可见失败状态，并能重试或取消。
- **“构建闭包适合发起一次性请求。”** 构建会重跑；请求必须由事件动作发起并有稳定所有者。

## 相关 API

- [`State`](../../api/cui/core/State.md) 与 [`DerivedState`](../../api/cui/core/DerivedState.md) — 模型事实和派生结果。
- [`ModelStore`](../../api/cui/core/ModelStore.md)、[`ScopedStore`](../../api/cui/core/ScopedStore.md)、[`Reducer`](../../api/cui/core/Reducer.md) 与 [`Lens`](../../api/cui/core/Lens.md) — 强类型单向数据流、局部运行时边界、组合和特征投影。
- [`IdentifiedArray`](../../api/cui/core/IdentifiedArray.md)、[`IdentifiedAction`](../../api/cui/core/IdentifiedAction.md) 与 [`MissingFeaturePolicy`](../../api/cui/core/MissingFeaturePolicy.md) — 动态子特征身份和缺失语义。
- [`EffectStore`](../../api/cui/core/EffectStore.md)、[`EffectReducer`](../../api/cui/core/EffectReducer.md) 与 [`EffectBatch`](../../api/cui/core/EffectBatch.md) — 纯效果描述与显式解释边界。
- [`FrameHandler`](../../api/cui/core/FrameHandler.md) — UI 帧中的结果收取点。
- [`DesktopApp`](../../api/cui/desktop/DesktopApp.md) — 应用与资源所有者。

## 下一步

在[任务工作台教程](../tutorials/task-workbench.md)中把模型、动作、筛选和主从界面组合成完整程序；需要文件和后台服务时继续[桌面文件与后台任务](../how-to/desktop-files-and-background.md)。
