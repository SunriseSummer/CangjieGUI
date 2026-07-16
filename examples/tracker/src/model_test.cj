package cui_tracker

@Test
func withUpdatedBoolReplacesOne(): Unit {
    let base = [true, true, true, true]
    let next = withUpdatedBool(base, 2, false)
    @Expect(next[2], false)
    @Expect(next[0], true)
    @Expect(base[2], true) // 原数组不受影响
}

@Test
func filterIssuesKeepsEnabledStatuses(): Unit {
    let issues = [Issue("a", 0, 0), Issue("b", 1, 0), Issue("c", 2, 0), Issue("d", 0, 1)]
    // 仅启用状态 0 → a 与 d。
    let onlyTodo = filterIssues(issues, [true, false, false, false])
    @Expect(onlyTodo.size, 2)
    @Expect(onlyTodo[0].title, "a")
    @Expect(onlyTodo[1].title, "d")
    // 全部关闭 → 无结果。
    @Expect(filterIssues(issues, [false, false, false, false]).size, 0)
    // 全部开启 → 全部保留。
    @Expect(filterIssues(issues, [true, true, true, true]).size, 4)
}

@Test
func labelsFormatSafely(): Unit {
    @Expect(statusName(1), "进行中")
    @Expect(statusName(99), "待办") // 越界时回退默认值
    @Expect(priorityLabel(0), "高优先级")
    @Expect(priorityLabel(2), "低优先级")
}

@Test
func modelFilterLensTogglesVisibility(): Unit {
    let model = TrackerModel()
    let all = model.visible().size
    @Expect(all, model.total()) // 初始所有状态均显示
    // 通过对应 lens 关闭待办（状态 0）。
    let lens = model.filterLens(0)
    lens.value = false
    @Expect(model.visible().size < all)
    // 可见列表中不再有待办 issue。
    for (issue in model.visible()) {
        @Expect(issue.status != 0)
    }
    // 重新开启 → 恢复完整列表。
    lens.value = true
    @Expect(model.visible().size, all)
}
