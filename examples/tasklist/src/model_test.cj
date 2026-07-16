package cui_tasklist

@Test
func moveReordersTasks(): Unit {
    let model = TaskModel()
    let firstId = model.tasks.value[0].id
    // 将首个任务移动到位置 3。
    model.move(0, 3)
    @Expect(model.tasks.value[3].id, firstId)
    @Expect(model.tasks.value.size, 8) // 无任务丢失
}

@Test
func moveItemHelperIsCorrectInBothDirections(): Unit {
    let arr = [10, 20, 30, 40]
    @Expect(moveItem(arr, 0, 3), [20, 30, 40, 10]) // 下移到末尾
    @Expect(moveItem(arr, 3, 0), [40, 10, 20, 30]) // 上移到最前
    @Expect(moveItem(arr, 1, 2), [10, 30, 20, 40]) // 下移一位
}

@Test
func doneBindingReadsAndWritesTheRightTask(): Unit {
    let model = TaskModel()
    let id = model.tasks.value[1].id
    let binding = model.doneBinding(id)
    let before = binding.value
    binding.value = !before
    @Expect(taskDone(model.tasks.value, id), !before)
    // 其他任务不受影响。
    @Expect(taskDone(model.tasks.value, model.tasks.value[0].id), taskDone(seedTasks(), model.tasks.value[0].id))
}

@Test
func doneBindingSurvivesReorder(): Unit {
    let model = TaskModel()
    let id = model.tasks.value[2].id
    model.doneBinding(id).value = false // 第三个任务初始为已完成，将其取消
    model.move(2, 0) // 重新排序
    // 绑定以 id 为键，完成状态跟随任务本身而非其所在位置。
    @Expect(taskDone(model.tasks.value, id), false)
}

@Test
func summaryCountsDoneTasks(): Unit {
    let model = TaskModel()
    let initialDone = doneCount(seedTasks())
    @Expect(model.summary.value.contains("已完成 ${initialDone}"))
    model.doneBinding(model.tasks.value[0].id).value = true
    @Expect(model.summary.value.contains("已完成 ${initialDone + 1}"))
}
