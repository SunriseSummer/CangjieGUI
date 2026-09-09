/*
 * 骨架屏示例的类型化数据与纯造型逻辑。
 *
 * 文章数据供「加载完成」态展示；占位条的宽度比例由行号决定（长短交错更像真实文字），为纯函数可测。
 */
package cui_skeleton

import cui.{Color, IconSource}

// 一篇文章：图标、图标色、标题、摘要。
struct Article {
    let icon: IconSource
    let iconColor: Color
    let title: String
    let summary: String

    init(icon: IconSource, iconColor: Color, title: String, summary: String) {
        this.icon = icon
        this.iconColor = iconColor
        this.title = title
        this.summary = summary
    }
}

let ARTICLES: Array<Article> = [
    Article(IconSource("assets/icons/document.svg"), Color.rgb(52, 168, 120), "声明式界面的即时模式实现",
        "每帧重建控件树，用缓存与脏帧跳过压住成本"),
    Article(IconSource("assets/icons/brush.svg"), Color.rgb(230, 158, 60), "多重阴影与深度感",
        "环境光叠方向光，深度来自两层之差"),
    Article(IconSource("assets/icons/refresh.svg"), Color.rgb(96, 150, 250), "交错入场的时序数学",
        "第 i 行只比上一行多等一个步进"),
    Article(IconSource("assets/icons/save.svg"), Color.rgb(150, 110, 220), "本地字体的加载与回退",
        "打不开就退回系统字体，中途拔盘也不崩")
]

// 骨架行数与文章数一致，切换前后高度不跳。
func skeletonRows(): Int64 {
    ARTICLES.size
}

// 标题占位条的宽度比例：偶数行长、奇数行短，模拟真实标题的参差。
func titleFraction(row: Int64): Float32 {
    if (row % 2 == 0) {
        0.62
    } else {
        0.46
    }
}

// 摘要占位条的宽度比例：与标题错开，整体长于标题。
func lineFraction(row: Int64): Float32 {
    if (row % 2 == 0) {
        0.88
    } else {
        0.74
    }
}
