/*
 * CUI 示例：文件浏览器。
 *
 * 演示 `Breadcrumb` 面包屑导航：顶部显示 根目录 › … › 当前 的路径，点任意一段跳回该层，末段为当前位置（不可点），
 * 路径过长时中间自动折叠为省略号。下方列出当前目录内容，点文件夹进入（压入路径），与面包屑构成完整的上下导航。
 */
package cui_explorer

import cui.{DesktopApp, WindowSpec}

main(): Int64 {
    let model = ExplorerModel()
    let app = DesktopApp(WindowSpec("CUI 文件浏览器", 640, 620, scale: 1.25), theme: explorerTheme())
    app.setMinimumSize(520, 480)
    app.run {
        explorerView(model)
    }
    return 0
}
