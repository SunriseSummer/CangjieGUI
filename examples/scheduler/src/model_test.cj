package cui_scheduler

import cui.{CalendarDate, TimeOfDay}

@Test
func durationBetweenTimes(): Unit {
    @Expect(meetingDurationMinutes(TimeOfDay(10, 0), TimeOfDay(11, 30)), 90)
    @Expect(meetingDurationMinutes(TimeOfDay(9, 15), TimeOfDay(9, 45)), 30)
    @Expect(meetingDurationMinutes(TimeOfDay(11, 0), TimeOfDay(10, 0)), 0) // 结束早于开始
    @Expect(meetingDurationMinutes(TimeOfDay(10, 0), TimeOfDay(10, 0)), 0) // 零时长
}

@Test
func durationFormatting(): Unit {
    @Expect(formatDuration(90), "1 小时 30 分钟")
    @Expect(formatDuration(120), "2 小时")
    @Expect(formatDuration(45), "45 分钟")
    @Expect(formatDuration(0), "—")
}

@Test
func timeRangeText(): Unit {
    @Expect(meetingTimeRange(Meeting("x", CalendarDate(2026, 7, 16), TimeOfDay(9, 5), TimeOfDay(10, 0))), "09:05–10:00")
}

@Test
func meetingsSortByDateThenStart(): Unit {
    let seed = withMeeting([
        Meeting("B", CalendarDate(2026, 7, 17), TimeOfDay(9, 0), TimeOfDay(10, 0))
    ], Meeting("A", CalendarDate(2026, 7, 16), TimeOfDay(15, 0), TimeOfDay(16, 0)))
    // 日期较早者排在前面，与插入顺序无关。
    @Expect(seed[0].title, "A")
    @Expect(seed[1].title, "B")
    // 同日且开始更早的会议插入到已有会议之前。
    let withEarly = withMeeting(seed, Meeting("A0", CalendarDate(2026, 7, 16), TimeOfDay(8, 0), TimeOfDay(9, 0)))
    @Expect(withEarly[0].title, "A0")
    @Expect(withEarly.size, 3)
}

@Test
func addGatedByValidity(): Unit {
    let model = SchedulerModel()
    let before = model.meetings.value.size
    // 无效：结束早于开始 → 不添加。
    model.start.value = TimeOfDay(11, 0)
    model.end.value = TimeOfDay(10, 0)
    @Expect(!model.canAdd())
    model.addMeeting()
    @Expect(model.meetings.value.size, before)
    // 恢复有效 → 添加成功。
    model.end.value = TimeOfDay(12, 0)
    @Expect(model.canAdd())
    model.addMeeting()
    @Expect(model.meetings.value.size, before + 1)
}
