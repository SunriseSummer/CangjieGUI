/*
 * CUI 示例：字体样式排版样张。
 *
 * 演示 `Label` 的字体样式修饰符 `.bold()` / `.italic()` / `.underline()` / `.strikethrough()`——
 * 粗体/斜体优先使用真实字体面，不具备时按策略合成；斜体使用缓存的整段纹理路径。
 * 顶部四个 `Chip` 实时切换样式，字号阶梯逐档以当前样式渲染；下方是一张各样式的静态参考卡。
 * 综合演示字体样式 + 状态绑定 + 派生摘要。
 */
package cui_typography

import cui.{DesktopApp, WindowSpec, Fonts, FontRole}

main(): Int64 {
    Fonts.setDefault(FontRole.systemUI)
    let model = TypographyModel()
    let app = DesktopApp(WindowSpec("CUI 字体样式", 640, 720, scale: 1.0), theme: typographyTheme())
    app.setMinimumSize(520, 560)
    app.run {
        typographyView(model)
    }
    return 0
}
