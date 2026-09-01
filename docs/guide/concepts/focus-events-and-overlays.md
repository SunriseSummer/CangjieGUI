[CUI 指南](../index.md) › 焦点与浮层

# 焦点、事件与浮层

## 先用一句话说明

事件描述用户刚做了什么，焦点决定键盘动作交给谁，语义树把同一操作暴露给辅助技术，浮层则把临时界面放到普通内容之上并优先处理相关交互。

鼠标点击、Tab、方向键和 Enter 不应形成四套业务逻辑。控件把不同输入解释成同一语义动作，例如“提交”“选择下一行”“关闭对话框”，应用模型只处理动作结果。

## 为什么重要

只用鼠标测试的界面可能无法 Tab 到达按钮，焦点留在被关闭的弹层里，或对话框打开后背景仍响应点击。手工伪造 `UiEvent` 调用 `handle` 只能证明方法能执行，不能证明真实应用的命中、焦点顺序、浮层优先级和事件循环协作正确。

桌面应用还需要不同强度的反馈。危险操作要求模态确认并暂时阻止背景交互；保存成功只需短时 Toast，不应打断用户。选择错误的浮层会让操作过重或反馈容易错过。

## 工作模型

应用从 SDL 收集输入并转换成 CUI 事件。布局完成后，指针事件按可见几何命中控件；键盘事件先考虑当前焦点，再由容器或应用级包装器处理快捷键。`EventHandler` 的单参数回调适合无需上下文的兼容动作；新组件用 `EventListener` 声明 Capture、Target 或 Bubble，并返回 `EventOutcome`。Ctrl/Cmd/Shift 组合从 `ctx.eventModifiers()` 读取事件时快照。可聚焦控件按照构建顺序和容器协议参与 Tab 遍历。

`EventOutcome` 不把两个决定压进一个含糊 Bool：`Handled` 阻止事件落到后方兄弟但保留冒泡，`StopPropagation` 截断路径，`Consume` 同时执行两者。多个策略的 `combined` 是逐位并集，满足恒等、结合、交换与幂等；所以手势、审计和业务处理可以分层组合，括号或求值批次不会改变最终路由效果。

多子容器不会假定自定义 `handle` 只处理自身矩形：[`Widget.pointerEventScope`](../../api/cui/core/Widget.md#pointereventscope) 默认 `Unbounded`，因此旧组件和全局手势完整保留。若自定义子树能证明全部指针处理都局限在父容器分配的矩形，可覆盖为 `LayoutBounds`，或链式调用 `.pointerEventsWithinLayout()`。栈、网格、FlowRow 与 ZStack 会把这类矩形按 z 序构成有序 AABB 树，只访问点所在的候选；未声明边界的叶始终参与，按压/拖拽捕获期间也会回退全量路由。该契约不等于绘制 clip，错误声明会使矩形外处理被跳过。

焦点是应用状态的一部分，却不等于业务选择。列表中“当前行”可以与键盘焦点有关，但排序或过滤后仍应由稳定数据 id 保持。内核把易读的 control key 与 generational Element owner 配对：retained 命中继续指向同一元素；元素卸载后即使复用同一 slot 和同名 key，旧焦点也无法别名到新控件。`TextField.autofocus()` 可以正常写在声明式构建中：同一控件身份只请求一次焦点；控件卸载后以新身份重新出现时，才会再次执行这项首次聚焦意图。

Button、Label、Checkbox、TextField 会自动注册平台无关 `SemanticsNode`；自定义图表或复合控件用 `.semantics(Semantics(...), key: ...)` 补充标签和角色。辅助技术请求 `Activate`、`Focus` 或 `SetValue` 时，控件复用鼠标/键盘对应的同一状态动作，不建立第二套业务入口。语义以 retained fragment 组合：缓存布局命中只引用一个子树 patch，平台查询时才扁平化，因此无障碍能力不会把每帧局部布局重新扩大成整树扫描。

桌面原生 provider 与应用安装的 `AccessibilityAdapter` 是独立消费者。每个消费者按语义 revision 幂等推进；新
观察器只收到一次当前快照重放，不会让已经同步的原生桥重复发布。某个消费者抛异常后只熔断该分支，应用可用
`setAccessibilityFailureHandler` 即时记录，也可用 `takeAccessibilityFailures` 取得完整结构化故障。回调运行在
UI 线程，必须保持非阻塞；它自己失败时同样会被隔离而不会终止帧循环。

下拉、菜单、模态和 Toast 使用浮层基础设施。浮层在普通内容之上绘制并优先接收命中。`Modal` 承载真实控件子树并把 Tab 限制在对话框内；当前公开 API 不提供“关闭后恢复到 opener”的目标参数，也不能给普通按钮声明 autofocus，因此应用不应承诺精确恢复点，必须按实际 Tab/Enter 行为验收。`ToastLayer` 显示由 `Toaster` 管理的短时消息；时间驱动的 Toast 需要帧推进，不能创建控制器却忘记渲染层。

自定义弹出内容优先用 `Portal`：body 是正常 Widget 子树，不必把绘制和事件各写成一个 `Overlay` 回调。Portal 在声明位置不占尺寸或间距，却仍获得一次脱离版面的 layout 以登记绝对矩形；因此内部控件的焦点、语义和状态协议与树内一致。只有编写底层控件或适配特殊原生表面时才直接构造 `Overlay`。

## 选择与取舍

- **普通按钮/内联提示**：操作局部、反馈应留在表单附近。
- **Modal**：删除、覆盖、不可逆提交，或必须完成/取消的短流程。
- **Toast**：成功、已复制、后台任务完成等无需立即响应的短消息。
- **Dropdown/ContextMenu**：从临时选项中选择，关闭后回到原任务。
- **应用级事件包装器**：真正全局的快捷键；`EventHandler` 同时提供简洁回调与可访问 `UiContext` 的上下文回调，两者都应复用按钮/菜单的业务动作。
- **组件事件传播**：`EventListener(scope: Subtree)`；外层策略用 Capture，目标动作使用 Target/控件本身，日志与父级协调使用 Bubble。

不要让 Toast 承载错误恢复步骤，也不要用 Modal 报告每个成功操作。反馈强度要与用户需要采取的下一步匹配。

## 应用这个模型

表单提交可以由按钮和 Enter 快捷键调用同一个 `submit()` 动作。动作校验失败时更新内联提示；成功时关闭模态并通过 `Toaster.show` 显示“已保存”。这样输入方式不同，业务状态变化仍只有一条路径。

```cangjie role=contrast
EventHandler(onEvent: {event =>
    match (event) {
        case UiEvent.KeyDown(Key.Enter, _) =>
            submit()
            true
        case _ => false
    }
}) {
    Button("提交", {=> submit()}).role(ButtonRole.Primary)
}
```

自定义画布需要显式说明用途：

```cangjie role=trace
CanvasWidget({renderer, rect => drawChart(renderer, rect)})
    .semantics(Semantics(label: "本月销售趋势", role: SemanticsRole.Image), key: "sales.chart")
```

`true` 表示这次 Enter 已被转成提交动作；其他事件返回 `false`，继续交给当前焦点控件。按钮和键盘没有复制校验规则。

删除联系人时，右键菜单和工具栏都把待删除 id 写入模型并打开同一 `Modal`；确认按钮执行删除，取消只关闭。背景表格不应在模态打开时响应选择变化。

这段跟踪代码把“请求确认 → 阻断背景 → 确认 → Toast”放在同一控件树中。`requestDelete` 与 `confirmDelete` 是模型动作，输入控件只调用它们：

```cangjie role=trace
ZStack {
    Button("删除", {=> model.requestDelete(selectedId.value)}, role: ButtonRole.Danger)
    Modal(model.confirming, onDismiss: {=> model.cancelDelete()}) {
        HStack {
            Button("取消", {=> model.cancelDelete()})
            Button("确认", {=> model.confirmDelete(toaster)}, role: ButtonRole.Danger)
        }
    }
    ToastLayer(toaster)
}
```

## 常见误解

- **“焦点就是选中项。”** 焦点表示键盘输入目标，业务选择应由模型和稳定 id 保存。
- **“把 autofocus 写在构建中会每帧抢焦点。”** 同一控件身份只请求一次；真正要检查的是稳定身份以及卸载后重新挂载是否符合预期。
- **“Toast 只要调用 show 就会出现。”** 需要在界面中存在对应渲染层并由帧推进超时。
- **“全局快捷键可以复制按钮逻辑。”** 复制后启用条件和错误处理会分叉，应共享动作函数。
- **“KeyDown 的第二个值是修饰键。”** 它是 repeat `Bool`；组合键读取当前事件的 `ctx.eventModifiers()`，不查询延迟派发后的全局快照。
- **“模态只是一个居中的 Panel。”** 它还承担背景交互阻断和焦点边界。
- **“画出来的文字自然能被读屏识别。”** 自绘像素没有平台语义；内建控件自动提供，自定义画布必须声明。

## 相关 API

- [`EventHandler`](../../api/cui/core/EventHandler.md) — 应用级事件处理入口。
- [`EventListener`](../../api/cui/core/EventListener.md)、[`EventOutcome`](../../api/cui/core/EventOutcome.md) — 捕获/目标/冒泡与可组合传播效果。
- [`Modal`](../../api/cui/controls/Modal.md) — 模态内容和确认/取消交互。
- [`Toaster`](../../api/cui/controls/Toaster.md) 与 [`ToastLayer`](../../api/cui/controls/ToastLayer.md) — 消息状态与渲染层。
- [`TextField`](../../api/cui/text/TextField.md) — 文本焦点和编辑。
- [`Semantics`](../../api/cui/core/Semantics.md) 与 [`SemanticsNode`](../../api/cui/core/SemanticsNode.md) — 无障碍属性、边界与动作。
- [`Portal`](../../api/cui/core/Portal.md) — 声明式浮层子树；[`Overlay`](../../api/cui/core/Overlay.md) 是低层回调协议。

## 下一步

在[模态确认与 Toast](../how-to/modal-and-toast.md)中选择合适反馈强度，再到[键盘与焦点](../how-to/keyboard-and-focus.md)让鼠标、Tab 和快捷键共享业务动作。
