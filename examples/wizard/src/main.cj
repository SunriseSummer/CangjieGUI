/*
 * CUI 示例：账户设置向导。
 *
 * 演示 `StepIndicator` 步骤条：四步流程，已完成打勾、当前高亮、未来置灰，可点已完成步骤跳回。配合
 * 上一步/下一步 步进导航与逐步必填校验，把步骤条、各步表单与导航按钮都从单一状态派生。
 */
package cui_wizard

import cui.{DesktopApp, WindowSpec}

main(): Int64 {
    let model = WizardModel()
    let app = DesktopApp(WindowSpec("CUI 向导", 640, 540, scale: 1.5), theme: wizardTheme())
    app.setMinimumSize(520, 460)
    app.run {
        wizardView(model)
    }
    return 0
}
