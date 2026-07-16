/*
 * 向导主题：清爽浅色 + 靛蓝强调。令牌集中于此。
 */
package cui_wizard

import cui.{Color, Theme}

/** 校验提示的警示文字色，视图直接引用。 */
let WIZARD_DANGER: Color = Color.rgb(206, 74, 68)

func wizardTheme(): Theme {
    Theme(
        Color.rgb(238, 240, 245), // bg
        Color.rgb(255, 255, 255), // panel
        Color.rgb(220, 224, 232), // panelEdge
        Color.rgb(30, 34, 44), // text
        Color.rgb(118, 124, 138), // mutedText
        Color.rgb(74, 104, 210), // accent
        Color.rgb(255, 255, 255), // accentText
        Color.rgb(206, 74, 68), // danger
        Color.rgb(246, 248, 251), // field
        Color.rgb(235, 240, 250), // fieldActive
        panelRaised: Color.rgb(255, 255, 255),
        accentSoft: Color.rgb(226, 232, 250),
        shadow: Color.rgba(30, 38, 66, 24),
        radius: 12.0,
        controlRadius: 9.0
    )
}
