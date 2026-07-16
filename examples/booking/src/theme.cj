/*
 * 预订主题：温暖的米色纸面 + 松绿强调色，贴近酒店预订的沉静观感。令牌集中于此。
 */
package cui_booking

import cui.{Color, Length, LengthUnits, Theme}

/** 应用主标题字号。 */
let BOOKING_TITLE: Length = 20.fp

/** 强调（成功）与警示文字色，视图直接引用，避免在视图层重复取主题。 */
let BOOKING_ACCENT: Color = Color.rgb(46, 138, 106)
let BOOKING_DANGER: Color = Color.rgb(198, 84, 66)

func bookingTheme(): Theme {
    Theme(
        Color.rgb(244, 242, 236), // bg
        Color.rgb(255, 255, 255), // panel
        Color.rgb(224, 220, 210), // panelEdge
        Color.rgb(34, 38, 34), // text
        Color.rgb(116, 120, 112), // mutedText
        Color.rgb(46, 138, 106), // accent
        Color.rgb(255, 255, 255), // accentText
        Color.rgb(198, 84, 66), // danger
        Color.rgb(248, 248, 244), // field
        Color.rgb(234, 244, 238), // fieldActive
        panelRaised: Color.rgb(255, 255, 255),
        accentSoft: Color.rgb(224, 240, 232),
        shadow: Color.rgba(40, 50, 40, 26),
        radius: 13.0,
        controlRadius: 9.0
    )
}
