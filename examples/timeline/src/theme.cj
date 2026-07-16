/*
 * 时间轴主题：冷调浅底 + 蓝紫强调色。令牌集中于此。
 */
package cui_timeline

import cui.{Color, Length, LengthUnits, Theme}

/** 应用主标题字号。 */
let TIMELINE_TITLE: Length = 20.fp

/** 日格星期名的强调（今天）与常规（其余）色，视图直接引用。 */
let TIMELINE_ACCENT: Color = Color.rgb(88, 96, 214)
let TIMELINE_MUTED: Color = Color.rgb(120, 126, 140)

func timelineTheme(): Theme {
    Theme(
        Color.rgb(238, 239, 245), // bg
        Color.rgb(255, 255, 255), // panel
        Color.rgb(220, 222, 232), // panelEdge
        Color.rgb(30, 32, 44), // text
        Color.rgb(116, 120, 136), // mutedText
        Color.rgb(88, 96, 214), // accent
        Color.rgb(255, 255, 255), // accentText
        Color.rgb(206, 74, 68), // danger
        Color.rgb(247, 248, 251), // field
        Color.rgb(236, 238, 250), // fieldActive
        panelRaised: Color.rgb(255, 255, 255),
        accentSoft: Color.rgb(226, 228, 250),
        shadow: Color.rgba(30, 34, 66, 26),
        radius: 12.0,
        controlRadius: 9.0
    )
}
