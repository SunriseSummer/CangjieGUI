/*
 * CUI 示例：文件浏览器。
 *
 * 演示 `Breadcrumb` 面包屑导航与惯例的文件管理器交互：工具栏“上级”按钮 + 面包屑跳回上层（末段为当前位置、
 * 不可点，路径过长时中间自动折叠为省略号）；目录内容按 名称/修改日期/大小 三列展示，整行可点——单击文件夹
 * 进入（压入路径）、单击文件选中（状态栏展示详情），悬停高亮；底部状态栏统计条目数。
 */
package cui_explorer

import cui.{DesktopApp, WindowSpec}

main(): Int64 {
    let model = ExplorerModel()
    let app = DesktopApp(WindowSpec("CUI 文件浏览器", 720, 620, scale: 1.25), theme: explorerTheme())
    app.setMinimumSize(560, 460)
    app.run {
        explorerView(model)
    }
    return 0
}
