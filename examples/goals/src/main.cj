/*
 * CUI 示例：每日目标。
 *
 * 演示 `ProgressRing` 环形进度：一圈轨道 + 从顶部顺时针扫到当前完成度的弧（圆角折线，任意尺寸都平滑），
 * 环心显示百分比。四个目标各一个环，顶部另有一个总完成度环；点 +/- 调整当前值，各环与总环实时更新。
 * 综合演示环形进度 + 派生完成度 + 交互调整。
 */
package cui_goals

import cui.{DesktopApp, WindowSpec}

main(): Int64 {
    let model = GoalsModel()
    let app = DesktopApp(WindowSpec("CUI 每日目标", 600, 680, scale: 1.2), theme: goalsTheme())
    app.setMinimumSize(480, 520)
    app.run {
        goalsView(model)
    }
    return 0
}
