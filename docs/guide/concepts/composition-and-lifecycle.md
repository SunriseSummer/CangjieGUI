[CUI 指南](../index.md) › 构建与生命周期

# 声明式构建与应用生命周期

## 先用一句话说明

应用对象持续运行窗口和事件循环，构建函数则根据当前数据反复描述这一刻应该出现的控件树。

这不是“每帧重新启动应用”，而是把界面视为状态的结果。构建函数可以多次执行，因此它必须便宜、可重复，不能把一次性副作用当成普通界面声明。

## 为什么重要

初学者常把 `app.run { ... }` 当只执行一次的初始化，于是在里面读取大文件、启动后台任务、追加全局列表或调用撤销。构建再次发生时，这些副作用重复执行，表现为卡顿、数据重复或状态跳变。另一种错误是把输入值存在普通局部变量里；下一次构建它重新初始化，用户刚输入的内容消失。

理解生命周期后，你能决定三件事：持久数据放在状态/模型中，一次性资源由明确拥有者创建和关闭，构建函数只读取状态并声明控件。用户事件修改模型，框架安排下一次需要的构建和绘制。

## 工作模型

`DesktopApp` 创建并持有底层窗口、渲染环境、帧循环和状态存储。它收集 SDL 事件，确定是否需要重绘，按 `State` 的真实读取依赖只执行脏的声明作用域，再完成必要的测量、布局和绘制。闲置时不会为了“声明式”而无意义地持续刷新；状态写入、输入、动画或主动请求帧会推进更新。普通 `VStack`、`Panel` 等 builder body 自动进入组合图；框架还会自动晋升少量复杂渲染边界、缓存稳定显示列表并计算局部 damage，开发者不需要添加 memo、revision、`cachePaint` 或 retained 包装。

构建函数中的 `VStack { Label(...); Button(...) }` 描述父子关系。顶层直接声明零个、一个或多个控件也会自动形成可复用的逻辑根，不必为了性能额外包一层 `VStack`。控件对象可以在本次构建中创建，但业务事实不能依赖这些临时对象的身份。固定结构中的 `remember`、`rememberState`、keyless `mountEffect` / `lifecycleEffect` 共用受形状守卫的位置槽，分别保留稳定对象、可写状态与资源生命周期；`Keyed`/`ForEach` 与显式键把动态数据身份带入逻辑位置。

事件回调是改变状态的边界。按钮点击、文本输入或键盘动作在事件事务中写入模型；`State` 写推进应用级调度代数，宿主在本帧 draw 前稳定重建，使可见结果立即反映。只改普通 `var` 不会触发这一步。不要在构建阶段主动调用控件的 `handle`、`layout` 或伪造输入事件，这会绕过应用正常协议，也不能代表用户真的能完成交互。

## 选择与取舍

- **构建函数内**：读取状态、计算轻量派生值、选择控件、设置样式与回调。
- **状态或模型中**：用户输入、选择、业务数据、需要跨帧/跨构建保留的值。
- **事件回调中**：短小的状态更新和动作派发。
- **后台任务中**：耗时 I/O 或计算；结果通过线程安全边界带回 UI 线程，再更新状态。
- **资源拥有者中**：文件、图像、观察订阅等需要关闭的对象；生命周期必须明确，不能每次构建悄悄创建。

“普通构建创建控件值”并不等于每个 body 或阶段都会无条件执行。框架自动复用没有脏依赖的声明作用域，复杂干净兄弟可同时跳过 measure/layout/draw；折叠面板只在展开时构建内容，虚拟列表只构建视口附近项目。`RetainedSubtree` 仍可用于底层实验、兼容和强制诊断对照，但不再是常规性能写法。

## 应用这个模型

计数器中，应用对象只创建一次；`count` 由状态存储保留；标签和按钮每次从同一状态描述。点击按钮不会直接找到旧标签对象并改文字，而是写入 `count.value`，下次构建产生带新文字的标签。

```cangjie role=contrast
app.run {
    let count = rememberState<Int64> {0}
    VStack {
        Label("计数：${count.value}")
        Button("加一", {=> count.value += 1})
    }
}
```

这段代码从语义上持续描述标签和按钮；运行时只在 `counter` 变化所覆盖的脏路径执行相关 body。
位置槽对应的值由应用状态存储保留。回调只改事实，不直接寻找并修改旧标签对象；若这段状态进入条件或循环，应改用显式键与 `Keyed`/`ForEach`。

如果要加载文件，不应在每次构建都 `read`。后台线程也不能直接写 UI `State`。下面的信箱只让工作线程发布普通字符串；`FrameHandler` 的回调运行在 UI 帧中，取出结果后才更新 `status`。把信箱和 `status` 创建在 `app.run` 外，避免构建时重复启动任务：

```cangjie role=trace
import std.sync.Mutex

class ResultMailbox {
    private let mutex = Mutex()
    private var pending: ?String = None

    func request(): Unit {
        let _ = spawn {
            publish("后台结果已就绪")
        }
    }

    private func publish(result: String): Unit {
        synchronized(mutex) {
            pending = Some(result)
        }
    }

    func collect(): ?String {
        synchronized(mutex) {
            let result = pending
            pending = None
            return result
        }
    }
}

let mailbox = ResultMailbox()
let status = State<String>("尚未加载")

FrameHandler(onFrame: {_ =>
    match (mailbox.collect()) {
        case Some(result) => status.value = result
        case None => ()
    }
}) {
    VStack {
        Label(status.value)
        Button("开始加载", {=> mailbox.request()})
    }
}
```

这条路径中，`spawn` 从不接触 UI 状态，锁内也只交换结果，不执行耗时工作。一次性任务可在忙碌期间条件挂载 `FrameHandler`；持续采样应用可以像进程管理器示例那样保留帧处理器。

## 常见误解

- **“声明式等于每帧无条件重绘。”** 应用按状态、事件和动画需求推进，不需要把空闲循环当业务模型。
- **“局部变量会像控件状态一样保留。”** 普通局部值随构建重新计算；跨构建事实需要状态或外部模型。
- **“回调里可以手工布局控件。”** 应修改数据，让框架走正常构建和布局。
- **“构建次数越少越正确。”** 正确目标是构建可重复、无副作用且依赖精确；框架可以跳过未变 scope，但必要的状态改变必须重建并在 draw 前稳定。

## 相关 API

- [`DesktopApp`](../../api/cui/desktop/DesktopApp.md) — 应用、窗口和帧循环所有权。
- [`State`](../../api/cui/core/State.md) 与 [`rememberState`](../../api/cui/core/functions.md#rememberstate) — 跨构建数据。
- [`Keyed`](../../api/cui/core/Keyed.md) — 稳定身份作用域。
- [`FrameHandler`](../../api/cui/core/FrameHandler.md) — 需要按帧推进的公开入口。
- [自动增量 UI 架构](../../automatic-incremental-architecture.md) — 自动依赖图、选择性渲染节点、显示列表预算与 damage。

## 下一步

继续[状态、绑定与派生值](state-and-binding.md)，为表单和列表决定事实来源与修改权限；随后完成[设置表单](../tutorials/settings-form.md)，把生命周期原则应用到真实输入流程。
