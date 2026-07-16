/*
 * 追踪器状态：问题列表 + 一份按状态下标对应的过滤开关。
 *
 * 每个状态的过滤开关是开关数组在该下标上的镜头（`project`），`Chip` 双向读写它；可见问题是问题列表与
 * 开关数组的纯函数，每帧现算。
 */
package cui_tracker

import cui.{Binding, State}

class TrackerModel {
    let issues: Array<Issue> = seedIssues()
    let statusFilters: State<Array<Bool>>

    init() {
        // 初始四个状态全部显示。
        this.statusFilters = State<Array<Bool>>([true, true, true, true])
    }

    // 第 status 个状态过滤开关的双向镜头，供该状态的 `Chip` 绑定。
    func filterLens(status: Int64): Binding<Bool> {
        statusFilters.project(get: {arr => arr[status]}, set: {arr, v => withUpdatedBool(arr, status, v)})
    }

    // 当前开关下可见的问题。
    func visible(): Array<Issue> {
        filterIssues(issues, statusFilters.value)
    }

    func total(): Int64 {
        issues.size
    }
}
