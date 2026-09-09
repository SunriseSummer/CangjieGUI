package cui_icons

import cui.*

main(): Unit {
    let model = IconsModel()
    let app = DesktopApp(WindowSpec("CUI · 图标工坊", 1060, 1020), theme: Theme.light())
    app.setMinimumSize(1060, 820)
    app.run {iconsView(model)}
}
