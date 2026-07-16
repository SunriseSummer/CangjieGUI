/*
 * 活动流主题：清爽浅底 + 靛蓝强调。操作者名的颜色作为令牌供视图直接引用。
 */
package cui_activity

import cui.{Color, Theme}

/** 操作者名的强调色（比正文更醒目，与动作色区分）。 */
let ACTIVITY_ACTOR: Color = Color.rgb(52, 58, 82)

func activityTheme(): Theme {
    Theme(
        Color.rgb(238, 240, 245), // bg
        Color.rgb(255, 255, 255), // panel
        Color.rgb(222, 225, 233), // panelEdge
        Color.rgb(34, 38, 48), // text
        Color.rgb(122, 128, 142), // mutedText
        Color.rgb(72, 96, 200), // accent
        Color.rgb(255, 255, 255), // accentText
        Color.rgb(206, 74, 68), // danger
        Color.rgb(247, 249, 251), // field
        Color.rgb(236, 240, 250), // fieldActive
        panelRaised: Color.rgb(255, 255, 255),
        accentSoft: Color.rgb(226, 232, 250),
        shadow: Color.rgba(30, 38, 66, 24),
        radius: 12.0,
        controlRadius: 9.0
    )
}
