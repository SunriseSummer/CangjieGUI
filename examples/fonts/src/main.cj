package cui_fonts

import cui.{DesktopApp, Fonts, FontRole, WindowSpec}

main(args: Array<String>): Int64 {
    registerFonts()
    let model = FontsModel(preferVariable: true)
    for (i in 0..args.size) {
        if (args[i] == "--demo" && i + 1 < args.size) {
            model.selectDemo(args[i + 1])
        }
    }
    let app = DesktopApp(WindowSpec("CUI 字体实验室", 840, 880, scale: 1.0), theme: fontsTheme())
    app.setMinimumSize(620, 600)
    app.run {fontsView(model)}
    0
}

// 应用启动阶段设置一次，避免在每一帧重新注册或重新枚举系统字体。
func registerFonts(): Unit {
    Fonts.setDefault(FontRole.systemUI)
}
