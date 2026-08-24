/*
 * CUI 示例：设计令牌样式指南。
 *
 * 一份“活的样式指南”，集中展示 CUI 的设计令牌尺度：间距 `Spacing`、圆角 `Radii`、动效 `Motion`（时长 + 缓动），
 * 以及既有的字号尺度 `FontSizes` 与高度预设 `Shadow.elevation`。页面自身也用这些令牌排版（间距、圆角、高度），
 * 既是参考也是范例。综合演示设计令牌体系 + 样式属性的合成运用。
 */
package cui_styleguide

import cui.{DesktopApp, WindowSpec}

main(): Int64 {
    let app = DesktopApp(WindowSpec("CUI 设计令牌", 660, 720, scale: 1.0), theme: styleguideTheme())
    app.setMinimumSize(560, 560)
    app.run {
        styleguideView()
    }
    return 0
}
