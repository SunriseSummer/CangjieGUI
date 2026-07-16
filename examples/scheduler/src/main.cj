/*
 * CUI 示例：会议排期。
 *
 * 演示 `TimePicker` 时间选择：弹出的时/分网格选时，点选实时更新、方向键微调（上下按分步、左右按小时，跨午夜环绕），
 * 与 `DatePicker` 并排组成一行日程表单。开始/结束时间实时算出时长，配合主题非空校验决定“添加”可用性；
 * 已排会议按 (日期, 开始时间) 升序排列。综合演示时间选择 + 日期选择 + 派生校验 + 排序列表。
 */
package cui_scheduler

import cui.{DesktopApp, WindowSpec}

main(): Int64 {
    let model = SchedulerModel()
    let app = DesktopApp(WindowSpec("CUI 会议排期", 680, 660, scale: 1.25), theme: schedulerTheme())
    app.setMinimumSize(560, 520)
    app.run {
        schedulerView(model)
    }
    return 0
}
