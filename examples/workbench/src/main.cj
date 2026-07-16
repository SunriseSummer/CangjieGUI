/*
 * CUI 示例：分栏工作台。
 *
 * 演示 `SplitView` 分栏容器：外层横向分栏（导航｜工作区）内再嵌纵向分栏（编辑器／信息），三区边界
 * 皆由可拖动、可键盘微调的分隔条分配。综合演示嵌套分栏、`project` 主从绑定、`derive` 派生大纲与
 * 统计，以及 ListView / TextArea / ScrollView 在分栏窗格中的填充行为。
 */
package cui_workbench

import cui.{DesktopApp, WindowSpec}

main(): Int64 {
    let model = WorkbenchModel()
    let app = DesktopApp(WindowSpec("CUI 工作台", 960, 660, scale: 1.5), theme: workbenchTheme())
    app.setMinimumSize(720, 520)
    app.run {
        workbenchView(model)
    }
    return 0
}
