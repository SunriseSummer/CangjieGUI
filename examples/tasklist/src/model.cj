/*
 * 任务优先级状态：一份有序任务表，顺序即优先级（越靠上越优先）。
 *
 * 拖动重排通过 `move(from, to)` 整表替换触发更新；每行的完成勾选用 `tasks.project` 双向绑定到该任务的
 * done 字段，单一数据源、无副本。`ReorderableList` 只负责报告移动，数据仍由模型持有。
 */
package cui_tasklist

import cui.{Binding, DerivedState, State}

class TaskModel {
    let tasks: State<Array<Task>>
    let summary: DerivedState<String>

    init() {
        this.tasks = State<Array<Task>>(seedTasks())
        this.summary = this.tasks.map({arr => "${arr.size} 项 · 已完成 ${doneCount(arr)}"})
    }

    /** 把第 `from` 项移到第 `to` 位，顺序即优先级。 */
    func move(from: Int64, to: Int64): Unit {
        tasks.value = moveItem(tasks.value, from, to)
    }

    /** 某任务完成态的双向绑定，供该行的复选框使用。 */
    func doneBinding(id: Int64): Binding<Bool> {
        tasks.project(get: {arr => taskDone(arr, id)}, set: {arr, value => withTaskDone(arr, id, value)})
    }
}
