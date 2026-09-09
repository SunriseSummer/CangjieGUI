/*
 * 笔记主题：清爽的浅色纸面配色，令牌集中于此。
 */
package cui_notes

import cui.{Color, SurfaceStyle, Theme}

/** 新建操作、选中笔记与页头图标共用的强调色。 */
let NOTES_ACCENT = Color.rgb(157, 103, 40)

func notesCard(): SurfaceStyle {
    SurfaceStyle(Color.rgb(255, 255, 255), border: Color.rgb(230, 224, 214), borderWidth: 1.0, radius: 14.0)
}

func notesPaper(): SurfaceStyle {
    SurfaceStyle(Color.rgb(255, 255, 255), borderWidth: 0.0)
}

func notesTheme(): Theme {
    Theme(
        bg: Color.rgb(244, 243, 239),
        panel: Color.rgb(255, 255, 255),
        panelEdge: Color.rgb(224, 220, 210),
        text: Color.rgb(38, 34, 28),
        mutedText: Color.rgb(124, 116, 102),
        accent: NOTES_ACCENT,
        accentText: Color.rgb(255, 255, 255),
        danger: Color.rgb(198, 74, 66),
        field: Color.rgb(250, 249, 246),
        fieldActive: Color.rgb(248, 240, 228),
        panelRaised: Color.rgb(255, 255, 255),
        accentSoft: Color.rgb(248, 236, 218),
        shadow: Color.rgba(60, 48, 30, 0),
        radius: 14.0,
        controlRadius: 6.0,
        borderWidth: 0.0
    )
}
