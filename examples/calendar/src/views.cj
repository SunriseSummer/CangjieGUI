/*
 * 日历视图层：只描述界面结构，业务规则全部委托给 CalendarModel。
 *
 *  - 星期表头与日格共享同一套七列 Flexible 节奏，各行严格对齐
 *  - 左右箭头依赖框架为无 label 的 IconButton 自动分配的构建期唯一标识，
 *    两枚箭头互不吞事件
 *  - 尺寸一律使用 vp/fp 单位表达
 */
package cui_calendar

import cui.{Button, ButtonRole, FontSizes, ForEachIndexed, HStack, IconButton, IconName, ImageView, Label,
    LengthUnits, Panel, Spacer, TabView, TextAlign, VStack}

func calendarView(model: CalendarModel): Unit {
    VStack {
        HStack {
            // 逐帧内联声明即可：解码后的纹理按路径缓存在共享缓存里，重建不触碰磁盘。
            ImageView(CALENDAR_BADGE).width(40.vp).height(30.vp)
            Label(model.title.value).fontSize(FontSizes.TITLE)
            Spacer()
            IconButton(IconName.ChevronLeft) {
                => model.shiftMonth(-1)
            }
            IconButton(IconName.ChevronRight) {
                => model.shiftMonth(1)
            }
        }.spacing(10.vp).hug()
        Panel {
            TabView(["月历", "日程"], model.tab) {
                monthPage(model)
                agendaPage(model)
            }
        }.contentPadding(14.vp)
    }.spacing(12.vp).padding(16.vp)
}

func monthPage(model: CalendarModel): Unit {
    VStack {
        weekdayHeader()
        ForEachIndexed(monthWeeks(model.year.value, model.month.value)) {
            _, week => weekRow(model, week)
        }
    }.spacing(8.vp)
}

func weekdayHeader(): Unit {
    let names = ["日", "一", "二", "三", "四", "五", "六"]
    HStack {
        for (name in names) {
            Label(name).muted().textAlign(TextAlign.Center).fontSize(FontSizes.CAPTION).flex()
        }
    }.spacing(8.vp).hug()
}

func weekRow(model: CalendarModel, week: Array<Int64>): Unit {
    HStack {
        for (day in week) {
            dayCell(model, day)
        }
    }.spacing(8.vp)
}

// 每个日格都是一个弹性网格单元；空白格用 Spacer().flex() 占位，保持首尾两周的列节奏。
func dayCell(model: CalendarModel, day: Int64): Unit {
    if (day == 0) {
        Spacer().flex()
        return
    }
    let button = Button("${day}", {=> model.selected.value = day}).role(dayRole(model, day))
    if (day != model.selected.value && model.isToday(day)) {
        button.style(todaySurface())
    }
    let _ = button.flex()
}

func dayRole(model: CalendarModel, day: Int64): ButtonRole {
    if (day == model.selected.value) {
        ButtonRole.Primary
    } else {
        ButtonRole.Normal
    }
}

func agendaPage(model: CalendarModel): Unit {
    VStack {
        Label(model.selectedDateLine()).muted()
        agendaItem("09:30", "项目规划评审")
        agendaItem("14:00", "设计方案走查")
        agendaItem("17:30", "整理个人笔记")
        Spacer()
    }.spacing(10.vp).padding(6.vp)
}

func agendaItem(time: String, title: String): Unit {
    Panel {
        HStack {
            Label(time).foregroundColor(CALENDAR_ACCENT).fontSize(FontSizes.CAPTION)
            Label(title)
            Spacer()
        }.spacing(14.vp)
    }.contentPadding(12.vp).style(agendaCardSurface()).hug()
}
