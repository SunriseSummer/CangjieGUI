/*
 * CUI 示例：文件活动流。
 *
 * 演示 `RichText` 富文本：每条活动把彩色图标、强调色操作者、常规动词、动作色文件与弱化时间拼在一行，
 * 长路径在卡片宽度内自动换行、图标随文流动。分段控件按动作类型筛选。
 */
package cui_activity

import cui.{DesktopApp, WindowSpec}

main(): Int64 {
    let model = ActivityModel()
    let app = DesktopApp(WindowSpec("CUI 活动流", 680, 620, scale: 1.5), theme: activityTheme())
    app.setMinimumSize(520, 460)
    app.run {
        activityView(model)
    }
    return 0
}
