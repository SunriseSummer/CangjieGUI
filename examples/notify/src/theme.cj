/*
 * 通知示例主题：深色底衬托浮起的通知卡片。令牌集中于此。
 */
package cui_notify

import cui.{Color, Theme}

func notifyTheme(): Theme {
    Theme(
        Color.rgb(26, 29, 38), // bg
        Color.rgb(38, 42, 54), // panel
        Color.rgb(54, 59, 74), // panelEdge
        Color.rgb(232, 235, 242), // text
        Color.rgb(150, 156, 170), // mutedText
        Color.rgb(96, 132, 246), // accent
        Color.rgb(255, 255, 255), // accentText
        Color.rgb(226, 92, 86), // danger
        Color.rgb(46, 51, 64), // field
        Color.rgb(54, 60, 78), // fieldActive
        panelRaised: Color.rgb(46, 51, 64),
        accentSoft: Color.rgb(52, 62, 96),
        shadow: Color.rgba(0, 0, 0, 120),
        radius: 12.0,
        controlRadius: 10.0
    )
}
