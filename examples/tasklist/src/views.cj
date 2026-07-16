/*
 * 任务清单视图层：抬头 + 可拖动重排的任务列表。
 *
 *  - `ReorderableList` 的每行左侧是拖动手柄，按住手柄上下拖动即改变任务顺序（顺序即优先级），松手提交。
 *  - 行内容是一个复选框（显示任务标题、切换完成态）：点手柄拖动、点手柄以外则命中复选框，二者互不干扰。
 *  - 完成态用 `project` 双向绑定到该任务的 done 字段；顺序由模型持有，列表只负责报告移动。
 */
package cui_tasklist

import cui.{Checkbox, CrossAxisAlignment, FontSizes, HStack, Label, LengthUnits, Panel, ReorderableList, Spacer,
    VStack}

func tasklistView(model: TaskModel): Unit {
    VStack {
        appHeader(model)
        Panel {
            ReorderableList.of(model.tasks.value, 48.0, {from, to => model.move(from, to)}, spacing: 8.0,
                key: {t => "task${t.id}"}) {
                task => taskRow(model, task)
            }
        }.contentPadding(8.vp).hug()
        Spacer()
    }.spacing(12.vp).padding(16.vp)
}

func appHeader(model: TaskModel): Unit {
    VStack {
        Label("任务优先级").fontSize(FontSizes.TITLE)
        Label("按住每行左侧手柄上下拖动即可重排优先级（越靠上越优先）；点标题勾选完成 · ${model.summary.value}")
            .muted().fontSize(FontSizes.CAPTION)
    }.spacing(2.vp).hug()
}

func taskRow(model: TaskModel, task: Task): Unit {
    Panel {
        HStack {
            Checkbox(task.title, model.doneBinding(task.id))
            Spacer()
        }.crossAxisAlignment(CrossAxisAlignment.Center).hug()
    }.contentPadding(8.vp)
}
