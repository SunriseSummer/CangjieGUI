/*
 * 追踪器主题：清爽浅色 + 靛蓝强调。语义色（成功/警告/危险）由 Badge 自带，不在此。令牌集中于此。
 */
package cui_tracker

import cui.{Color, Theme}

func trackerTheme(): Theme {
    Theme(
        Color.rgb(243, 244, 247), // bg
        Color.rgb(255, 255, 255), // panel
        Color.rgb(224, 227, 233), // panelEdge
        Color.rgb(30, 34, 42), // text
        Color.rgb(118, 125, 138), // mutedText
        Color.rgb(84, 96, 220), // accent
        Color.rgb(255, 255, 255), // accentText
        Color.rgb(208, 76, 70), // danger
        Color.rgb(247, 248, 251), // field
        Color.rgb(236, 238, 250), // fieldActive
        panelRaised: Color.rgb(252, 253, 255),
        accentSoft: Color.rgb(228, 231, 250),
        shadow: Color.rgba(28, 34, 66, 20),
        radius: 12.0,
        controlRadius: 9.0
    )
}
