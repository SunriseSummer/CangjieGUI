/*
 * 工作台主题：冷调石板灰底 + 靛蓝强调色，凸显分栏边界与聚焦分隔条。令牌集中于此。
 */
package cui_workbench

import cui.{Color, Length, LengthUnits, Theme}

/** 应用主标题字号。 */
let WORKBENCH_TITLE: Length = 20.fp

func workbenchTheme(): Theme {
    Theme(
        Color.rgb(236, 238, 243), // bg
        Color.rgb(255, 255, 255), // panel
        Color.rgb(216, 221, 230), // panelEdge
        Color.rgb(28, 33, 42), // text
        Color.rgb(108, 116, 132), // mutedText
        Color.rgb(72, 108, 214), // accent
        Color.rgb(255, 255, 255), // accentText
        Color.rgb(206, 74, 68), // danger
        Color.rgb(247, 249, 252), // field
        Color.rgb(236, 241, 252), // fieldActive
        panelRaised: Color.rgb(255, 255, 255),
        accentSoft: Color.rgb(224, 232, 251),
        shadow: Color.rgba(28, 40, 72, 28),
        radius: 12.0,
        controlRadius: 9.0
    )
}
