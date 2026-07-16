/*
 * 设置主题：中性浅色 + 靛蓝强调。令牌集中于此。
 */
package cui_settings

import cui.{Color, Theme}

func settingsTheme(): Theme {
    Theme(
        Color.rgb(236, 238, 243), // bg
        Color.rgb(255, 255, 255), // panel
        Color.rgb(220, 224, 232), // panelEdge
        Color.rgb(30, 34, 44), // text
        Color.rgb(116, 122, 138), // mutedText
        Color.rgb(74, 100, 208), // accent
        Color.rgb(255, 255, 255), // accentText
        Color.rgb(206, 74, 68), // danger
        Color.rgb(244, 246, 250), // field
        Color.rgb(234, 238, 249), // fieldActive
        panelRaised: Color.rgb(255, 255, 255),
        accentSoft: Color.rgb(226, 232, 250),
        shadow: Color.rgba(30, 38, 66, 24),
        radius: 12.0,
        controlRadius: 9.0
    )
}
