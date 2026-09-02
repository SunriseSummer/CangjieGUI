[CUI 指南](../index.md) › 键盘与焦点

# 让鼠标、Tab 和快捷键共享业务动作

## 目标

让主要操作既可用鼠标，也能按可预测的 Tab 顺序到达并用键盘触发；应用级快捷键与按钮、菜单调用同一业务函数。焦点决定按键应交给哪个控件，当前选择仍由业务 id 保存。

## 适用场景

表单提交、列表导航、命令面板、菜单和桌面编辑器都需要。若问题发生在模态或下拉覆盖背景内容时，先读[焦点、事件与浮层](../concepts/focus-events-and-overlays.md)。

## 准备工作

列出语义动作，例如 `submit`、`deleteSelected`、`moveSelection`、`closeDialog`。每个动作写一次启用条件、状态更新和错误处理。控件回调和键盘映射只负责调用动作，不各自复制业务判断。

## 操作步骤

### 1. 按任务顺序声明可聚焦控件

表单使用输入 → 选项 → 提交的构建顺序。首要文本输入可以在声明式构建中使用 `autofocus()`；同一控件身份只请求一次，禁用控件应从遍历中合理跳过。若条件分支卸载后重新创建输入框，它会以新身份再次执行首次聚焦。

### 2. 让控件处理标准键

按钮的 Enter/Space、列表方向键、菜单导航等优先使用控件内建行为。不要在应用根重复拦截所有按键，否则文本编辑、组合键和弹层优先级容易冲突。

### 3. 只为全局动作添加 EventHandler

全局动作可以由 `EventHandler` 捕获。Enter、Escape、Delete 等无需事件上下文时使用单参数回调；Ctrl/Cmd/Shift 组合键使用双参数回调，从 `ctx.eventModifiers()` 读取事件时刻快照。处理前检查模态/输入语境和动作启用条件，并调用与按钮相同的函数，详见[文本与菜单](text-editing-and-menus.md)。

全局 Delete 快捷键只负责发起与行按钮相同的删除请求，不复制确认或修改数组的逻辑。这样鼠标与键盘经过同一检查，也会打开同一个确认对话框。

在[模态与 Toast](modal-and-toast.md)的完整程序中，最外层 `EventHandler` 已经把 Delete 映射到 `model.requestFirstDelete()`。没有项目或 Modal 已打开时，动作返回 `false`，让事件继续正常传播，并且不修改待确认对象。

同时把基页 `requestFirstDelete()` 的首个条件保持为 `confirming.value || projects.value.size == 0`。这一动作入口守卫是第二道边界：以后即使菜单或别的根级处理器复用它，也不能在 Modal 已打开时改写待确认对象。

还可以在状态标签后增加“删除第一项”工具栏按钮，让它同样调用 `requestFirstDelete()`，用于比较鼠标和快捷键是否得到同一个确认对话框。按钮是否存在不改变模型中的守卫条件。

### 4. 把选择与焦点分开

列表选中项存业务 id。焦点移动到工具栏时，选择可以保留；排序或过滤时，选择按 id 更新。不要用“当前聚焦的屏幕行号”代替模型选择。

### 5. 测试完整键盘路径

从窗口打开开始，不碰鼠标完成主要任务：Tab 到控件、输入、切换、提交、关闭弹层。再用鼠标完成同一任务，比较最终模型状态。

## 确认结果

Tab 顺序与视觉阅读一致，焦点样式可见；Enter/Space 触发正确动作；文本框中的普通按键不会被全局处理器抢走。专门回放：用行按钮为 `beta` 打开 Modal，按 Delete 后处理器返回 `false`、`pendingId` 仍为 `beta`，确认后删除的仍是 `beta`；这证明外层处理器没有越过模态边界。鼠标和键盘应得到同一成功/错误提示。排序列表后，选择仍指向同一 id。

## 常见错误

- 条件分支不断改变控件身份，导致 autofocus 被当作“首次出现”反复执行。
- 在根部拦截方向键，导致文本光标和列表导航冲突。
- 快捷键绕过按钮的禁用条件，执行本不允许的动作。
- 把焦点位置当业务选择，离开列表后详情清空。
- 只测试鼠标点击，焦点环、Tab 顺序和 Esc 关闭从未验证。
- 弹层关闭后焦点落到已不存在的控件。

## 相关 API

- [`EventHandler`](../../api/cui/core/EventHandler.md) — 应用级键盘处理。
- [`Button`](../../api/cui/core/Button.md) 与 [`TextField`](../../api/cui/text/TextField.md) — 标准焦点/键盘行为。
- [`ListView`](../../api/cui/controls/ListView.md) — 选择与方向键导航。
- [`Modal`](../../api/cui/controls/Modal.md) — 焦点和背景交互边界。

## 下一步

把共享动作与[模态确认和 Toast](modal-and-toast.md)组合，继续[文本编辑与菜单](text-editing-and-menus.md)，或到[常见问题](../troubleshooting/common-problems.md)排查焦点丢失、快捷键冲突和背景误响应。
