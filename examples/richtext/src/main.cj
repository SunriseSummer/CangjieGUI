/*
 * 发布说明入口：组装模型与窗口。
 */
package cui_richtext

import cui.{DesktopApp, WindowSpec}

main(): Unit {
    let model = RichTextModel()
    let app = DesktopApp(WindowSpec("CUI 发布说明", 680, 760, scale: 1.0), theme: richtextTheme())
    app.run {
        richtextView(model)
    }
}
