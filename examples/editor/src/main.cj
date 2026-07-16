/*
 * CUI 示例：菜单栏文本编辑器。
 *
 * 演示 `MenuBar` 应用菜单栏：文件/编辑/帮助多个菜单，菜单项带快捷键提示、分隔线与随文档状态动态启用/
 * 禁用。点击展开、菜单间悬停切换，或 Tab 聚焦后方向键导航。菜单动作作用于模型，`TextArea` 绑定正文，
 * 状态栏显示上次动作与实时行数、字数。
 */
package cui_editor

import cui.{DesktopApp, WindowSpec}

main(): Int64 {
    let model = EditorModel()
    let app = DesktopApp(WindowSpec("CUI 编辑器", 760, 560, scale: 1.5), theme: editorTheme())
    app.setMinimumSize(560, 420)
    app.run {
        editorView(model)
    }
    return 0
}
