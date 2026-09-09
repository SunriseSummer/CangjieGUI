package cui_symbols

import cui.{DesktopApp, Theme, WindowSpec}

main(): Unit {
    let model = SymbolsModel()
    let app = DesktopApp(WindowSpec("CUI · 预置图标图鉴", 1180, 1100), theme: Theme.light())
    app.setMinimumSize(1180, 1100)
    app.run {symbolsView(model)}
}
