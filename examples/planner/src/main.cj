/*
 * CUI 示例：专注规划台。
 *
 * 演示内容：
 *  - Keyed 与 rememberState 管理的局部状态
 *  - ScrollView、Grid、FlowRow 组合的桌面布局
 *  - ProgressBar 动画进度与 maxLines 文本换行
 */
package cui_planner

import cui.{DesktopApp, WindowSpec}

main(): Int64 {
    let model = PlannerModel()
    let app = DesktopApp(WindowSpec("CUI 专注规划台", 1120, 720, scale: 1.0), theme: plannerTheme())
    app.setMinimumSize(760, 560)
    app.run {
        plannerView(model)
    }
    return 0
}
