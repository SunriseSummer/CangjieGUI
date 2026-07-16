/*
 * 任务数据与纯函数辅助：不可变任务、整表替换更新、按 id 取/改完成态，以及通用的重排 `moveItem`。
 */
package cui_tasklist

import std.collection.ArrayList

struct Task {
    let id: Int64
    let title: String
    let done: Bool

    init(id: Int64, title: String, done: Bool) {
        this.id = id
        this.title = title
        this.done = done
    }
}

func seedTasks(): Array<Task> {
    [
        Task(1, "梳理下个迭代的组件清单", false),
        Task(2, "补齐拖放列表的单元测试", false),
        Task(3, "回顾昨天的性能基准", true),
        Task(4, "更新组件文档与示例索引", false),
        Task(5, "对齐无障碍树的接入方案", false),
        Task(6, "整理个人周报", true),
        Task(7, "预研时间选择器组件", false),
        Task(8, "回复代码评审意见", false)
    ]
}

/** 把 `from` 处的元素移动到 `to` 处，返回新数组（不改原数组）。 */
func moveItem<T>(items: Array<T>, from: Int64, to: Int64): Array<T> {
    let without = ArrayList<T>()
    for (i in 0..items.size) {
        if (i != from) {
            without.add(items[i])
        }
    }
    let result = ArrayList<T>()
    for (i in 0..without.size) {
        if (i == to) {
            result.add(items[from])
        }
        result.add(without[i])
    }
    if (to >= without.size) {
        result.add(items[from])
    }
    result.toArray()
}

/** 按 id 取任务完成态（找不到记未完成）。 */
func taskDone(tasks: Array<Task>, id: Int64): Bool {
    for (task in tasks) {
        if (task.id == id) {
            return task.done
        }
    }
    false
}

/** 返回把某任务完成态改为 `done` 后的新任务表。 */
func withTaskDone(tasks: Array<Task>, id: Int64, done: Bool): Array<Task> {
    Array<Task>(tasks.size, {i => if (tasks[i].id == id) {
        Task(tasks[i].id, tasks[i].title, done)
    } else {
        tasks[i]
    }})
}

/** 已完成的任务数。 */
func doneCount(tasks: Array<Task>): Int64 {
    var count: Int64 = 0
    for (task in tasks) {
        if (task.done) {
            count += 1
        }
    }
    count
}
