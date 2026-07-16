/*
 * 时间轴视图层：抬头 + 横向日期带 + 选中日期详情。
 *
 *  - 日期带是 `LazyRow`：400 个日格只物化视口附近的十几个；鼠标滚轮横向滚动，溢出时底部出现滚动条。
 *  - 每个日格上排星期（今天用强调色）、中间是可点选的日号按钮（选中用主色）、下排月份；点按钮即选中。
 *  - 详情面板由选中项派生：完整日期、星期与相对今天的天数，全部走 `CalendarDate` 运算。
 */
package cui_timeline

import cui.{Button, ButtonRole, CrossAxisAlignment, FontSizes, HStack, Label, LazyRow, LengthUnits, Panel, Spacer,
    TextAlign, VStack}

func timelineView(model: TimelineModel): Unit {
    VStack {
        appHeader(model)
        stripBand(model)
        detailPanel(model)
        Spacer()
    }.spacing(14.vp).padding(18.vp)
}

func appHeader(model: TimelineModel): Unit {
    HStack {
        VStack {
            Label("时间轴").fontSize(TIMELINE_TITLE)
            Label("横向日期带由 LazyRow 虚拟化，400 天只渲染视口附近；滚轮横向滚动，点日号选中").muted()
                .fontSize(FontSizes.CAPTION)
        }.spacing(2.vp).hug()
        Spacer()
        Button("回到今天", {=> model.backToToday()}).role(ButtonRole.Primary)
    }.crossAxisAlignment(CrossAxisAlignment.Center).hug()
}

// 固定高度的条带承载横向日期带；LazyRow 充满其中并在内部滚动。
func stripBand(model: TimelineModel): Unit {
    Panel {
        LazyRow(model.count, TIMELINE_CELL_W, spacing: TIMELINE_SPACING, scroll: Some(model.scroll)) {
            index => dayCell(model, index)
        }
    }.contentPadding(10.vp).height(120.vp)
}

func dayCell(model: TimelineModel, index: Int64): Unit {
    let date = model.dateAt(index)
    let isSelected = index == model.selected.value
    let weekdayColor = if (date == model.today) {
        TIMELINE_ACCENT
    } else {
        TIMELINE_MUTED
    }
    VStack {
        Label(weekdayShort(date)).fontSize(FontSizes.CAPTION).foregroundColor(weekdayColor).textAlign(TextAlign.Center)
        Button("${date.day}", {=> model.selected.value = index}).role(cellRole(isSelected)).fillWidth()
        Label("${date.month} 月").fontSize(FontSizes.CAPTION).muted().textAlign(TextAlign.Center)
    }.spacing(4.vp)
}

func cellRole(isSelected: Bool): ButtonRole {
    if (isSelected) {
        ButtonRole.Primary
    } else {
        ButtonRole.Normal
    }
}

func detailPanel(model: TimelineModel): Unit {
    let date = model.selectedDate()
    Panel {
        VStack {
            Label("${date.year} 年 ${date.month} 月 ${date.day} 日").fontSize(FontSizes.DISPLAY)
            HStack {
                Label(weekdayFull(date))
                Label("·").muted()
                Label(relativeLabel(model.selectedDelta())).muted()
            }.spacing(8.vp).crossAxisAlignment(CrossAxisAlignment.Center).hug()
        }.spacing(8.vp)
    }.contentPadding(18.vp).hug()
}
