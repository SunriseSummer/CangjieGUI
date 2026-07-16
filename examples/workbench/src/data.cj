/*
 * 工作台数据与纯函数辅助。
 *
 * 文档是不可变值，更新通过整表替换触发状态通知（与笔记、看板示例一致）。正文按 Markdown 风格
 * 书写，以 `#` 开头的行视为小节标题；大纲与统计都由正文实时派生，因此编辑即刻反映到右下信息面板。
 */
package cui_workbench

import std.collection.ArrayList

// '#' 的字节值，用于逐字节剥离标题行的前缀（ASCII 边界安全，正文中文部分不受影响）。
let HASH_BYTE: UInt8 = UInt8(35)

struct Doc {
    let id: Int64
    let body: String

    init(id: Int64, body: String) {
        this.id = id
        this.body = body
    }
}

/** 大纲条目：标题层级（`#` 的个数）与标题文本。 */
struct Heading {
    let level: Int64
    let text: String

    init(level: Int64, text: String) {
        this.level = level
        this.text = text
    }
}

func seedDocs(): Array<Doc> {
    [
        Doc(
            1,
            "# 产品路线图\n把命令面板、主从编辑与惰性列表打磨成一流体验。\n\n" +
            "## 本季度\n先做分栏工作台与变高虚拟列表。\n\n" +
            "## 下季度\n补齐无障碍树与增量重组。"
        ),
        Doc(
            2,
            "# 会议纪要\n讨论了分栏组件的手感：拖动阻尼、最小宽度与键盘可达性。\n\n" +
            "## 决议\n分隔条应可 Tab 聚焦，方向键微调。\n\n" +
            "## 待办\n补充嵌套分栏的示例与文档。"
        ),
        Doc(
            3,
            "# 写作灵感\n工作台左侧是文档列表，右侧上方编辑、下方看大纲与字数。\n\n" +
            "## 隐喻\n像 IDE：导航、编辑、检查三区各得其所，边界可自由分配。"
        ),
        Doc(4, "# 空白文档\n从这里开始书写……")
    ]
}

func clampDocIndex(index: Int64, count: Int64): Int64 {
    if (count <= 0) {
        0
    } else if (index < 0) {
        0
    } else if (index >= count) {
        count - 1
    } else {
        index
    }
}

/** 选中文档的正文，没有文档时为空串——供编辑器绑定使用。 */
func docBodyAt(docs: Array<Doc>, index: Int64): String {
    if (docs.isEmpty()) {
        ""
    } else {
        docs[clampDocIndex(index, docs.size)].body
    }
}

/** 返回将第 `index` 篇文档正文替换后的新文档表。 */
func withBodyAt(docs: Array<Doc>, index: Int64, body: String): Array<Doc> {
    if (docs.isEmpty()) {
        return docs
    }
    let target = clampDocIndex(index, docs.size)
    Array<Doc>(docs.size, {i => if (i == target) {
        Doc(docs[i].id, body)
    } else {
        docs[i]
    }})
}

/** 文档的侧栏标题：取第一条小节标题，没有则回退到正文首行或占位文本。 */
func docTitle(body: String): String {
    for (heading in outlineOf(body)) {
        return heading.text
    }
    // 空串在仓颉中 split 得到空数组，故先判空再取首行，避免越界。
    let lines = body.split("\n")
    if (lines.isEmpty() || lines[0].trimAscii().isEmpty()) {
        "无标题"
    } else {
        lines[0].trimAscii()
    }
}

/** 从正文提取所有 Markdown 小节标题，构成大纲。 */
func outlineOf(body: String): Array<Heading> {
    let result = ArrayList<Heading>()
    for (line in body.split("\n")) {
        match (headingOf(line)) {
            case Some(heading) => result.add(heading)
            case None => ()
        }
    }
    result.toArray()
}

/** 把一行解析为标题（若以 `#` 开头），否则为 None。 */
func headingOf(line: String): ?Heading {
    let trimmed = line.trimAscii()
    if (!trimmed.startsWith("#")) {
        return None
    }
    var level = 0
    while (level < trimmed.size && trimmed[level] == HASH_BYTE) {
        level += 1
    }
    // level 处于 ASCII '#' 之后的字节边界，切片对其后的中文正文安全。
    let text = trimmed[level..trimmed.size].trimAscii()
    if (text.isEmpty()) {
        None
    } else {
        Some(Heading(level, text))
    }
}

/** 正文统计串：行数、小节数与估算阅读时长（约 400 字/分钟）。 */
func statsText(body: String): String {
    let lines = if (body.isEmpty()) {
        0
    } else {
        body.split("\n").size
    }
    let chars = charCount(body)
    let sections = outlineOf(body).size
    let minutes = max(1, (chars + 399) / 400)
    "${lines} 行 · ${sections} 小节 · ${chars} 字 · 约 ${minutes} 分钟"
}

/** 正文字符数（Unicode 码点），不计换行与回车。 */
func charCount(body: String): Int64 {
    var count = 0
    for (rune in body.toRuneArray()) {
        if (rune != r'\n' && rune != r'\r') {
            count += 1
        }
    }
    count
}
