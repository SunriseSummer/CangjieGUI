/*
 * 目录主题：清爽浅色 + 蓝色强调，另附每个分类的色签色。令牌集中于此。
 */
package cui_catalog

import cui.{Color, Theme}

// 价格文字色，卡片直接引用。
let CATALOG_PRICE: Color = Color.rgb(210, 96, 58)

func catalogTheme(): Theme {
    Theme(
        Color.rgb(243, 244, 248), // bg
        Color.rgb(255, 255, 255), // panel
        Color.rgb(224, 227, 234), // panelEdge
        Color.rgb(32, 36, 46), // text
        Color.rgb(120, 126, 140), // mutedText
        Color.rgb(64, 108, 220), // accent
        Color.rgb(255, 255, 255), // accentText
        Color.rgb(206, 74, 68), // danger
        Color.rgb(247, 249, 252), // field
        Color.rgb(236, 240, 249), // fieldActive
        panelRaised: Color.rgb(252, 253, 255),
        accentSoft: Color.rgb(224, 231, 250),
        shadow: Color.rgba(30, 38, 66, 22),
        radius: 12.0,
        controlRadius: 9.0
    )
}

// 分类色签色：给每张卡片一道分类色条，快速区分品类。
func categoryColor(cat: Int64): Color {
    match (cat) {
        case 0 => Color.rgb(79, 122, 232) // 电子
        case 1 => Color.rgb(232, 148, 61) // 家居
        case 2 => Color.rgb(214, 90, 132) // 服饰
        case 3 => Color.rgb(72, 168, 116) // 图书
        case _ => Color.rgb(150, 108, 220) // 运动
    }
}
