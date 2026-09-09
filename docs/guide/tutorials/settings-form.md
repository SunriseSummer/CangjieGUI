[CUI 指南](../index.md) › 设置表单

# 构建一个会校验的设置表单

## 你将完成

你会构建一个包含姓名输入、条款勾选、提交按钮和结果提示的桌面表单。空姓名时提示“请输入姓名”；填写姓名但未勾选时提示“请先同意条款”；两项满足后显示欢迎文字。输入控件、按钮和提示始终读取同一份状态，窗口重建不会清空内容。

这个教程把计数器扩展成真实任务：多个可写字段共同决定一次操作是否成功。重点不是控件数量，而是数据所有权、校验发生时机、阅读/焦点顺序和可观察反馈。

## 开始之前

先完成[第一个窗口](../getting-started/first-window.md)，阅读[构建生命周期](../concepts/composition-and-lifecycle.md)和[状态与绑定](../concepts/state-and-binding.md)。沿用同一个 `docexample` 项目、依赖和 SDL 运行环境。

本例在点击提交时校验，以便清楚观察三条路径。更复杂表单可以派生 `canSubmit` 来提前禁用按钮，但错误提示仍应说明哪一项需要修正，而不只是让按钮不可用。

## 先建立一个模型

表单有三份事实：用户输入的姓名、是否同意条款、最近一次提交结果。`TextField` 和 `Checkbox` 需要可写绑定，所以直接接收前两份 `State`；按钮回调读取它们并更新提示。标签只显示提示，不再保存另一份结果。

控件树按用户完成任务的顺序排列：标题 → 姓名 → 条款 → 提交 → 结果。这个顺序同时影响视觉阅读和默认 Tab 焦点遍历。把结果放在按钮后面，用户操作后无需回头寻找反馈。

## 操作步骤

### 1. 在固定声明中创建位置状态

在 `app.run` 的固定声明顺序中创建姓名、同意状态和提示。keyless 位置槽由框架保留并验证形状，不需要为每个字段发明字符串；若以后把字段放进条件、循环或可重排区域，再改用显式键与 `Keyed`/`ForEach`。

### 2. 把输入控件绑定到事实

`TextField(name)` 直接读写姓名，`Checkbox(..., accepted)` 直接读写布尔值。不要在回调中从控件对象“取值”；控件对象会随构建变化，状态才是事实来源。

### 3. 把校验集中在提交动作

回调按用户最容易修复的顺序检查：先姓名，再条款，最后成功。每个分支只更新提示。若未来把校验抽成函数，仍让函数接收值并返回结果，避免它反向操控控件。

### 4. 明确反馈

最后一个 `Label` 每次读取 `message.value`。成功文字包含姓名，证明输入值确实流经校验而不是只切换了固定布尔状态。

## 完整程序

```cangjie verify role=complete profile=gui-visual
package docexample

import cui.*

main(): Unit {
    let app = DesktopApp(WindowSpec("账户设置", 460, 320))
    app.run {
        let name = rememberState<String> {""}
        let accepted = rememberState<Bool> {false}
        let message = rememberState<String> {"请填写表单"}

        VStack(spacing: 12.vp) {
            Label("创建账户").bold()
            TextField(name)
            Checkbox("我已阅读并同意条款", accepted)
            Button("提交", {
                => if (name.value.trimAscii().isEmpty()) {
                    message.value = "请输入姓名"
                } else if (!accepted.value) {
                    message.value = "请先同意条款"
                } else {
                    message.value = "欢迎，${name.value}"
                }
            }).role(ButtonRole.Primary)
            Label(message.value)
        }.padding(20.vp)
    }
}
```

## 从单文件到多文件

先把本页程序的字段与校验迁入 `model.cj`，把组件声明迁入 `views.cj`，`main.cj` 只装配模型与窗口。三个文件使用同一包名；拆分后重跑下面的三条校验路径，行为应保持一致。

进一步阅读仓库 [settings 示例](../../../examples/settings/README.md)。它是使用折叠分区的完整设置应用，提供外观、通知、隐私和关于页面；可用于比较同样的模型与视图边界，但并非本页姓名表单的拆分副本。

## 确认结果

先对单文件检查点执行 `cjpm run`，确认标题、输入框和按钮与窗口四边保持 20 vp 留白。再按以下顺序验证：不输入直接点“提交”，显示“请输入姓名”；输入“林”但不勾选，显示“请先同意条款”；勾选后再次提交，显示“欢迎，林”。用 Tab 依次经过文本框、复选框和按钮，Enter/Space 操作与鼠标结果一致。窗口缩放和状态更新后，姓名不应消失。拆分文件后重新验证这组行为。

## 接着试一试

1. 增加一个只读摘要 `Label("UTF-8 字节数：${name.value.size}")`，直接从姓名计算，不创建第二份状态。
2. 用 `derive(name, accepted)` 得到 `canSubmit`，让按钮在条件不满足时禁用；仍保留清楚的字段说明。
3. 将三份字段放进一个 `ProfileDraft`，再用 `project` 给输入控件字段绑定。比较“多个小状态”和“一个整体状态”的所有权差异。

第一项变化不需要新状态。在 `TextField(name)` 后声明 `Label("UTF-8 字节数：${name.value.size}").muted()`，输入时它会从同一事实重新计算。

## 如果没有成功

- **输入后立即清空**：检查是否使用 `rememberState`，位置槽是否保持固定（动态结构则检查显式键），文本框是否接收同一状态。
- **点击始终走同一分支**：确认回调读取 `.value`，且没有在构建阶段重置状态。
- **Tab 顺序混乱**：按任务顺序声明可聚焦控件，不要用纯视觉偏移掩盖代码顺序。
- **按钮点击但提示不变**：标签应读取 `message.value`，回调也必须写入同一对象。

## 相关 API

- [`TextField`](../../api/cui/text/TextField.md) — 文本绑定、焦点和编辑行为。
- [`Checkbox`](../../api/cui/controls/Checkbox.md) — 布尔绑定与键盘操作。
- [`Button`](../../api/cui/core/Button.md) — 动作回调和语义角色。
- [`State`](../../api/cui/core/State.md) 与 [`Bindable.project`](../../api/cui/core/Bindable.md#project) — 表单事实和字段的双向绑定。

## 下一步

读[模型、动作与界面边界](../concepts/app-architecture.md)，然后完成[任务工作台](task-workbench.md)，把单页表单扩展成可维护应用。

需要在更多窗口尺寸下排布字段时，继续[选择布局容器](../how-to/choose-layout.md)和[布局约束与滚动](../concepts/layout-and-scrolling.md)。需要在提交前做确认或成功后显示短时反馈时，继续[模态确认与 Toast](../how-to/modal-and-toast.md)。
