/*
 * 排期主题：清爽浅色 + 青蓝强调。令牌集中于此。
 */
package cui_scheduler

import cui.{Color, Theme}

// 无效时长（结束早于开始）的警示文字色，视图直接引用。
let SCHEDULER_DANGER: Color = Color.rgb(206, 74, 68)

func schedulerTheme(): Theme {
    Theme(
        Color.rgb(240, 243, 246), // bg
        Color.rgb(255, 255, 255), // panel
        Color.rgb(222, 227, 232), // panelEdge
        Color.rgb(28, 34, 42), // text
        Color.rgb(116, 124, 136), // mutedText
        Color.rgb(20, 148, 168), // accent
        Color.rgb(255, 255, 255), // accentText
        Color.rgb(206, 74, 68), // danger
        Color.rgb(246, 249, 251), // field
        Color.rgb(232, 244, 246), // fieldActive
        panelRaised: Color.rgb(252, 254, 255),
        accentSoft: Color.rgb(214, 240, 244),
        shadow: Color.rgba(24, 40, 52, 22),
        radius: 12.0,
        controlRadius: 9.0
    )
}
