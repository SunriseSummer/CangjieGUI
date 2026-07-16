/*
 * 预订视图层：一张录入表单 + 实时结算摘要 + 确认回执。
 *
 *  - 入住/退房用两个 `DatePicker`：点击弹出月历，点选日期即回填；日历浮层压在表单其余行之上。
 *  - 房型 `SegmentedControl`、人数 `Stepper`；四项任一改变，晚数/单价/合计与有效性都由 `derive` 实时更新。
 *  - 退房不晚于入住时摘要转为警示，确认按钮随有效性启用；确认后显示回执，再次编辑即作废回执。
 */
package cui_booking

import cui.{Button, ButtonRole, CrossAxisAlignment, DatePicker, FontSizes, HStack, Label, LengthUnits, Panel,
    SegmentedControl, Spacer, Stepper, VStack}

func bookingView(model: BookingModel): Unit {
    VStack {
        appHeader()
        formPanel(model)
        summaryPanel(model)
        confirmRow(model)
    }.spacing(14.vp).padding(18.vp)
}

func appHeader(): Unit {
    VStack {
        Label("酒店预订").fontSize(BOOKING_TITLE)
        Label("选择入住与退房日期，实时计算晚数与合计；日期可点选或键盘方向键调整").muted()
            .fontSize(FontSizes.CAPTION)
    }.spacing(2.vp).hug()
}

func formPanel(model: BookingModel): Unit {
    Panel {
        VStack {
            formRow("入住日期") {
                => DatePicker(model.checkIn)
            }
            formRow("退房日期") {
                => DatePicker(model.checkOut)
            }
            formRow("房型") {
                => SegmentedControl(ROOM_TYPES, model.roomType)
            }
            formRow("入住人数") {
                => Stepper(model.guests, lower: 1, upper: 6)
            }
        }.spacing(12.vp)
    }.contentPadding(16.vp).hug()
}

func formRow(label: String, content: () -> Unit): Unit {
    HStack {
        Label(label).width(84.vp)
        content()
        Spacer()
    }.spacing(12.vp).crossAxisAlignment(CrossAxisAlignment.Center).hug()
}

func summaryPanel(model: BookingModel): Unit {
    Panel {
        // 两个互补的无 else if（本代码库惯用法）：每个分支都是产生输出的语句，
        // 不会像 if/else 表达式那样留下未使用的表达式值。
        if (model.isValid.value) {
            HStack {
                summaryStat("入住", model.checkIn.value.iso())
                summaryStat("退房", model.checkOut.value.iso())
                summaryStat("晚数", "${model.nights.value} 晚")
                summaryStat("每晚", money(model.nightlyRate.value))
                summaryStat("合计", money(model.total.value))
            }.spacing(20.vp)
        }
        if (!model.isValid.value) {
            Label("退房日期需晚于入住日期").foregroundColor(BOOKING_DANGER)
        }
    }.contentPadding(16.vp).hug()
}

func summaryStat(caption: String, value: String): Unit {
    VStack {
        Label(caption).muted().fontSize(FontSizes.CAPTION)
        Label(value).fontSize(FontSizes.BODY)
    }.spacing(3.vp).hug()
}

func confirmRow(model: BookingModel): Unit {
    VStack {
        HStack {
            Button("确认预订", {=> model.confirm()}).role(ButtonRole.Primary).enabled(model.isValid.value)
            Spacer()
        }.hug()
        if (!model.confirmation.value.isEmpty()) {
            Label(model.confirmation.value).foregroundColor(BOOKING_ACCENT).wrap()
        }
    }.spacing(10.vp).hug()
}
