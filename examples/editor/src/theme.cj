/*
 * 编辑器主题：清爽的浅灰底 + 靛蓝强调色，菜单栏与选中项一致。令牌集中于此。
 */
package cui_editor

import cui.{Color, SurfaceStyle, Theme}

let EDITOR_ACCENT = Color.rgb(78, 92, 166)

func editorCard(): SurfaceStyle {
    SurfaceStyle(Color.rgb(255, 255, 255), border: Color.rgb(226, 230, 239), borderWidth: 1.0, radius: 14.0,
        shadow: Color.rgba(32, 44, 70, 12), shadowOffsetY: 2.0)
}

func editorPaper(): SurfaceStyle {
    SurfaceStyle(Color.rgb(255, 255, 255), borderWidth: 0.0)
}

func editorTheme(): Theme {
    Theme(
        bg: Color.rgb(245, 246, 250),
        panel: Color.rgb(255, 255, 255),
        panelEdge: Color.rgb(220, 224, 232),
        text: Color.rgb(30, 34, 42),
        mutedText: Color.rgb(112, 120, 134),
        accent: EDITOR_ACCENT,
        accentText: Color.rgb(255, 255, 255),
        danger: Color.rgb(206, 74, 68),
        field: Color.rgb(230, 233, 242),
        fieldActive: Color.rgb(236, 240, 250),
        panelRaised: Color.rgb(255, 255, 255),
        accentSoft: Color.rgb(224, 232, 250),
        shadow: Color.rgba(0, 0, 0, 0),
        radius: 12.0,
        smallRadius: 3.0,
        controlRadius: 6.0,
        borderWidth: 0.0
    )
}
