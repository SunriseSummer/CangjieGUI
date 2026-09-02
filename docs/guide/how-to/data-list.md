[CUI 指南](../index.md) › 数据列表

# 构建有稳定身份的数据列表

## 目标

构建一个可选择、过滤和重排的任务列表。每个任务由业务 id 标识；反转显示顺序后，选择和行内展开状态仍跟随原任务。过滤隐藏选中项时，应用明确选择第一条仍可见任务，而不是让旧行号指向别的对象。

## 适用场景

任务清单、联系人、文件、聊天消息和看板卡片都需要这套方法。若数据固定且只有几项，普通 `VStack` 足够；若需要列排序和固定表头，继续[表格主从界面](table-master-detail.md)。项目数量大时先保持本页的数据身份设计，再把普通构建替换成虚拟容器。

## 准备工作

沿用[第一个窗口](../getting-started/first-window.md)中的 `docexample` 项目、`cui` 依赖和 SDL 运行环境；本页给出完整 `main.cj`，不需要从计数器拼接未定义的模型。先理解[布局约束、滚动与虚拟化](../concepts/layout-and-scrolling.md)。为数据类型确定稳定 id：它在项目生命周期内不变，且不依赖当前数组索引。

## 操作步骤

### 1. 一份数组作为事实来源

`TaskListModel.tasks` 保存完整任务数组，`openOnly` 只保存筛选开关；可见数组每次从两者计算。新增、编辑和删除应整体写回 `tasks.value`，不要再保存一份需要手工同步的“过滤数组”。

### 2. 选择保存业务 id

模型用 `selectedId` 保存选择。详情文字每次按 id 从完整数组查找，所以数组位置变化不会改变选择含义。若筛选隐藏选中任务，`toggleOpenOnly` 明确改选第一条可见任务；没有可见项时才清空 id。

### 3. 按 id 构建项目子树

`ForEach(..., key:)` 为每项建立稳定作用域。下面的 `taskRow` 在该作用域中使用同名 `rememberState("expanded")`；键先由任务 id 分区，所以不同任务不会互相覆盖。`ForEach` 用每项的业务 id 建立稳定作用域，因此反转显示顺序时，行内展开状态仍跟随原任务。

### 4. 让重排只改变位置

`reverseOrder` 创建反向数组并整体写回。它不修改任务 id，也不把选择换算成行号。筛选只决定哪些任务进入当前控件树；被过滤任务的行内状态会随卸载清理，需要跨过滤保留的业务状态应提升到模型。

下面是可直接放进空项目 `src/main.cj` 的完整程序：

```cangjie verify role=complete profile=gui-visual
package docexample

import std.collection.ArrayList
import cui.*

class Task {
    let id: String
    let title: String
    let done: Bool

    init(id: String, title: String, done: Bool) {
        this.id = id
        this.title = title
        this.done = done
    }
}

class TaskListModel {
    let tasks = State<Array<Task>>(
        [
            Task("task-a", "核对需求", false),
            Task("task-b", "修复焦点", true),
            Task("task-c", "发布版本", false)
        ]
    )
    let selectedId = State<String>("task-b")
    let openOnly = State<Bool>(false)

    func visibleTasks(): Array<Task> {
        let visible = ArrayList<Task>()
        for (task in tasks.value) {
            if (!openOnly.value || !task.done) {
                visible.add(task)
            }
        }
        visible.toArray()
    }

    func select(id: String): Unit {
        selectedId.value = id
    }

    func reverseOrder(): Unit {
        let current = tasks.value
        tasks.value = Array<Task>(current.size, {
            index => current[current.size - index - 1]
        })
    }

    func selectionIsVisible(): Bool {
        for (task in visibleTasks()) {
            if (task.id == selectedId.value) {
                return true
            }
        }
        false
    }

    func toggleOpenOnly(): Unit {
        openOnly.value = !openOnly.value
        if (!selectionIsVisible()) {
            let visible = visibleTasks()
            selectedId.value = if (visible.isEmpty()) {
                ""
            } else {
                visible[0].id
            }
        }
    }

    func selectedTitle(): String {
        for (task in tasks.value) {
            if (task.id == selectedId.value) {
                return task.title
            }
        }
        "未选择"
    }
}

func taskRow(model: TaskListModel, task: Task): Unit {
    let expanded = rememberState<Bool>("expanded") {false}
    VStack(spacing: 6.vp) {
        HStack(spacing: 8.vp) {
            Button(if (model.selectedId.value == task.id) {
                "已选"
            } else {
                "选择"
            }, {=> model.select(task.id)})
            Label(task.title).flex()
            Label(if (task.done) {
                "已完成"
            } else {
                "未完成"
            }).muted()
            Button(if (expanded.value) {
                "收起"
            } else {
                "展开"
            }, {=> expanded.value = !expanded.value})
        }
        if (expanded.value) {
            Label("业务 id：${task.id}").muted()
        }
    }
}

main(): Unit {
    let model = TaskListModel()
    let app = DesktopApp(WindowSpec("稳定身份列表", 620, 420))
    app.run {
        VStack(spacing: 12.vp) {
            Label("当前选择：${model.selectedTitle()}").bold()
            HStack(spacing: 8.vp) {
                Button("反转顺序", {=> model.reverseOrder()})
                Button(if (model.openOnly.value) {
                    "显示全部"
                } else {
                    "只看未完成"
                }, {=> model.toggleOpenOnly()})
            }
            let visible = model.visibleTasks()
            if (visible.isEmpty()) {
                Label("没有符合筛选条件的任务").muted()
            }
            ForEach(visible, key: {task => task.id}) {
                task => taskRow(model, task)
            }
        }.padding(20.vp)
    }
}
```

## 确认结果

执行 `cjpm run`。初始选择应为“修复焦点”。先展开这一行，再点击“反转顺序”：它移到新位置后仍保持“已选”和展开，详情继续显示 `task-b`。点击“只看未完成”后，该已完成任务被隐藏，选择明确改为当前第一条可见任务；再次反转时选择仍跟随同一业务 id。点击“显示全部”可重新看到被过滤任务，但它先前的行内展开状态已经因卸载而清理，这是当前模型刻意展示的边界。

## 接着试一试

若产品希望“过滤隐藏选中项后不自动选择别项”，让 `toggleOpenOnly` 在当前选择不可见时把 `selectedId.value` 设为空串，不再选择第一条可见任务。结果应显示“当前选择：未选择”，而不是误选另一行。

## 常见错误

- 使用数组索引作为 id，插入或重排后选择和编辑状态移动到另一行。
- 同时保存原数组和过滤数组，更新一边忘记另一边。
- 保存选中行号，排序后详情指向另一任务。
- 以为稳定 key 能让已过滤或滚出虚拟视口的局部状态永久存活；需要长期保留的状态应进入以业务 id 为键的模型。
- 在每次构建中追加默认数据，导致列表持续增长。
- 过滤隐藏选择后既不清空也不重选，详情仍显示不可见对象。

## 相关 API

- [`ForEach`](../../api/cui/core/functions.md#foreach) 与 [`Keyed`](../../api/cui/core/Keyed.md) — 稳定身份子树。
- [`LazyColumn`](../../api/cui/core/LazyColumn.md) — 固定高纵向虚拟列表。
- [`ListView`](../../api/cui/controls/ListView.md) — 带选择和键盘导航的列表。
- [`State`](../../api/cui/core/State.md) — 数据数组、筛选和选中 id。

## 下一步

数据到达千级时继续[虚拟化大列表](virtualize-large-data.md)。

需要多列、排序和详情时继续[构建表格主从界面](table-master-detail.md)。若项目状态在重排后跟错行，返回[状态与绑定](../concepts/state-and-binding.md)检查所有权和键。
