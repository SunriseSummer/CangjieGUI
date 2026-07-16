package cui_activity

@Test
func seedProducesVariedActivities(): Unit {
    let model = ActivityModel()
    @Expect(model.activities.size, 60)
    // 种子轮转全部五种动作，每种至少出现一次。
    var created = false
    var deleted = false
    for (a in model.activities) {
        if (sameAction(a.action, Action.Created)) {
            created = true
        }
        if (sameAction(a.action, Action.Deleted)) {
            deleted = true
        }
    }
    @Expect(created)
    @Expect(deleted)
}

@Test
func seedDecorrelatesActorFromAction(): Unit {
    let model = ActivityModel()
    // 相移让配对逐轮变化：同一操作者应出现不止一种动作（旧实现下 林小满 只会“新建”）。
    var creates = false
    var others = false
    for (a in model.activities) {
        if (a.actor == "林小满") {
            if (sameAction(a.action, Action.Created)) {
                creates = true
            } else {
                others = true
            }
        }
    }
    @Expect(creates)
    @Expect(others)
}

@Test
func filterAllReturnsEverything(): Unit {
    let model = ActivityModel()
    model.filter.value = 0
    @Expect(model.filtered().size, model.activities.size)
}

@Test
func filterByActionKeepsOnlyThatAction(): Unit {
    let model = ActivityModel()
    model.filter.value = 4 // 删除
    let filtered = model.filtered()
    @Expect(filtered.size > 0)
    for (a in filtered) {
        @Expect(sameAction(a.action, Action.Deleted))
    }
}

@Test
func actionMetadataIsConsistent(): Unit {
    @Expect(actionVerb(Action.Created), "新建了")
    @Expect(actionName(Action.Deleted), "删除")
    // 不同动作对应不同动词。
    @Expect(actionVerb(Action.Saved) != actionVerb(Action.Opened))
}

@Test
func filterOutOfRangeFallsBackToAll(): Unit {
    let model = ActivityModel()
    model.filter.value = 99 // 超出动作列表范围
    @Expect(model.filtered().size, model.activities.size)
}
