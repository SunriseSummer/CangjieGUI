/*
 * 活动流状态：全部活动与当前筛选的动作类型。
 *
 * 筛选用分段控件选择（全部/新建/保存/复制/删除/打开），`filtered()` 按选择过滤，视图据此渲染。
 * 单一数据源、派生视图，无冗余副本。
 */
package cui_activity

import std.collection.ArrayList
import cui.State

// 分段下标 → 动作；下标 0 为“全部”。
let FILTER_LABELS: Array<String> = ["全部", "新建", "保存", "复制", "删除", "打开"]
private let FILTER_ACTIONS: Array<Action> = [Action.Created, Action.Saved, Action.Copied, Action.Deleted,
    Action.Opened]

class ActivityModel {
    let activities: Array<Activity>
    let filter = State<Int64>(0) // 0 = 全部

    init() {
        this.activities = seedActivities()
    }

    /** 当前筛选下的活动：下标 0 返回全部，否则按对应动作过滤。 */
    func filtered(): Array<Activity> {
        if (filter.value <= 0 || filter.value > FILTER_ACTIONS.size) {
            return activities
        }
        let wanted = FILTER_ACTIONS[filter.value - 1]
        let result = ArrayList<Activity>()
        for (activity in activities) {
            if (sameAction(activity.action, wanted)) {
                result.add(activity)
            }
        }
        result.toArray()
    }
}

/** 动作相等判断（枚举无内建 ==，按名称比较即可）。 */
func sameAction(a: Action, b: Action): Bool {
    actionName(a) == actionName(b)
}
