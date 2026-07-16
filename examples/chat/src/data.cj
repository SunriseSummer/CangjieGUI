/*
 * 聊天数据：群聊消息、时间线与逐条预估高度。
 *
 * 变高虚拟列表要求每条消息给出 O(1) 的高度，且要与其真正绘制的高度吻合。这里按字符数估算气泡行数，
 * 再叠加各可选段（时间分隔条、他人消息的名字行）与固定的行高、内边距得到整行高度；消息构造时一次算好
 * 并存下，`LazyList` 据此累加偏移、二分定位可见窗口，故长短不一的气泡也只渲染视口附近。渲染时正文用
 * `maxLines(lines)` 封顶，保证不超高。
 *
 * 仿主流聊天软件：消息带时刻（自午夜起的分钟数），与上一条间隔到达 `TIME_SEP_GAP_MIN` 时在该条上方
 * 插入居中的时间分隔条；他人消息在气泡外上方显示发送者名，自己的消息不显示名字。
 */
package cui_chat

import std.collection.ArrayList

// 气泡一行约容纳的字符数：实测正文区宽 320px、全角字符宽 15px 约容 21 字，取 20 保守——估算行数
// 恒不小于实绘行数（半角字符更窄，只会多容），且与实际尽量贴近以免行距忽大忽小。
let CHARS_PER_LINE: Int64 = 20
let MAX_LINES: Int64 = 8
// 高度预算按各段的实绘下限取值（Label 实测：BODY 行高 20 + 行间 2、首行另含 6 内衬且单行最小高 28；
// CAPTION 单行最小高同为 28），配合正文 maxLines(lines) 封顶，保证估算恒不小于实绘，绝不超高裁切。
let NAME_H: Float32 = 32.0 // 他人消息的名字行：CAPTION 单行最小高 28 + 名字与气泡间距 4
let TEXT_LINE_H: Float32 = 24.0 // 正文每行预算：行高 20 + 行间 2，余量吸收首行 6px 内衬（24c ≥ 22c+4，c ≥ 2）
let BUBBLE_MIN_TEXT_H: Float32 = 28.0 // 正文块最小高：Label 单行取 max(28, 行高+6) = 28
let BUBBLE_PAD: Float32 = 10.0 // 气泡内上下留白（各一份）
let ROW_GAP: Float32 = 12.0 // 相邻气泡之间的行距
let TIME_SEP_H: Float32 = 28.0 // 居中时间分隔条整行高度（22 内容 + 6 下间距；消息行栈 spacing 为 0）
let TIME_SEP_GAP_MIN: Int64 = 10 // 与上一条间隔达到该分钟数时显示时间分隔条

struct Message {
    let id: Int64
    let sender: String
    let text: String
    let mine: Bool
    let minuteOfDay: Int64
    let showsTime: Bool
    let lines: Int64
    let height: Float32

    init(id: Int64, sender: String, text: String, mine: Bool, minuteOfDay: Int64, showsTime: Bool) {
        this.id = id
        this.sender = sender
        this.text = text
        this.mine = mine
        this.minuteOfDay = minuteOfDay
        this.showsTime = showsTime
        this.lines = estimateLines(text)
        let nameH: Float32 = if (mine) {
            0.0
        } else {
            NAME_H
        }
        let sepH: Float32 = if (showsTime) {
            TIME_SEP_H
        } else {
            0.0
        }
        // 正文块套用 Label 的单行最小高（短句气泡实绘 28 而非 24），多行按每行预算累加。
        let textBlock = max(BUBBLE_MIN_TEXT_H, Float32(this.lines) * TEXT_LINE_H)
        this.height = sepH + nameH + textBlock + BUBBLE_PAD * 2.0 + ROW_GAP
    }

    /** 该消息的时刻文案，如 09:05。 */
    func clock(): String {
        formatClock(minuteOfDay)
    }
}

/** 自午夜起的分钟数格式化为 HH:MM。 */
func formatClock(minutes: Int64): String {
    let h = (minutes / 60) % 24
    let m = minutes % 60
    "${padClock(h)}:${padClock(m)}"
}

private func padClock(value: Int64): String {
    if (value < 10) {
        "0${value}"
    } else {
        "${value}"
    }
}

/** 与上一条消息的间隔达到阈值时插入时间分隔条（首条恒插入——prev 传入极小值）。 */
func needsTimeSeparator(prevMinute: Int64, minute: Int64): Bool {
    minute - prevMinute >= TIME_SEP_GAP_MIN
}

/** 估算正文占用的行数（字符数向上取整到每行容量，钳到 [1, MAX_LINES]）。 */
func estimateLines(text: String): Int64 {
    let runes = text.toRuneArray().size
    let raw = (runes + CHARS_PER_LINE - 1) / CHARS_PER_LINE
    if (raw < 1) {
        1
    } else if (raw > MAX_LINES) {
        MAX_LINES
    } else {
        raw
    }
}

/** 一组消息的总高度——聊天初始滚到底部时用。 */
func totalHeight(messages: Array<Message>): Float32 {
    var sum: Float32 = 0.0
    for (message in messages) {
        sum += message.height
    }
    sum
}

let MY_SENDER = "我"

// 群聊脚本：按 (发送者, 文案) 顺序循环铺满对话，三人交替、长短不一，凸显变高虚拟化。
private let SCRIPT: Array<(String, String)> = [
    ("Ada", "早，昨天那版组件清单我看完了。"),
    ("我", "有什么要调整的吗?"),
    ("Ada", "整体没问题，聊天这个示例建议按主流社交软件的样式重排：头像、名字放气泡外面，加时间分隔条。"),
    ("小舟", "赞成，输入栏也建议贴底，回车直接发送。"),
    ("我", "收到，我今天改。变高虚拟列表这块不动：每条气泡按预估高度定位，只渲染视口附近的十几条，上翻几百条历史依旧一屏成本。"),
    ("Ada", "对，关键是每条消息的高度要预先算好、且和实际绘制吻合，列表才能靠累加偏移和二分快速定位可见窗口。"),
    ("小舟", "长文本怎么处理?"),
    ("我", "按估算的行数封顶，超出用省略号，既不超高也不塌陷。"),
    ("Ada", "时间分隔条也要算进行高，不然上翻时会跳。"),
    ("我", "嗯，分隔条、名字行都叠进每条的预估高度里，虚拟化照常工作。"),
    ("小舟", "顺便说一下，昨天那个分栏和树的组合用起来手感很好，导航加详情一步到位。"),
    ("Ada", "组件之间能自然组合，是这套框架最舒服的地方。"),
    ("我", "下一轮在富文本和时间选择器之间挑一个先做。"),
    ("小舟", "可以，稳步推进。"),
    ("我", "收到，我先把这一轮的测试和示例都补齐，晚点同步。")
]

/**
 * 由群聊脚本循环生成一段较长的对话。时间线从 09:02 开始、逐条前进 0–2 分钟，每逢第 8 条跳 26 分钟，
 * 从而周期性触发时间分隔条；全部确定性生成，快照稳定。
 */
func seedMessages(): Array<Message> {
    let list = ArrayList<Message>()
    var id: Int64 = 1
    var round = 0
    var minute: Int64 = 9 * 60 + 2
    var prevMinute: Int64 = -TIME_SEP_GAP_MIN // 首条恒显示时间分隔条
    while (list.size < 240) {
        let (sender, text) = SCRIPT[round % SCRIPT.size]
        list.add(Message(id, sender, text, sender == MY_SENDER, minute, needsTimeSeparator(prevMinute, minute)))
        prevMinute = minute
        minute += round % 3 // 逐条前进 0–2 分钟
        if (round % 8 == 7) {
            minute += 26 // 周期性拉开间隔，触发下一条的时间分隔条
        }
        id += 1
        round += 1
    }
    list.toArray()
}
