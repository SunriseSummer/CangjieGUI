package cui_timeline

import cui.CalendarDate

private let ANCHOR = CalendarDate(2026, 7, 16)

@Test
func todayIsSelectedAndCentredByDefault(): Unit {
    let model = TimelineModel(ANCHOR)
    @Expect(model.selected.value, model.todayIndex())
    @Expect(model.selectedDate(), ANCHOR)
    @Expect(model.selectedDelta(), 0)
}

@Test
func stripStartsBeforeTodayAndSpansTheRange(): Unit {
    let model = TimelineModel(ANCHOR)
    // 日期带起点比今天早 TIMELINE_LEAD 天，故下标 0 为锚点前 30 天。
    @Expect(model.dateAt(0), ANCHOR.addingDays(-30))
    @Expect(model.dateAt(model.todayIndex()), ANCHOR)
    @Expect(model.count, 400)
}

@Test
func selectionDrivesDateAndDelta(): Unit {
    let model = TimelineModel(ANCHOR)
    model.selected.value = model.todayIndex() + 5 // 今天之后五天
    @Expect(model.selectedDate(), ANCHOR.addingDays(5))
    @Expect(model.selectedDelta(), 5)

    model.selected.value = model.todayIndex() - 10 // 今天之前十天
    @Expect(model.selectedDelta(), -10)
}

@Test
func backToTodayResetsSelectionAndScroll(): Unit {
    let model = TimelineModel(ANCHOR)
    model.selected.value = 200
    model.scroll.value = 9999.0
    model.backToToday()
    @Expect(model.selected.value, model.todayIndex())
    @Expect(model.selectedDate(), ANCHOR)
    // 滚动量回到今天的初始位置（非负，今天前留出约两格）。
    @Expect(model.scroll.value < 9999.0)
    @Expect(model.scroll.value > 0.0)
}

@Test
func dateAtClampsOutOfRangeIndices(): Unit {
    let model = TimelineModel(ANCHOR)
    // 越界下标截断到两端，而不会算出日期带之外的日期。
    @Expect(model.dateAt(-5), model.dateAt(0))
    @Expect(model.dateAt(10_000), model.dateAt(model.count - 1))
}

@Test
func weekdayNamesMatchCalendarDate(): Unit {
    // 2026-07-16 是星期四（weekdayIndex 为 4）。
    @Expect(weekdayShort(CalendarDate(2026, 7, 16)), "四")
    @Expect(weekdayFull(CalendarDate(2026, 7, 16)), "周四")
}

@Test
func relativeLabelReadsNaturally(): Unit {
    @Expect(relativeLabel(0), "今天")
    @Expect(relativeLabel(3), "3 天后")
    @Expect(relativeLabel(-2), "2 天前")
}
