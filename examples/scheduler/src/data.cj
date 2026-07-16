/*
 * 会议排期示例的类型化数据与纯逻辑（时长计算、排序、文案）。
 *
 * 时长、排序键、时间段文案都是 `TimeOfDay`/`CalendarDate` 的纯函数，便于单测且与视图无关。
 */
package cui_scheduler

import std.collection.ArrayList
import cui.{CalendarDate, TimeOfDay}

// 一场排定的会议。
struct Meeting {
    let title: String
    let date: CalendarDate
    let start: TimeOfDay
    let end: TimeOfDay

    init(title: String, date: CalendarDate, start: TimeOfDay, end: TimeOfDay) {
        this.title = title
        this.date = date
        this.start = start
        this.end = end
    }
}

// 会议时长（分钟）；结束不晚于开始时记 0（视为无效，同日不跨午夜）。
func meetingDurationMinutes(start: TimeOfDay, end: TimeOfDay): Int64 {
    let span = end.totalMinutes() - start.totalMinutes()
    if (span > 0) {
        span
    } else {
        0
    }
}

// 时长文案，如 "1 小时 30 分钟"；无效时长为 "—"。
func formatDuration(minutes: Int64): String {
    if (minutes <= 0) {
        return "—"
    }
    let h = minutes / 60
    let m = minutes % 60
    if (h > 0 && m > 0) {
        "${h} 小时 ${m} 分钟"
    } else if (h > 0) {
        "${h} 小时"
    } else {
        "${m} 分钟"
    }
}

// 会议时间段文案，如 "10:00–11:00"。
func meetingTimeRange(m: Meeting): String {
    "${m.start.format()}–${m.end.format()}"
}

// 排序键：先按日期、再按开始时间升序。
func meetingLess(a: Meeting, b: Meeting): Bool {
    let byDate = a.date.compareTo(b.date)
    if (byDate != 0) {
        return byDate < 0
    }
    a.start.compareTo(b.start) < 0
}

// 追加一场会议并按 (日期, 开始时间) 升序返回新数组（选择排序，列表短小）。
func withMeeting(items: Array<Meeting>, added: Meeting): Array<Meeting> {
    let remaining = ArrayList<Meeting>()
    for (m in items) {
        remaining.add(m)
    }
    remaining.add(added)
    let result = ArrayList<Meeting>()
    while (remaining.size > 0) {
        var minIdx = 0
        var j = 1
        while (j < remaining.size) {
            if (meetingLess(remaining[j], remaining[minIdx])) {
                minIdx = j
            }
            j += 1
        }
        result.add(remaining[minIdx])
        remaining.remove(at: minIdx)
    }
    result.toArray()
}
