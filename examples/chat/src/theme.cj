/*
 * 聊天主题：柔和的浅蓝底 + 蓝色气泡。气泡与文字色作为令牌供视图直接引用。
 */
package cui_chat

import cui.{Color, Theme}

/** 气泡背景与文字色：我方（右、蓝底白字）与对方（左、白底深字）。 */
let CHAT_MINE_BG: Color = Color.rgb(64, 120, 240)
let CHAT_MINE_TEXT: Color = Color.rgb(255, 255, 255)
let CHAT_MINE_SUB: Color = Color.rgb(214, 226, 252)
let CHAT_OTHER_BG: Color = Color.rgb(255, 255, 255)
let CHAT_OTHER_TEXT: Color = Color.rgb(32, 36, 46)
let CHAT_OTHER_SUB: Color = Color.rgb(122, 128, 142)

func chatTheme(): Theme {
    Theme(
        Color.rgb(232, 236, 244), // bg
        Color.rgb(244, 246, 250), // panel（消息区底色，比气泡略深）
        Color.rgb(220, 224, 232), // panelEdge
        Color.rgb(32, 36, 46), // text
        Color.rgb(120, 126, 140), // mutedText
        Color.rgb(64, 120, 240), // accent
        Color.rgb(255, 255, 255), // accentText
        Color.rgb(206, 74, 68), // danger
        Color.rgb(255, 255, 255), // field
        Color.rgb(238, 242, 252), // fieldActive
        panelRaised: Color.rgb(255, 255, 255),
        accentSoft: Color.rgb(224, 233, 252),
        shadow: Color.rgba(30, 44, 80, 24),
        radius: 12.0,
        controlRadius: 10.0
    )
}
