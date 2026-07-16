/*
 * 任务清单主题：清爽浅底 + 靛蓝强调。令牌集中于此。
 */
package cui_tasklist

import cui.{Color, Theme}

func tasklistTheme(): Theme {
    Theme(
        Color.rgb(236, 238, 244), // bg
        Color.rgb(255, 255, 255), // panel
        Color.rgb(222, 226, 234), // panelEdge
        Color.rgb(30, 34, 44), // text
        Color.rgb(118, 124, 138), // mutedText
        Color.rgb(74, 104, 210), // accent
        Color.rgb(255, 255, 255), // accentText
        Color.rgb(206, 74, 68), // danger
        Color.rgb(246, 248, 251), // field
        Color.rgb(235, 240, 250), // fieldActive
        panelRaised: Color.rgb(255, 255, 255),
        accentSoft: Color.rgb(226, 232, 250),
        shadow: Color.rgba(30, 38, 66, 30),
        radius: 12.0,
        controlRadius: 9.0
    )
}
