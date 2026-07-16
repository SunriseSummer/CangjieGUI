/*
 * 排期视图层：表单（主题 / 日期 / 开始 / 结束 + 时长 + 添加）与已排日程列表。
 *
 *  - 开始/结束用两个 `TimePicker` 选时，日期用 `DatePicker`；时长由二者实时计算，无效时红字提示。
 *  - “添加到日程”仅在时长有效且主题非空时可用；已排会议按 (日期, 开始时间) 升序展示。
 */
package cui_scheduler

import cui.{Button, ButtonRole, CrossAxisAlignment, DatePicker, FontSizes, HStack, Label, LengthUnits, Panel,
    ScrollView, Spacer, TextField, TimePicker, VStack}

func schedulerView(model: SchedulerModel): Unit {
    VStack {
        header()
        Panel {
            formBody(model)
        }.contentPadding(18.vp).hug()
        Panel {
            meetingsPanel(model)
        }.contentPadding(14.vp).flex()
    }.spacing(14.vp).padding(18.vp)
}

func header(): Unit {
    VStack {
        Label("会议排期").fontSize(FontSizes.TITLE)
        Label("用 TimePicker 选择开始与结束时间，实时计算时长并按时间排入日程").muted().fontSize(FontSizes.CAPTION)
    }.spacing(3.vp).hug()
}

func formBody(model: SchedulerModel): Unit {
    VStack {
        formField("会议主题") {=> TextField(model.title)}
        HStack {
            formField("日期") {=> DatePicker(model.date)}
            Spacer()
        }.hug()
        HStack {
            formField("开始") {=> TimePicker(model.start)}
            formField("结束") {=> TimePicker(model.end)}
            Spacer()
        }.spacing(12.vp).hug()
        HStack {
            Label("时长").muted().fontSize(FontSizes.CAPTION).width(48.vp)
            if (model.durationMinutes() > 0) {
                Label(formatDuration(model.durationMinutes())).fontSize(FontSizes.BODY)
            }
            if (model.durationMinutes() <= 0) {
                Label("结束需晚于开始").foregroundColor(SCHEDULER_DANGER).fontSize(FontSizes.CAPTION)
            }
            Spacer()
            Button("添加到日程", {=> model.addMeeting()}).role(ButtonRole.Primary).enabled(model.canAdd())
        }.crossAxisAlignment(CrossAxisAlignment.Center).hug()
    }.spacing(14.vp)
}

func meetingsPanel(model: SchedulerModel): Unit {
    let items = model.meetings.value
    VStack {
        Label("已排日程（${items.size}）").muted().fontSize(FontSizes.CAPTION)
        ScrollView {
            VStack {
                for (m in items) {
                    meetingRow(m)
                }
            }.spacing(8.vp)
        }.flex()
    }.spacing(10.vp)
}

private func meetingRow(m: Meeting): Unit {
    Panel {
        HStack {
            VStack {
                Label(m.title).fontSize(FontSizes.CONTROL)
                Label(m.date.iso()).muted().fontSize(FontSizes.CAPTION)
            }.spacing(2.vp).hug().flex()
            VStack {
                Label(meetingTimeRange(m)).fontSize(FontSizes.CONTROL)
                Label(formatDuration(meetingDurationMinutes(m.start, m.end))).muted().fontSize(FontSizes.CAPTION)
            }.spacing(2.vp).crossAxisAlignment(CrossAxisAlignment.End).hug()
        }.crossAxisAlignment(CrossAxisAlignment.Center).hug()
    }.contentPadding(12.vp)
}

func formField(label: String, control: () -> Unit): Unit {
    VStack {
        Label(label).muted().fontSize(FontSizes.CAPTION)
        control()
    }.spacing(4.vp).hug()
}
