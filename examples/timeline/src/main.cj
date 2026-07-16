/*
 * CUI 示例：横向日期时间轴。
 *
 * 演示 `LazyRow` 横向虚拟列表：一条 400 天的日期带，只物化视口附近的日格，滚轮横向滚动、溢出时底部
 * 出现滚动条。每个日格是可点选的日号按钮，选中项驱动详情面板；日期运算全部复用 `CalendarDate`。
 * 今天在入口读取后传入模型，使模型逻辑可确定性地测试。
 */
package cui_timeline

import cui.{CalendarDate, DesktopApp, WindowSpec}

main(): Int64 {
    let model = TimelineModel(CalendarDate.today())
    let app = DesktopApp(WindowSpec("CUI 时间轴", 820, 520, scale: 1.5), theme: timelineTheme())
    app.setMinimumSize(620, 420)
    app.run {
        timelineView(model)
    }
    return 0
}
