/*
 * CUI 示例：酒店预订。
 *
 * 演示 `DatePicker` 日期选择器：弹出月历、点选或键盘选择日期、月份翻页、越月滚动。两个日期驱动
 * `derive` 派生的晚数、单价、合计与有效性校验，配合 `SegmentedControl`、`Stepper` 组成一张实时结算表单。
 * 今天的日期在入口读取后传入模型，使模型逻辑可确定性地测试。
 */
package cui_booking

import cui.{CalendarDate, DesktopApp, WindowSpec}

main(): Int64 {
    let model = BookingModel(CalendarDate.today())
    let app = DesktopApp(WindowSpec("CUI 酒店预订", 720, 560, scale: 1.5), theme: bookingTheme())
    app.setMinimumSize(560, 460)
    app.run {
        bookingView(model)
    }
    return 0
}
