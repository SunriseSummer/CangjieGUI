/*
 * CUI 示例：文件浏览器。
 *
 * 演示 `TreeView` 层级列表：展开/折叠、层级缩进与图标、按 id 选择、键盘导航（↑↓/←→/空格）。
 * 布局复用上一组件 `SplitView` 分出可拖动的左右两栏，右栏详情由选中项从索引查得，示范组件间组合。
 */
package cui_file_explorer

import cui.{DesktopApp, WindowSpec}

main(): Int64 {
    let model = ExplorerModel()
    let app = DesktopApp(WindowSpec("CUI 文件浏览器", 900, 640, scale: 1.5), theme: explorerTheme())
    app.setMinimumSize(680, 480)
    app.run {
        explorerView(model)
    }
    return 0
}
