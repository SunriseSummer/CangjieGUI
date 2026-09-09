/*
 * 发布说明示例的静态数据与纯映射。
 *
 * 每条说明携带类别、主题词、描述与可选的内联代码片段、弃用旧写法、尾句、议题号；
 * 视图据非空与否决定拼装哪些富文本片段。类别的名称/颜色/图标映射是纯函数，便于单测。
 */
package cui_richtext

import cui.{Color, IconSource}

// 类别下标：0 新增、1 修复、2 性能、3 弃用。
let CATEGORY_NAMES: Array<String> = ["新增", "修复", "性能", "弃用"]
let FILTER_LABELS: Array<String> = ["全部", "新增", "修复", "性能", "弃用"]

// 一条发布说明。可选字段为空串表示该片段不出现。
struct ReleaseNote {
    let category: Int64
    let subject: String
    let desc: String
    let code: String
    let tail: String
    let oldApi: String
    let issue: String

    init(
        category: Int64,
        subject: String,
        desc: String,
        code!: String = "",
        tail!: String = "",
        oldApi!: String = "",
        issue!: String = ""
    ) {
        this.category = category
        this.subject = subject
        this.desc = desc
        this.code = code
        this.tail = tail
        this.oldApi = oldApi
        this.issue = issue
    }
}

// 一个版本区块：版本号、日期、是否最新、导语与若干条说明。
struct ReleaseSection {
    let version: String
    let date: String
    let latest: Bool
    let intro: String
    let notes: Array<ReleaseNote>

    init(version: String, date: String, latest: Bool, intro: String, notes: Array<ReleaseNote>) {
        this.version = version
        this.date = date
        this.latest = latest
        this.intro = intro
        this.notes = notes
    }
}

let RELEASES: Array<ReleaseSection> = [
    ReleaseSection(
        "2.4",
        "2026-07-18",
        true,
        "本次聚焦文本渲染质量与自定义控件开放，末条附不兼容变更的迁移指引。",
        [
            ReleaseNote(0, "真粗体字面", "粗体优先加载同族的粗体文件，CJK 标题边缘与常规字重同样平滑",
                code: "msyhbd.ttc", issue: "#4821"),
            ReleaseNote(0, "自定义控件三件套", "应用层控件可进入 Tab 焦点序并绘制标准焦点环",
                code: "focusableControlIdentity", issue: "#4796"),
            ReleaseNote(2, "长文换行提速", "两万字文档的逐帧换行从秒级降至毫秒级", code: "maxRunesFitting",
                tail: "换用 gallop 定界", issue: "#4810"),
            ReleaseNote(3, "主题位置参数", "主题构造的位置参数不再受支持", code: "Theme(bg: …)",
                oldApi: "Theme(bg, panel, …)")
        ]
    ),
    ReleaseSection(
        "2.3",
        "2026-07-16",
        false,
        "组件完备性收官版本，六十余个控件覆盖桌面常见场景。",
        [
            ReleaseNote(0, "环形进度", "线性进度条的圆形对应物，弧线随占比生长", code: "ProgressRing", issue: "#4655"),
            ReleaseNote(1, "阴影裁剪断口", "滚动容器在交叉轴放宽裁剪，卡片光晕不再被切出硬边", issue: "#4702"),
            ReleaseNote(1, "滚动条拖拽跳位", "抓取偏移随拖拽标识存放，真机拖动第二帧不再跳变", issue: "#4718"),
            ReleaseNote(2, "几何网格缓存", "圆角矩形与软阴影复用成形网格，内容页绘树成本约降九成", code: "GeometryBatch")
        ]
    )
]

// 类别 → 展示名（越界给「其他」，数据错误可见而不崩溃）。
func categoryName(category: Int64): String {
    if (category >= 0 && category < CATEGORY_NAMES.size) {
        CATEGORY_NAMES[category]
    } else {
        "其他"
    }
}

// 类别 → 主色（标签文字与行首图标共用）。
func categoryColor(category: Int64): Color {
    match (category) {
        case 0 => Color.rgb(32, 138, 84) // 新增（绿）
        case 1 => Color.rgb(56, 118, 214) // 修复（蓝）
        case 2 => Color.rgb(182, 126, 28) // 性能（琥珀）
        case _ => Color.rgb(196, 72, 60) // 弃用（红）
    }
}

// 类别 → 标签底色（highlight 用的柔和色）。
func categorySoft(category: Int64): Color {
    match (category) {
        case 0 => Color.rgb(224, 242, 232)
        case 1 => Color.rgb(226, 236, 252)
        case 2 => Color.rgb(248, 238, 216)
        case _ => Color.rgb(250, 228, 224)
    }
}

// 类别 → 行首图标。
func categoryIcon(category: Int64): IconSource {
    match (category) {
        case 0 => IconSource("assets/icons/document.svg")
        case 1 => IconSource("assets/icons/brush.svg")
        case 2 => IconSource("assets/icons/process.svg")
        case _ => IconSource("assets/icons/trash.svg")
    }
}

// 过滤匹配：0 为全部，其后依次对应各类别。
func matchesFilter(note: ReleaseNote, filter: Int64): Bool {
    filter == 0 || note.category == filter - 1
}
