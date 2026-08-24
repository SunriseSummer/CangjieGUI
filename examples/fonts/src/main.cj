/*
 * CUI 示例：本地字体文件加载。
 *
 * 演示 `Fonts.register(name, path)` 从本地字体文件加载字体，再由 `Label.fontFamily(name)` 套用——
 * 加载一款衬线与一款等宽字体，与系统默认字体并列对照，可切换样张字体并叠加粗体。字体名解析（挑第一个
 * 存在的候选文件）与选中项到字体名的映射都是纯函数；找不到文件的字体运行时自动回退系统字体。
 */
package cui_fonts

import cui.{DesktopApp, FileSystem, Fonts, WindowSpec}

main(): Int64 {
    registerFonts()
    let model = FontsModel()
    let app = DesktopApp(WindowSpec("CUI 字体加载", 660, 720, scale: 1.0), theme: fontsTheme())
    app.setMinimumSize(540, 560)
    app.run {
        fontsView(model)
    }
    return 0
}

// 为每种字体挑第一个存在的候选文件并注册（系统默认项跳过）。找不到文件者不注册，运行时自动回退系统字体。
func registerFonts(): Unit {
    for (face in TYPEFACES) {
        if (let Some(family) <- face.family) {
            if (let Some(path) <- firstExisting(face.candidates, {p => FileSystem.exists(p)})) {
                Fonts.register(family, path)
            }
        }
    }
}
