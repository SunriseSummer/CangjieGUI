[CUI 指南](../index.md) › 焦点与浮层

# 焦点、事件与浮层

## 核心结论

事件描述用户做了什么，焦点决定键盘事件交给谁，浮层决定临时内容的显示和输入优先级，无障碍语义把同一操作暴露给辅助技术。

鼠标、键盘、菜单和辅助技术不应各自实现一套业务规则。控件应把不同输入转换成同一个业务动作，例如“提交”“删除”“选择下一项”。

## 事件怎样传播

布局完成后，指针事件按可见几何命中控件；键盘事件优先交给当前焦点，再按组件树传播。

新组件优先使用 `EventListener`：

- `Capture`：事件到达目标前，由外层先处理。
- `Target`：只在当前目标边界处理。
- `Bubble`：目标处理后向外层返回。

`EventOutcome` 分开表达两件事：事件是否已经处理，以及是否停止继续传播。`Handled` 可以阻止后方兄弟重复响应，同时允许父级继续观察；`StopPropagation` 只截断传播；`Consume` 同时完成两者。

`EventHandler` 是较简单的兼容接口：回调返回 `true` 表示事件已消费。只需要“先于子树处理并返回布尔值”时可以继续使用。

组合键应从 `ctx.eventModifiers()` 读取与当前事件一起采集的修饰键快照。`UiEvent.KeyDown` 的第二个值表示按键是否重复，不是 Ctrl、Shift 等修饰键。

## 指针边界

自定义 `Widget` 默认可能观察布局矩形外的指针事件，因此父容器会采用保守路由。只有当全部指针逻辑都严格检查布局矩形时，才能返回 `PointerEventScope.LayoutBounds` 或使用 `.pointerEventsWithinLayout()`。

这个声明是事件优化承诺，不是绘制裁剪。声明错误会使矩形外本应处理的事件被跳过。活动拖拽仍会回到手势所有者，但不能用拖拽捕获掩盖错误边界。

## 焦点与业务选择

焦点表示“下一个键盘输入交给谁”，业务选择表示“应用当前选中了什么”。两者可以有关联，但不能共用一份不稳定的位置数据。

可聚焦控件按声明顺序进入 Tab 导航。动态列表应使用稳定业务 ID；排序、过滤或删除后，选择仍应指向同一个业务对象。`autofocus()` 对同一组件身份只生效一次，组件卸载后以新身份重新出现时才会再次申请焦点。

焦点环遵循桌面端惯例：通过键盘取得焦点时显示，通过指针点击取得焦点时通常不显示。自定义控件使用 `ctx.showFocusRing(id)` 和 `drawFocusRing` 保持与内建控件一致。

## 无障碍语义

Button、Label、Checkbox 和 TextField 会自动注册基础语义。自定义图表或复合组件应提供：

- 稳定标识和正确边界。
- `SemanticsRole`、可读标签和当前值。
- 启用、选中或勾选状态。
- `Activate`、`Focus`、`Increment`、`Decrement`、`SetValue` 等适用动作。

纯展示内容可使用 `.semantics(...)` 修饰器；完整交互组件在布局时调用 `registerSemantics`，并把语义动作转给鼠标和键盘使用的同一业务函数。

原生无障碍桥和应用安装的 `AccessibilityAdapter` 彼此独立。某个适配器失败时只隔离该分支，不终止帧循环。故障回调运行在 UI 线程，必须快速、非阻塞。

## 浮层怎样选择

浮层显示在普通内容之上，并优先接收相关事件：

| 需求 | 组件 |
|---|---|
| 危险操作确认、必须完成或取消的短流程 | `Modal` |
| 保存成功、复制完成等短消息 | `Toaster` + `ToastLayer` |
| 临时选项 | `Dropdown`、`ContextMenu`、`MenuBar` |
| 自定义正常组件子树的浮层 | `Portal` |
| 框架级绘制和事件回调 | `Overlay` |

`Modal` 不只是居中的 Panel：它还阻止背景交互，并把 Tab 导航限制在对话框内。Toast 不应承载必须由用户处理的错误或恢复步骤。

自定义浮层优先使用 `Portal`。它的内容仍是普通 Widget 子树，保留布局、焦点、状态和语义能力；只是在声明位置不占空间。只有开发底层控件或接入特殊原生表面时，才直接使用 `Overlay`。

## 共享业务动作

按钮、Enter 快捷键和菜单项应该调用同一个 `submit()` 或 `deleteItem(id)`。动作内部统一完成校验、启用判断、状态更新和错误反馈。

例如删除流程可以按以下顺序设计：

1. 工具栏或右键菜单把待删除 ID 写入模型，并打开确认框。
2. Modal 阻止背景表格继续响应。
3. 取消只关闭确认框；确认调用唯一的删除动作。
4. 成功后关闭确认框并显示 Toast；失败时保留可恢复的错误状态。

同一流程的完整可编译示例见[模态确认和 Toast](../how-to/modal-and-toast.md)，键盘路径见[键盘与焦点](../how-to/keyboard-and-focus.md)。

## 常见错误

- 把焦点等同于业务选择。
- 为按钮、快捷键和菜单复制三套校验逻辑。
- 把 KeyDown 的 repeat 标记误当成修饰键。
- 自定义组件无条件消费所有指针事件。
- 把 Modal 当作普通居中容器，导致背景仍可操作。
- 调用 `Toaster.show` 却没有在界面中声明 `ToastLayer`。
- 自绘文字或按钮，却没有提供无障碍语义。

## 相关 API

- [`EventListener`](../../api/cui/core/EventListener.md)、[`EventOutcome`](../../api/cui/core/EventOutcome.md)、[`EventHandler`](../../api/cui/core/EventHandler.md)
- [`UiContext`](../../api/cui/core/UiContext.md)、[`PointerEventScope`](../../api/cui/core/PointerEventScope.md)
- [`Semantics`](../../api/cui/core/Semantics.md)、[`SemanticsNode`](../../api/cui/core/SemanticsNode.md)
- [`Portal`](../../api/cui/core/Portal.md)、[`Overlay`](../../api/cui/core/Overlay.md)
- [`Modal`](../../api/cui/controls/Modal.md)、[`Toaster`](../../api/cui/controls/Toaster.md)、[`ToastLayer`](../../api/cui/controls/ToastLayer.md)

## 下一步

完成[键盘与焦点](../how-to/keyboard-and-focus.md)和[模态确认与 Toast](../how-to/modal-and-toast.md)，用真实交互验证鼠标、Tab、快捷键和浮层边界。
