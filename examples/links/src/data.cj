/*
 * 链接示例的类型化数据。
 *
 * 每条通知由若干片段拼成，其中 isLink 的片段是可点击链接；点击它会把该片段文本设为“已选择”。数据不可变。
 */
package cui_links

import cui.{Color, IconSource}

// 通知行的一个片段：文本 + 是否为链接。
struct Segment {
    let text: String
    let isLink: Bool

    init(text: String, isLink!: Bool = false) {
        this.text = text
        this.isLink = isLink
    }
}

// 一条通知：图标、图标色、若干片段。
struct Notice {
    let icon: IconSource
    let iconColor: Color
    let segments: Array<Segment>

    init(icon: IconSource, iconColor: Color, segments: Array<Segment>) {
        this.icon = icon
        this.iconColor = iconColor
        this.segments = segments
    }
}

let ICON_ADDED = Color.rgb(52, 199, 120)
let ICON_FIXED = Color.rgb(230, 168, 70)
let ICON_UPDATED = Color.rgb(96, 165, 250)
let NOTICES: Array<Notice> = [
    Notice(
        IconSource("assets/icons/document.svg"),
        ICON_ADDED,
        [Segment("Ada", isLink: true), Segment(" 新建了 "), Segment("report.md", isLink: true), Segment(" 并 @了 "),
            Segment("你", isLink: true)]
    ),
    Notice(
        IconSource("assets/icons/brush.svg"),
        ICON_FIXED,
        [Segment("小满", isLink: true), Segment(" 修复了 "), Segment("#登录崩溃", isLink: true), Segment(" 请 "),
            Segment("周珩", isLink: true), Segment(" 复审")]
    ),
    Notice(
        IconSource("assets/icons/refresh.svg"),
        ICON_UPDATED,
        [Segment("周珩", isLink: true), Segment(" 更新了 "), Segment("设计规范", isLink: true), Segment(" 到 "),
            Segment("v3", isLink: true)]
    ),
    Notice(
        IconSource("assets/icons/save.svg"),
        ICON_UPDATED,
        [Segment("Ada", isLink: true), Segment(" 在 "), Segment("#发布计划", isLink: true), Segment(" 里提到了 "),
            Segment("里程碑 M2", isLink: true)]
    ),
    Notice(
        IconSource("assets/icons/copy.svg"),
        ICON_ADDED,
        [Segment("小满", isLink: true), Segment(" 复制了 "), Segment("模板/周报.md", isLink: true), Segment(" 到 "),
            Segment("团队空间", isLink: true)]
    )
]

// 全部通知里的链接片段总数（用于测试与提示）。
func linkCount(notices: Array<Notice>): Int64 {
    var total: Int64 = 0
    for (notice in notices) {
        for (segment in notice.segments) {
            if (segment.isLink) {
                total += 1
            }
        }
    }
    total
}
