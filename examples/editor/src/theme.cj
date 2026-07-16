/*
 * 编辑器主题：清爽的浅灰底 + 靛蓝强调色，菜单栏与选中项一致。令牌集中于此。
 */
package cui_editor

import cui.{Color, Theme}

func editorTheme(): Theme {
    Theme(
        Color.rgb(238, 240, 244), // bg
        Color.rgb(255, 255, 255), // panel
        Color.rgb(220, 224, 232), // panelEdge
        Color.rgb(30, 34, 42), // text
        Color.rgb(112, 120, 134), // mutedText
        Color.rgb(66, 104, 210), // accent
        Color.rgb(255, 255, 255), // accentText
        Color.rgb(206, 74, 68), // danger
        Color.rgb(248, 249, 251), // field
        Color.rgb(236, 240, 250), // fieldActive
        panelRaised: Color.rgb(255, 255, 255),
        accentSoft: Color.rgb(224, 232, 250),
        shadow: Color.rgba(28, 38, 66, 26),
        radius: 12.0,
        controlRadius: 8.0
    )
}
