[CUI 指南](../index.md) › 模态与通知

# 使用模态确认和 Toast 反馈

## 目标

为删除等高风险操作提供必须确认的模态界面，为保存成功等低风险结果提供短时非阻塞 Toast。两种反馈共享业务动作，却使用不同交互强度，背景内容和焦点行为保持可预测。

## 适用场景

删除、覆盖、不可逆提交或必须完成的小流程使用 `Modal`；“已保存”“已复制”“后台任务完成”使用 Toast。字段错误优先放在字段附近，不要让用户关闭弹层后再寻找错误位置。

## 准备工作

先读[焦点、事件与浮层](../concepts/focus-events-and-overlays.md)。模型应有待确认对象 id、模态是否打开和一个长期存在的 `Toaster`。确认动作能够被按钮、菜单和快捷键共同调用；不要把业务删除逻辑写死在某个控件对象里。

## 操作步骤

### 1. 危险动作只打开确认

点击“删除”时记录目标 id 并显示 `Modal`，此时不修改数据。模态正文说明对象和后果，提供明确的“取消”“删除”按钮。用 `initialFocus` 指定对话框内按钮的稳定 key，例如优先聚焦“取消”；未指定或未匹配时选择首个内部焦点项。关闭时恢复先前控件身份；该控件已卸载时选择存活的后备焦点。

### 2. 确认后执行共享动作

“删除”按钮调用模型函数，根据 id 更新数组并关闭模态。工具栏和右键菜单都走同一个入口，避免启用条件和错误处理分叉。

### 3. 成功后显示 Toast

动作完成后调用 `toaster.show(...)`。界面树中同时存在 `ToastLayer(toaster)`，否则消息状态没有可见承载。Toast 自动消失，需要帧推进；不要用阻塞睡眠等待它。

下面的完整程序把危险动作、确认状态和成功通知连成一条路径。模型保存项目数组与 `pendingId`，行按钮只调用 `requestDelete(id)`，真正删除集中在 `confirmDelete`。`Toaster` 在应用构建闭包之外只创建一次；内容层和通知层同时出现在根 `ZStack` 中。为了让程序一启动就展示本页的核心界面，示例在进入事件循环前请求删除“发布清单”；关闭模态框后，两个行按钮仍可正常重复演练：

```cangjie verify role=complete profile=gui-visual
package docexample

import std.collection.ArrayList
import cui.*

class Project {
    let id: String
    let name: String

    init(id: String, name: String) {
        this.id = id
        this.name = name
    }
}

class DeleteModel {
    let projects = State<Array<Project>>(
        [
            Project("alpha", "迁移计划"),
            Project("beta", "发布清单")
        ]
    )
    let pendingId = State<String>("")
    let confirming = State<Bool>(false)
    let status = State<String>("请选择要删除的项目")

    func requestDelete(id: String): Unit {
        if (projectName(id).isEmpty()) {
            return
        }
        pendingId.value = id
        confirming.value = true
    }

    func requestFirstDelete(): Bool {
        // 根级 EventHandler 比子树先收到按键；Modal 打开时必须在动作入口拒绝背景动作。
        if (confirming.value || projects.value.size == 0) {
            return false
        }
        requestDelete(projects.value[0].id)
        true
    }

    func cancelDelete(): Unit {
        pendingId.value = ""
        confirming.value = false
    }

    func confirmDelete(toaster: Toaster): Unit {
        let targetId = pendingId.value
        let deletedName = projectName(targetId)
        let remaining = ArrayList<Project>()
        for (project in projects.value) {
            if (project.id != targetId) {
                remaining.add(project)
            }
        }
        cancelDelete()
        if (deletedName.isEmpty()) {
            status.value = "项目已不存在"
            return
        }
        projects.value = remaining.toArray()
        status.value = "已删除 ${deletedName}"
        toaster.show("已删除 ${deletedName}", kind: ToastKind.Success)
    }

    func projectName(id: String): String {
        for (project in projects.value) {
            if (project.id == id) {
                return project.name
            }
        }
        ""
    }
}

func handleDeleteShortcut(model: DeleteModel, event: UiEvent): Bool {
    match (event) {
        case UiEvent.KeyDown(Key.Delete, _) => model.requestFirstDelete()
        case _ => false
    }
}

main(): Unit {
    let model = DeleteModel()
    let toaster = Toaster()
    model.requestDelete("beta")
    // 对话框已为 beta 打开；再次发起背景删除必须被动作入口拒绝。
    if (model.requestFirstDelete() || model.pendingId.value != "beta") {
        throw IllegalStateException("Modal 打开时不能替换待确认项目")
    }
    let app = DesktopApp(WindowSpec("确认与通知", 560, 360))
    app.run {
        EventHandler(onEvent: {event => handleDeleteShortcut(model, event)}) {
            ZStack {
                VStack(spacing: 12.vp) {
                    Label("选中项目后按 Delete，或点击右侧按钮").muted()
                    Label(model.status.value)
                    if (model.projects.value.size == 0) {
                        Label("没有剩余项目").muted()
                    }
                    ForEach(model.projects.value, key: {project => project.id}) {
                        project => HStack {
                            Label(project.name).flex()
                            Button("删除", {=> model.requestDelete(project.id)}, role: ButtonRole.Danger)
                        }
                    }
                }.padding(24.vp)
                Modal(model.confirming, onDismiss: {=> model.cancelDelete()}) {
                    VStack(spacing: 12.vp) {
                        Label("确定删除 ${model.projectName(model.pendingId.value)}？").bold()
                        HStack {
                            Button("取消", {=> model.cancelDelete()})
                            Button("确认删除", {=> model.confirmDelete(toaster)}, role: ButtonRole.Danger)
                        }.spacing(8.vp)
                    }.spacing(8.vp)
                }
                ToastLayer(toaster)
            }
        }
    }
}
```

完整程序已经用最外层 `EventHandler` 把 Delete 映射到 `requestFirstDelete()`。处理器先于子树收到按键，因此动作入口必须检查 `confirming`。Modal 打开或项目为空时返回 `false`，不修改 `pendingId`，随后由正常浮层路由继续处理。

### 4. 错误使用可恢复反馈

删除失败且用户必须选择下一步时，保留模态或显示内联错误；短时 Toast 不适合承载长错误和修复步骤。错误信息应保留具体对象与原因。

## 确认结果

程序启动后应立即显示“发布清单”的删除确认，且 `pendingId == "beta"`。模态打开时按 Delete：事件不得被背景快捷键消费，`pendingId` 仍须是 `beta`，标题也不变。取消后两行仍在。再次点击“发布清单”的删除按钮并确认后，只剩“迁移计划”，状态与 Toast 都包含“发布清单”。模态打开期间背景行按钮不应响应。分别用 Esc、遮罩、取消和确认关闭，再按 Tab 记录实际进入的控件；当前 API 不保证恢复到打开按钮，本页不把某个固定恢复点作为通过条件。连续删除两项时，Toast 按请求顺序出现并按时消失。

## 常见错误

- 点击删除按钮立即改数据，再打开“确认”作为通知。
- 只创建 `Toaster` 并调用 `show`，没有把 `ToastLayer` 放进界面。
- 为所有成功动作弹模态，迫使用户额外点击。
- 用 Toast 显示必须抄写的长错误，消息消失后无法恢复。
- 模态只是视觉面板，背景仍接受点击或快捷键。
- 菜单、按钮和键盘分别复制删除逻辑，结果不一致。

## 相关 API

- [`Modal`](../../api/cui/controls/Modal.md) — 模态内容与背景交互边界。
- [`Toaster`](../../api/cui/controls/Toaster.md) 与 [`ToastLayer`](../../api/cui/controls/ToastLayer.md) — 消息队列和显示层。
- [`Button`](../../api/cui/core/Button.md) — 确认/取消动作。
- [`State`](../../api/cui/core/State.md) — 待确认 id 与打开状态。

## 下一步

继续[键盘与焦点](keyboard-and-focus.md)，让工具栏、菜单和快捷键复用同一动作。浮层未阻断背景或 Toast 不消失时，到[常见问题](../troubleshooting/common-problems.md)诊断。
