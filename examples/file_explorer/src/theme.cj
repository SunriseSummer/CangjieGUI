/*
 * 文件浏览器主题：中性冷灰配色 + 青蓝强调色，贴近代码编辑器的资源管理器观感。令牌集中于此。
 */
package cui_file_explorer

import cui.{Color, Length, LengthUnits, Theme}

/** 应用主标题字号。 */
let EXPLORER_TITLE: Length = 20.fp

func explorerTheme(): Theme {
    Theme(
        Color.rgb(240, 242, 245), // bg
        Color.rgb(255, 255, 255), // panel
        Color.rgb(218, 223, 230), // panelEdge
        Color.rgb(30, 35, 43), // text
        Color.rgb(112, 122, 136), // mutedText
        Color.rgb(30, 140, 170), // accent
        Color.rgb(255, 255, 255), // accentText
        Color.rgb(206, 74, 68), // danger
        Color.rgb(247, 249, 251), // field
        Color.rgb(232, 244, 248), // fieldActive
        panelRaised: Color.rgb(255, 255, 255),
        accentSoft: Color.rgb(222, 240, 245),
        shadow: Color.rgba(24, 42, 52, 26),
        radius: 12.0,
        controlRadius: 9.0
    )
}
