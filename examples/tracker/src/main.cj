/*
 * CUI 示例：问题追踪。
 *
 * 演示 `Badge` 状态徽标与 `Chip` 过滤标签：每条问题以语义色徽标（中性/强调/成功/警告/危险）标注状态与优先级；
 * 顶部一排可点的过滤 `Chip` 切换各状态是否显示。过滤开关是唯一数据源（`State.project` 逐状态镜头绑定 Chip），
 * 可见列表由它与问题列表纯函数派生。综合演示徽标 + 过滤标签 + 镜头绑定 + 派生列表。
 */
package cui_tracker

import cui.{DesktopApp, WindowSpec}

main(): Int64 {
    let model = TrackerModel()
    let app = DesktopApp(WindowSpec("CUI 问题追踪", 680, 620, scale: 1.25), theme: trackerTheme())
    app.setMinimumSize(560, 500)
    app.run {
        trackerView(model)
    }
    return 0
}
