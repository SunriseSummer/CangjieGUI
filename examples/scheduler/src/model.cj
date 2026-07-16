/*
 * 排期状态：表单字段（主题/日期/开始/结束）与已排会议列表。
 *
 * 时长由开始/结束时间现算，`canAdd` 据此与主题非空决定“添加”是否可用；添加后按 (日期, 开始) 排序。
 */
package cui_scheduler

import cui.{CalendarDate, State, TimeOfDay}

class SchedulerModel {
    let title = State<String>("团队周会")
    let date = State<CalendarDate>(CalendarDate(2026, 7, 16))
    let start = State<TimeOfDay>(TimeOfDay(10, 0))
    let end = State<TimeOfDay>(TimeOfDay(11, 0))
    let meetings: State<Array<Meeting>>

    init() {
        this.meetings = State<Array<Meeting>>(withMeeting([
            Meeting("产品评审", CalendarDate(2026, 7, 16), TimeOfDay(14, 0), TimeOfDay(15, 30))
        ], Meeting("入职一对一", CalendarDate(2026, 7, 17), TimeOfDay(9, 30), TimeOfDay(10, 0))))
    }

    // 当前表单的时长（分钟），供时长提示与可用性判断复用。
    func durationMinutes(): Int64 {
        meetingDurationMinutes(start.value, end.value)
    }

    // 结束晚于开始、且主题非空才可添加。
    func canAdd(): Bool {
        durationMinutes() > 0 && !title.value.trimAscii().isEmpty()
    }

    func addMeeting(): Unit {
        if (canAdd()) {
            meetings.value = withMeeting(meetings.value,
                Meeting(title.value.trimAscii(), date.value, start.value, end.value))
        }
    }
}
