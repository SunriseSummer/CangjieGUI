/*
 * 浏览器主题：清爽浅色 + 蓝色强调（文件夹图标与面包屑链接用强调色）。令牌集中于此。
 */
package cui_explorer

import cui.{Color, Theme}

// 文件夹图标色，视图直接引用。
let EXPLORER_FOLDER: Color = Color.rgb(72, 120, 224)

// 文件图标与右侧箭头的弱化色（与主题 mutedText 一致）。
let EXPLORER_MUTED: Color = Color.rgb(120, 127, 140)

func explorerTheme(): Theme {
    Theme(
        Color.rgb(242, 244, 248), // bg
        Color.rgb(255, 255, 255), // panel
        Color.rgb(224, 228, 234), // panelEdge
        Color.rgb(30, 35, 44), // text
        Color.rgb(120, 127, 140), // mutedText
        Color.rgb(60, 110, 224), // accent
        Color.rgb(255, 255, 255), // accentText
        Color.rgb(206, 74, 68), // danger
        Color.rgb(247, 249, 252), // field
        Color.rgb(235, 241, 250), // fieldActive
        panelRaised: Color.rgb(252, 253, 255),
        accentSoft: Color.rgb(224, 233, 250),
        shadow: Color.rgba(28, 40, 66, 20),
        radius: 12.0,
        controlRadius: 9.0
    )
}
