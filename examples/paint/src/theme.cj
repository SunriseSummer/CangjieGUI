/*
 * 画板的草木绿主题与画笔调色板。
 */
package cui_paint

import cui.{Color, LengthUnits, SurfaceStyle, Theme}

let PAINT_TITLE = 22.fp
let PAINT_COMMAND = 12.fp
let PAINT_CAPTION = 11.fp
let PAINT_ICON = 24.vp
let PAINT_GAP = 12.vp
let PAINT_SLIDER_WIDTH = 110.vp
let PAINT_SIZE_WIDTH = 84.vp

struct PaintColor {
    let name: String
    let color: Color
    init(name: String, color: Color) {
        this.name = name
        this.color = color
    }
}

func paintCard(): SurfaceStyle {
    SurfaceStyle(Color.rgb(255, 255, 255), border: Color.rgb(220, 229, 221), borderWidth: 1.0, radius: 14.0)
}

/** 可选画笔颜色，从冷到暖排列，方便在色板上一眼定位。 */
let PALETTE = [
    PaintColor("藏蓝", Color.rgb(38, 70, 104)),
    PaintColor("品蓝", Color.rgb(41, 121, 209)),
    PaintColor("草绿", Color.rgb(34, 160, 100)),
    PaintColor("琥珀", Color.rgb(238, 160, 38)),
    PaintColor("珊瑚", Color.rgb(224, 76, 76)),
    PaintColor("藤紫", Color.rgb(146, 84, 201))
]

/** 初始画笔颜色：调色板中的品蓝，在白色画布上辨识度最高。 */
let DEFAULT_BRUSH_COLOR = PALETTE[1].color

/** 空画布提示文字的灰绿色：贴近主题底色，暗示这是提示而非已落笔内容。 */
let CANVAS_HINT_COLOR = Color.rgb(120, 142, 124)

func paintTheme(): Theme {
    Theme(
        bg: Color.rgb(241, 246, 242),
        panel: Color.rgb(255, 255, 255),
        panelEdge: Color.rgb(202, 218, 203),
        text: Color.rgb(25, 36, 27),
        mutedText: Color.rgb(94, 111, 95),
        accent: Color.rgb(28, 132, 84),
        accentText: Color.rgb(255, 255, 255),
        danger: Color.rgb(198, 65, 72),
        field: Color.rgb(251, 253, 250),
        fieldActive: Color.rgb(230, 247, 237),
        panelRaised: Color.rgb(255, 255, 255),
        accentSoft: Color.rgb(212, 242, 225),
        shadow: Color.rgba(0, 0, 0, 0),
        radius: 16.0,
        controlRadius: 6.0,
        borderWidth: 0.0
    )
}
