/*
 * 观影清单主题：清爽浅色 + 琥珀金强调（评分点用强调色填充）。令牌集中于此。
 */
package cui_watchlist

import cui.{Color, Theme}

func watchlistTheme(): Theme {
    Theme(
        Color.rgb(244, 243, 240), // bg
        Color.rgb(255, 255, 255), // panel
        Color.rgb(230, 226, 218), // panelEdge
        Color.rgb(38, 34, 28), // text
        Color.rgb(132, 124, 110), // mutedText
        Color.rgb(226, 158, 42), // accent（琥珀金）
        Color.rgb(255, 255, 255), // accentText
        Color.rgb(206, 74, 68), // danger
        Color.rgb(250, 248, 244), // field
        Color.rgb(248, 240, 226), // fieldActive
        panelRaised: Color.rgb(255, 254, 251),
        accentSoft: Color.rgb(250, 236, 208),
        shadow: Color.rgba(48, 38, 20, 22),
        radius: 12.0,
        controlRadius: 9.0
    )
}
