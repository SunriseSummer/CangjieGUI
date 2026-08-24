/*
 * CUI 示例：本地字体样本册（霞鹜文楷）。
 *
 * 演示用 `Fonts.register` 从本地字体文件加载真实 CJK 字体：三个比例字重与一个等宽变体各占一个注册名，
 * `fontFamily` 按名套用即换字重。字体文件缺失时整页按未注册名回退系统字体，页面结构不变。
 * 综合演示本地字体加载 + 多字重 + CJK 样张排版。
 */
package cui_wenkai

import cui.{DesktopApp, FileSystem, Fonts, WindowSpec}

main(): Int64 {
    let dir = resolveFontsDir(FONT_DIR_CANDIDATES, {p => FileSystem.exists(p)})
    let registered = registerWeights(dir, {name, path => Fonts.register(name, path)})
    let model = WenkaiModel(registered)
    let app = DesktopApp(WindowSpec("CUI 本地字体样本册", 640, 640, scale: 1.0), theme: wenkaiTheme())
    app.setMinimumSize(520, 480)
    app.run {
        wenkaiView(model)
    }
    return 0
}
