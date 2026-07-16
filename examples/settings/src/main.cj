/*
 * CUI 示例：设置面板（折叠分区）。
 *
 * 演示 `Accordion` 折叠面板：外观/通知/隐私/关于四个可折叠分区，分区体是真实控件（分段/滑块/开关/复选/
 * 单选/按钮），只在展开时构建。抬头的“单开模式”开关驱动 `single`，开启后展开一个分区会收起其它。
 */
package cui_settings

import cui.{DesktopApp, WindowSpec}

main(): Int64 {
    let model = SettingsModel()
    let app = DesktopApp(WindowSpec("CUI 设置", 620, 640, scale: 1.5), theme: settingsTheme())
    app.setMinimumSize(480, 480)
    app.run {
        settingsView(model)
    }
    return 0
}
