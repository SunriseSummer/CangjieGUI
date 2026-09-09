<!-- kind: tutorial; audience: desktop-app-developer; prerequisites: settings-form, app-architecture -->

# 从表单走到任务工作台

## 你将完成

你会得到一个真正可操作的双区任务工作台：左侧按业务 id 选择任务，右侧编辑说明；筛选会自动修正已经不可见的选择，保存动作只修改模型。完整练习约需 35 分钟。

## 开始之前

先完成[设置表单](settings-form.md)，并读过[应用结构](../concepts/app-architecture.md)。沿用首窗口教程的 `cjpm.toml`、CUI 路径依赖和 SDL 运行库。你需要会创建 `State`、用 `VStack`/`HStack` 排列控件，并能在普通运行方式下关闭窗口。

## 先建立一个模型

小示例可以把所有代码写在 `main.cj`，真实项目仍应拆成三层：`model.cj` 保存事实并提供动作，`views.cj` 只读模型、发出动作，`main.cj` 负责创建模型和启动窗口。先运行单文件版本确认行为，再按后文边界拆分；这样出错时能判断是 API 用法还是文件组织问题。

## 操作步骤

### 第一步：让选择保存业务 id

不要保存“第 2 行”。筛选、排序之后行号会变化，`task-b` 这样的业务 id 不会。模型还要负责保证选择有效：当前任务被筛掉时，明确改选第一条可见任务，或者改为空选择。

### 第二步：让编辑绑定回模型

右侧编辑区需要一份稳定的 `State<String>`。示例为每个任务保存自己的说明状态；切换任务后，编辑内容仍属于原任务。`ForEach` 的 `key` 同样使用任务 id，使左侧行内状态跟着任务，而不是跟着屏幕位置。

### 第三步：运行完整工作台

把下面内容保存到空 Cangjie 项目的 `src/main.cj`。依赖配置与运行库准备见[第一个窗口](../getting-started/first-window.md)。先不要拆文件；保持一个已知可运行基线，下一步的结构调整才有对照。

## 完整程序

```cangjie verify role=complete profile=gui-visual
package docexample

import std.collection.ArrayList
import cui.*

class WorkItem {
    let id: String
    let title: String
    let note: State<String>
    let done: Bool

    init(id: String, title: String, note: String, done: Bool) {
        this.id = id
        this.title = title
        this.note = State<String>(note)
        this.done = done
    }
}

interface SaveService {
    func save(item: WorkItem): Bool
}

// 示例服务用空备注模拟失败；真实应用可在这里接文件或远端服务。
class NonEmptySaveService <: SaveService {
    public func save(item: WorkItem): Bool {
        !item.note.value.isEmpty()
    }
}

class WorkbenchModel {
    private let saveService: SaveService
    let items = State<Array<WorkItem>>(
        [
            WorkItem("task-a", "核对需求", "确认验收条件", false),
            WorkItem("task-b", "修复焦点", "Modal 打开时禁止背景动作", false),
            WorkItem("task-c", "发布版本", "打包运行库", true)
        ]
    )
    let selectedId = State<String>("task-a")
    let openOnly = State<Bool>(false)
    let savedCount = State<Int64>(0)
    let saveStatus = State<String>("尚未保存")

    init(saveService: SaveService) {
        this.saveService = saveService
    }

    func visible(): Array<WorkItem> {
        let result = ArrayList<WorkItem>()
        for (item in items.value) {
            if (!openOnly.value || !item.done) {
                result.add(item)
            }
        }
        result.toArray()
    }

    func selected(): ?WorkItem {
        for (item in items.value) {
            if (item.id == selectedId.value) {
                return Some(item)
            }
        }
        None
    }

    func toggleFilter(): Unit {
        openOnly.value = !openOnly.value
        let shown = visible()
        var found = false
        for (item in shown) {
            if (item.id == selectedId.value) {
                found = true
            }
        }
        if (!found) {
            selectedId.value = if (shown.isEmpty()) {
                ""
            } else {
                shown[0].id
            }
        }
    }

    func save(): Unit {
        match (selected()) {
            case Some(item) =>
                if (saveService.save(item)) {
                    savedCount.value = savedCount.value + 1
                    saveStatus.value = "保存成功：${item.title}"
                } else {
                    saveStatus.value = "保存失败：备注不能为空"
                }
            case None => saveStatus.value = "保存失败：没有选中的任务"
        }
    }
}

func workbench(model: WorkbenchModel): Unit {
    HStack(spacing: 16.vp) {
        VStack(spacing: 8.vp) {
            Label("任务").bold()
            Button(if (model.openOnly.value) {
                "显示全部"
            } else {
                "只看未完成"
            }, {=> model.toggleFilter()})
            ForEach(model.visible(), key: {item => item.id}) {
                item => Button(if (model.selectedId.value == item.id) {
                    "已选：${item.title}"
                } else {
                    item.title
                }, {=> model.selectedId.value = item.id})
            }
        }.width(190.vp)
        VStack(spacing: 10.vp) {
            workbenchDetail(model)
        }.flex()
    }.padding(20.vp)
}

func workbenchDetail(model: WorkbenchModel): Unit {
    match (model.selected()) {
        case Some(item) =>
            Label(item.title).bold()
            TextArea(item.note).flex()
            HStack(spacing: 8.vp) {
                Button("保存", {=> model.save()}, role: ButtonRole.Primary)
                Label("已保存 ${model.savedCount.value} 次").muted()
            }.height(40.vp)
            Label(model.saveStatus.value).muted()
            ()
        case None =>
            Label("没有可编辑的任务").muted()
            ()
    }
}

main(): Unit {
    let model = WorkbenchModel(NonEmptySaveService())
    model.save()
    if (!model.saveStatus.value.startsWith("保存成功")) {
        throw IllegalStateException("正常备注应由保存服务接受")
    }
    match (model.selected()) {
        case Some(item) =>
            let original = item.note.value
            item.note.value = ""
            model.save()
            if (!model.saveStatus.value.startsWith("保存失败")) {
                throw IllegalStateException("空备注应显示服务失败状态")
            }
            item.note.value = original
            model.saveStatus.value = "已验证成功和失败两条保存路径"
        case None => throw IllegalStateException("启动时应有选中的任务")
    }
    let app = DesktopApp(WindowSpec("任务工作台", 760, 480))
    app.run {workbench(model)}
}
```

## 可以继续修改

### 拆成多文件工程

保持本页包名不变，将 `WorkItem` 与业务模型移入 `model.cj`，将 `workbench` 等视图函数移入 `views.cj`，`main.cj` 只创建模型和 DesktopApp。拆分不会改变可见行为，随后重新执行筛选、选择与编辑验收。

仓库 [workbench 示例](../../../examples/workbench/README.md) 是另一套文档工作台：`data.cj` 定义 `Doc`、`Heading` 与大纲函数，`model.cj` 保存文档绑定和分栏比例，`views.cj` 组合导航、编辑器与大纲。它可作为嵌套分栏的延伸阅读，不是本页任务筛选程序的源码副本。

## 确认结果

启动后当前任务按钮应以“已选：核对需求”显示，不依赖特殊符号字形。再选择“修复焦点”，在右侧改写说明，切到别的任务并返回，文字应保留。点击“只看未完成”，已完成任务消失；如果它原本被选中，选择会改到第一条可见任务。保存计数增加，但不会改变选择或说明。最后将代码拆为三个文件并再次运行，行为应完全一致。

除了点选路径，再验证模型边界：先选择已完成任务再打开筛选，确认选择自动修正；把所有任务暂时改成已完成并只看未完成，确认详情显示空状态而不是访问 `-1`。这些结果都能在模型测试中复现，界面只是把同一事实显示出来。

## 如果没有成功

- 选择保存数组下标：筛选后详情会指向另一任务。
- 在界面构建函数里创建模型：每次重建都会丢失编辑内容。
- 让文件读写直接修改界面状态：失败路径难以测试；应由动作层把结果送回模型。
- 把业务内容只放在 `rememberState`：控件卸载时可能被清理；需要跨页面存活的事实应由模型持有。

构建失败时先回退到单文件完整程序；单文件正常而拆分后失败，通常是包名、可见性或导入不一致。切换任务后说明丢失，检查是否在构建函数中重新创建 `WorkbenchModel` 或 `note`。筛选后详情错位，检查选择是否保存了数组下标。

## 相关 API

[State](../../api/cui/core/State.md) 保存事实，[DerivedState](../../api/cui/core/DerivedState.md) 可表达只读统计，[TextArea](../../api/cui/text/TextArea.md) 编辑说明，[ForEach](../../api/cui/core/functions.md) 按 id 维护行身份。需要可拖动双栏时，可把当前 `HStack` 迁移到 [SplitView](../../api/cui/controls/SplitView.md)。

## 下一步

先读[尺寸单位与修饰器顺序](../concepts/modifiers-and-units.md)统一工作台间距。数据量上升后接着做[虚拟化大列表](../how-to/virtualize-large-data.md)；需要打开、保存文件时继续看[桌面文件与后台任务](../how-to/desktop-files-and-background.md)。
