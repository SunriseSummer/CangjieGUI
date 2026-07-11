/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
/*
 * CUI example: a month calendar.
 *
 * What it demonstrates:
 *  - a real grid built from `Flexible` cells: the weekday header and the day cells
 *    share the same seven-column rhythm, so every row lines up exactly
 *  - state-driven navigation: the chevron buttons rewrite year/month State and the
 *    whole grid follows on the next frame
 *  - a live "today" highlight taken from the system clock (Time.currentDateTime)
 *  - generating a small image asset with Surface and showing it with ImageView
 */
package cui_calendar

import std.collection.ArrayList
import cui.Button
import cui.ButtonRole
import cui.Color
import cui.DateTimeParts
import cui.DesktopApp
import cui.Flexible
import cui.FontSizes
import cui.HStack
import cui.IconButton
import cui.IconName
import cui.ImageView
import cui.Insets
import cui.Label
import cui.Panel
import cui.Spacer
import cui.State
import cui.Surface
import cui.SurfaceStyle
import cui.TabView
import cui.TextAlign
import cui.Theme
import cui.Time
import cui.VStack
import cui.Weekday
import cui.Widget
import cui.WindowSpec
import cui.emit

let CALENDAR_BADGE = "cui-calendar-badge.bmp"
let CALENDAR_ACCENT = Color.rgb(126, 87, 194)
let MONTH_NAMES = ["一月", "二月", "三月", "四月", "五月", "六月", "七月", "八月", "九月", "十月", "十一月", "十二月"]

class CalendarModel {
    let today: DateTimeParts
    let year: State<Int64>
    let month: State<Int64>
    let selected: State<Int64>
    let tab = State<Int64>(0)

    init(today: DateTimeParts) {
        this.today = today
        this.year = State<Int64>(Int64(today.year))
        this.month = State<Int64>(Int64(today.month))
        this.selected = State<Int64>(Int64(today.day))
    }
}

main(): Int64 {
    writeCalendarBadge()
    let model = CalendarModel(Time.currentDateTime())
    let badge = ImageView(CALENDAR_BADGE, preferredWidth: Some(40.0), preferredHeight: 30.0)
    let app = DesktopApp(WindowSpec("CUI 日历", 780, 560, scale: 1.5), theme: calendarTheme())
    app.manage(badge)
    app.run {
        calendarView(model, badge)
    }
    return 0
}

// ----------------------- view -------------------------------

func calendarView(model: CalendarModel, badge: Widget): Unit {
    VStack(spacing: 12.0, padding: Insets(16.0)) {
        HStack(spacing: 10.0, flexible: false) {
            emit(badge)
            Label(monthTitle(model), fontSize: FontSizes.TITLE)
            Spacer()
            IconButton(IconName.ChevronLeft) {
                => shiftMonth(model, -1)
            }
            IconButton(IconName.ChevronRight) {
                => shiftMonth(model, 1)
            }
        }
        Panel(padding: Insets(14.0)) {
            TabView(["月历", "日程"], model.tab) {
                monthPage(model)
                agendaPage(model)
            }
        }
    }
}

func monthPage(model: CalendarModel): Unit {
    VStack(spacing: 8.0) {
        weekdayHeader()
        for (week in monthWeeks(model.year.value, model.month.value)) {
            weekRow(model, week)
        }
    }
}

func weekdayHeader(): Unit {
    let names = ["日", "一", "二", "三", "四", "五", "六"]
    HStack(spacing: 8.0, flexible: false) {
        for (name in names) {
            Flexible {
                Label(name, muted: true, align: TextAlign.Center, fontSize: FontSizes.CAPTION)
            }
        }
    }
}

func weekRow(model: CalendarModel, week: Array<Int64>): Unit {
    HStack(spacing: 8.0) {
        for (day in week) {
            dayCell(model, day)
        }
    }
}

// Each day is one flexible grid cell; an empty `Flexible {}` keeps the column rhythm
// where the month has no date, so the first and last weeks stay aligned.
func dayCell(model: CalendarModel, day: Int64): Unit {
    if (day == 0) {
        Flexible {}
    } else {
        Flexible {
            Button("${day}", {=> model.selected.value = day}, role: dayRole(model, day), style: dayStyle(model, day))
        }
    }
}

func agendaPage(model: CalendarModel): Unit {
    VStack(spacing: 10.0, padding: Insets(6.0)) {
        Label(selectedDateLine(model), muted: true)
        agendaItem("09:30", "项目规划评审")
        agendaItem("14:00", "设计方案走查")
        agendaItem("17:30", "整理个人笔记")
        Spacer()
    }
}

func agendaItem(time: String, title: String): Unit {
    Panel(padding: Insets(12.0), style: Some(agendaCardSurface()), flexible: false) {
        HStack(spacing: 14.0) {
            Label(time, color: Some(CALENDAR_ACCENT), fontSize: FontSizes.CAPTION)
            Label(title)
            Spacer()
        }
    }
}

// ---------------------------- styles ---------------------------

func calendarTheme(): Theme {
    Theme(
        Color.rgb(246, 241, 250),
        Color.rgb(255, 255, 255),
        Color.rgb(217, 205, 228),
        Color.rgb(36, 29, 44),
        Color.rgb(105, 93, 117),
        CALENDAR_ACCENT,
        Color.rgb(255, 255, 255),
        Color.rgb(198, 63, 91),
        Color.rgb(253, 251, 255),
        Color.rgb(241, 233, 255),
        panelRaised: Color.rgb(255, 255, 255),
        accentSoft: Color.rgb(235, 224, 255),
        shadow: Color.rgba(43, 24, 70, 26),
        radius: 18.0,
        controlRadius: 12.0
    )
}

func dayRole(model: CalendarModel, day: Int64): ButtonRole {
    if (day == model.selected.value) {
        ButtonRole.Primary
    } else {
        ButtonRole.Normal
    }
}

// The selected day uses the primary role; today keeps a soft accent ring so it stays
// visible while another day is selected.
func dayStyle(model: CalendarModel, day: Int64): ?SurfaceStyle {
    if (day != model.selected.value && isToday(model, day)) {
        Some(todaySurface())
    } else {
        None<SurfaceStyle>
    }
}

func todaySurface(): SurfaceStyle {
    SurfaceStyle(
        Color.rgb(241, 233, 255),
        border: CALENDAR_ACCENT,
        radius: 12.0,
        borderWidth: 1.5
    )
}

func agendaCardSurface(): SurfaceStyle {
    SurfaceStyle(Color.rgb(243, 237, 252), radius: 12.0)
}

// ----------------- month arithmetic ----------------------------

func isToday(model: CalendarModel, day: Int64): Bool {
    model.year.value == Int64(model.today.year) && model.month.value == Int64(model.today.month) && day == Int64(model
        .today
        .day)
}

func monthTitle(model: CalendarModel): String {
    "${model.year.value} 年 ${MONTH_NAMES[model.month.value - 1]}"
}

func selectedDateLine(model: CalendarModel): String {
    let weekday = Time.dayOfWeek(Int32(model.year.value), Int32(model.month.value), Int32(model.selected.value))
    "${model.year.value} 年 ${model.month.value} 月 ${model.selected.value} 日，${weekdayName(weekday)}"
}

func shiftMonth(model: CalendarModel, delta: Int64): Unit {
    var month = model.month.value + delta
    var year = model.year.value
    if (month < 1) {
        month = 12
        year -= 1
    } else if (month > 12) {
        month = 1
        year += 1
    }
    model.month.value = month
    model.year.value = year
    model.selected.value = min(model.selected.value, Int64(Time.daysInMonth(Int32(year), Int32(month))))
}

// The weeks of a month as rows of seven day numbers, 0 where the cell is outside the
// month. Only as many rows as the month actually needs.
func monthWeeks(year: Int64, month: Int64): Array<Array<Int64>> {
    let firstIndex = weekdayIndex(Time.dayOfWeek(Int32(year), Int32(month), 1))
    let days = Int64(Time.daysInMonth(Int32(year), Int32(month)))
    let rows = (firstIndex + days + 6) / 7
    let weeks = ArrayList<Array<Int64>>()
    for (row in 0..rows) {
        weeks.add(Array<Int64>(7, {col => dayForCell(firstIndex, days, row, col)}))
    }
    weeks.toArray()
}

func dayForCell(firstIndex: Int64, days: Int64, row: Int64, col: Int64): Int64 {
    let day = row * 7 + col - firstIndex + 1
    if (day >= 1 && day <= days) {
        day
    } else {
        0
    }
}

func weekdayIndex(day: Weekday): Int64 {
    match (day) {
        case Weekday.Sunday => 0
        case Weekday.Monday => 1
        case Weekday.Tuesday => 2
        case Weekday.Wednesday => 3
        case Weekday.Thursday => 4
        case Weekday.Friday => 5
        case Weekday.Saturday => 6
    }
}

func weekdayName(day: Weekday): String {
    match (day) {
        case Weekday.Sunday => "星期日"
        case Weekday.Monday => "星期一"
        case Weekday.Tuesday => "星期二"
        case Weekday.Wednesday => "星期三"
        case Weekday.Thursday => "星期四"
        case Weekday.Friday => "星期五"
        case Weekday.Saturday => "星期六"
    }
}

// ------------------------ badge asset ------------------------------------

struct PixelRect {
    let x: Int32
    let y: Int32
    let w: Int32
    let h: Int32

    init(x: Int32, y: Int32, w: Int32, h: Int32) {
        this.x = x
        this.y = y
        this.w = w
        this.h = h
    }
}

// Rendered at 2x the displayed size so the ImageView downsamples it to a crisp thumbnail.
func writeCalendarBadge(): Unit {
    try (surface = Surface.create(192, 144)) {
        surface.clear(Color.rgb(253, 251, 255))
        fillRect(surface, PixelRect(0, 0, 192, 44), CALENDAR_ACCENT)
        fillRect(surface, PixelRect(52, 8, 14, 12), Color.rgb(171, 143, 222))
        fillRect(surface, PixelRect(126, 8, 14, 12), Color.rgb(171, 143, 222))
        fillRect(surface, PixelRect(20, 74, 152, 3), Color.rgb(224, 215, 240))
        fillRect(surface, PixelRect(20, 106, 152, 3), Color.rgb(224, 215, 240))
        let cell = Color.rgb(236, 228, 250)
        drawBadgeCell(surface, 0, 0, cell)
        drawBadgeCell(surface, 1, 0, cell)
        drawBadgeCell(surface, 2, 0, CALENDAR_ACCENT)
        drawBadgeCell(surface, 0, 1, cell)
        drawBadgeCell(surface, 1, 1, cell)
        drawBadgeCell(surface, 2, 1, cell)
        surface.saveBmp(CALENDAR_BADGE)
    }
}

func drawBadgeCell(surface: Surface, col: Int32, row: Int32, color: Color): Unit {
    fillRect(surface, PixelRect(44 + col * 40, 54 + row * 32, 30, 24), color)
}

func fillRect(surface: Surface, rect: PixelRect, color: Color): Unit {
    var row: Int32 = 0
    while (row < rect.h) {
        var col: Int32 = 0
        while (col < rect.w) {
            surface.writePixel(rect.x + col, rect.y + row, color)
            col += 1
        }
        row += 1
    }
}
