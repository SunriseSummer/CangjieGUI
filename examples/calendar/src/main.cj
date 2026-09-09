/*
 * CUI 示例：月历。
 *
 * 演示内容：
 *  - Flexible 构成的真实网格：表头与日格共享七列节奏
 *  - 状态驱动的导航：箭头改写年/月 State，整个网格随下一帧刷新
 *  - derive 派生的标题、系统时钟驱动的“今天”高亮
 *  - 用 Surface 生成小图片资产并以 ImageView 展示：纹理由共享缓存按路径保留，
 *    ImageView 像其他控件一样逐帧内联声明即可
 */
package cui_calendar

import cui.{DesktopApp, FileSystem, Time, WindowSpec}

main(): Int64 {
    writeCalendarBadge()
    try {
        let model = CalendarModel(Time.currentDateTime())
        let app = DesktopApp(WindowSpec("CUI 日历", 780, 560, scale: 1.0), theme: calendarTheme())
        app.setMinimumSize(560, 440)
        app.run {
            // 长时间运行跨过午夜后，“今天”高亮随系统时钟走，而非停在启动那天。
            model.refreshToday(Time.currentDateTime())
            calendarView(model)
        }
    } finally {
        if (FileSystem.exists(CALENDAR_BADGE)) {
            FileSystem.remove(CALENDAR_BADGE)
        }
    }
    return 0
}
