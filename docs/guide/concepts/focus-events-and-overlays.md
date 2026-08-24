[CUI 指南](../index.md) › 焦点与浮层

# 焦点、事件与浮层

## 先用一句话说明

事件描述用户刚做了什么，焦点决定键盘动作交给谁，浮层则把临时界面放到普通内容之上并优先处理相关交互。

鼠标点击、Tab、方向键和 Enter 不应形成四套业务逻辑。控件把不同输入解释成同一语义动作，例如“提交”“选择下一行”“关闭对话框”，应用模型只处理动作结果。

## 为什么重要

只用鼠标测试的界面可能无法 Tab 到达按钮，焦点留在被关闭的弹层里，或对话框打开后背景仍响应点击。手工伪造 `UiEvent` 调用 `handle` 只能证明方法能执行，不能证明真实应用的命中、焦点顺序、浮层优先级和事件循环协作正确。

桌面应用还需要不同强度的反馈。危险操作要求模态确认并暂时阻止背景交互；保存成功只需短时 Toast，不应打断用户。选择错误的浮层会让操作过重或反馈容易错过。

## 工作模型

应用从 SDL 收集输入并转换成 CUI 事件。布局完成后，指针事件按可见几何命中控件；键盘事件先考虑当前焦点，再由容器或应用级包装器处理快捷键。`EventHandler` 的单参数回调适合无需上下文的动作；Ctrl/Cmd/Shift 组合使用双参数回调，从 `ctx.eventModifiers()` 读取事件时快照。可聚焦控件按照构建顺序和容器协议参与 Tab 遍历。

焦点是应用状态的一部分，却不等于业务选择。列表中“当前行”可以与键盘焦点有关，但排序或过滤后仍应由稳定数据 id 保持。`TextField.autofocus()` 可以正常写在声明式构建中：同一控件身份只请求一次焦点；控件卸载后以新身份重新出现时，才会再次执行这项首次聚焦意图。

下拉、菜单、模态和 Toast 使用浮层基础设施。浮层在普通内容之上绘制并优先接收命中。`Modal` 承载真实控件子树并把 Tab 限制在对话框内；当前公开 API 不提供“关闭后恢复到 opener”的目标参数，也不能给普通按钮声明 autofocus，因此应用不应承诺精确恢复点，必须按实际 Tab/Enter 行为验收。`ToastLayer` 显示由 `Toaster` 管理的短时消息；时间驱动的 Toast 需要帧推进，不能创建控制器却忘记渲染层。

## 选择与取舍

- **普通按钮/内联提示**：操作局部、反馈应留在表单附近。
- **Modal**：删除、覆盖、不可逆提交，或必须完成/取消的短流程。
- **Toast**：成功、已复制、后台任务完成等无需立即响应的短消息。
- **Dropdown/ContextMenu**：从临时选项中选择，关闭后回到原任务。
- **应用级事件包装器**：真正全局的快捷键；`EventHandler` 同时提供简洁回调与可访问 `UiContext` 的上下文回调，两者都应复用按钮/菜单的业务动作。

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

## 相关 API

- [`EventHandler`](../../api/cui/core/EventHandler.md) — 应用级事件处理入口。
- [`Modal`](../../api/cui/controls/Modal.md) — 模态内容和确认/取消交互。
- [`Toaster`](../../api/cui/controls/Toaster.md) 与 [`ToastLayer`](../../api/cui/controls/ToastLayer.md) — 消息状态与渲染层。
- [`TextField`](../../api/cui/text/TextField.md) — 文本焦点和编辑。

## 下一步

在[模态确认与 Toast](../how-to/modal-and-toast.md)中选择合适反馈强度，再到[键盘与焦点](../how-to/keyboard-and-focus.md)让鼠标、Tab 和快捷键共享业务动作。
