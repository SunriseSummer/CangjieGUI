/*
 * CUI 示例：字体样式排版样张。
 *
 * 演示 `Label` 的字体样式修饰符 `.bold()` / `.italic()` / `.underline()` / `.strikethrough()`——
 * 均由渲染层从单一系统字体经 SDL_ttf 合成，Latin 与 CJK 一视同仁，无需额外字体文件。
 * 顶部四个 `Chip` 实时切换样式，字号阶梯逐档以当前样式渲染；下方是一张各样式的静态参考卡。
 * 综合演示字体样式 + 状态绑定 + 派生摘要。
 */
package cui_typography

import cui.{DesktopApp, WindowSpec}

main(): Int64 {
    let model = TypographyModel()
    let app = DesktopApp(WindowSpec("CUI 字体样式", 640, 720, scale: 1.0), theme: typographyTheme())
    app.setMinimumSize(520, 560)
    app.run {
        typographyView(model)
    }
    return 0
}
