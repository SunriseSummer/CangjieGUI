/*
 * 问题追踪示例的类型化数据与纯过滤逻辑。
 *
 * 状态过滤（按状态开关保留问题）与状态位更新都是纯函数，便于单测且与视图无关。
 */
package cui_tracker

import std.collection.ArrayList

// 状态名（下标即 Issue.status），过滤开关也按此下标对应。
let STATUS_NAMES: Array<String> = ["待办", "进行中", "已完成", "已关闭"]

// 优先级名（下标即 Issue.priority）。
let PRIORITY_NAMES: Array<String> = ["高", "中", "低"]

// 一条问题记录。
struct Issue {
    let title: String
    let status: Int64
    let priority: Int64

    init(title: String, status: Int64, priority: Int64) {
        this.title = title
        this.status = status
        this.priority = priority
    }
}

func seedIssues(): Array<Issue> {
    [
        Issue("登录页在窄屏下溢出", 1, 0),
        Issue("导出 CSV 缺少表头", 0, 1),
        Issue("暗色主题对比度偏低", 0, 2),
        Issue("空列表翻页时崩溃", 2, 0),
        Issue("补充键盘导航文档", 3, 2),
        Issue("表格排序结果不稳定", 1, 1),
        Issue("首屏加载偏慢", 0, 0),
        Issue("设置页存在拼写错误", 2, 2),
        Issue("Toast 偶发不消失", 1, 0),
        Issue("国际化：本地化日期格式", 0, 1),
        Issue("移除废弃的接口", 3, 1),
        Issue("优化图片缓存策略", 2, 1)
    ]
}

// 状态名（越界回退到首项）。
func statusName(status: Int64): String {
    if (status >= 0 && status < STATUS_NAMES.size) {
        STATUS_NAMES[status]
    } else {
        STATUS_NAMES[0]
    }
}

// 优先级文案，如 “高优先级”。
func priorityLabel(priority: Int64): String {
    let name = if (priority >= 0 && priority < PRIORITY_NAMES.size) {
        PRIORITY_NAMES[priority]
    } else {
        PRIORITY_NAMES[0]
    }
    "${name}优先级"
}

// 返回把下标 index 处开关替换为 value 的新数组。
func withUpdatedBool(arr: Array<Bool>, index: Int64, value: Bool): Array<Bool> {
    let out = ArrayList<Bool>()
    for (i in 0..arr.size) {
        if (i == index) {
            out.add(value)
        } else {
            out.add(arr[i])
        }
    }
    out.toArray()
}

// 仅保留状态开关为真的问题。
func filterIssues(issues: Array<Issue>, filters: Array<Bool>): Array<Issue> {
    let out = ArrayList<Issue>()
    for (issue in issues) {
        if (issue.status >= 0 && issue.status < filters.size && filters[issue.status]) {
            out.add(issue)
        }
    }
    out.toArray()
}
