/*
 * 聊天数据：不定长消息与其预估高度。
 *
 * 变高虚拟列表要求每条消息给出 O(1) 的高度，且要与其真正绘制的高度吻合。这里按字符数估算气泡行数，
 * 再由行数与固定的行高、内边距算出整行高度；消息构造时一次算好并存下，`LazyList` 据此累加偏移、
 * 二分定位可见窗口，故长短不一的气泡也只渲染视口附近。渲染时正文用 `maxLines(lines)` 封顶，保证不超高。
 */
package cui_chat

import std.collection.ArrayList

let CHARS_PER_LINE: Int64 = 18 // 气泡一行约容纳的字符数（按气泡宽度调校）
let MAX_LINES: Int64 = 8
// 高度预算取偏宽松，配合正文 maxLines(lines) 封顶，保证估算恒不小于实绘，绝不超高裁切。
let SENDER_H: Float32 = 22.0 // 发送者名一行
let TEXT_LINE_H: Float32 = 24.0 // 正文行高
let BUBBLE_PAD: Float32 = 10.0 // 气泡内上下留白（各一份）
let ROW_GAP: Float32 = 12.0 // 相邻气泡之间的行距

struct Message {
    let id: Int64
    let sender: String
    let text: String
    let mine: Bool
    let lines: Int64
    let height: Float32

    init(id: Int64, sender: String, text: String, mine: Bool) {
        this.id = id
        this.sender = sender
        this.text = text
        this.mine = mine
        this.lines = estimateLines(text)
        this.height = SENDER_H + Float32(this.lines) * TEXT_LINE_H + BUBBLE_PAD * 2.0 + ROW_GAP
    }
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

private let SAMPLE_TEXTS: Array<String> = [
    "在吗？",
    "在的，刚看完你发的组件清单。",
    "这一轮我把变高虚拟列表做完了：聊天这种气泡长短不一的场景，现在也能只渲染视口附近的十几条，往上翻几百条历史消息依旧很稳。",
    "赞，性能这块一直是重点。",
    "对，关键是每条消息的高度要预先算好、且和实际绘制吻合，列表才能靠累加偏移和二分快速定位可见窗口，而不用把每条都量一遍。",
    "明白了，那长文本怎么处理？",
    "长文本按估算的行数封顶，超出用省略号，既不超高也不塌陷。",
    "好，那我们把这条也记进文档。",
    "已经写进示例说明了。",
    "顺便说一下，昨天那个分栏和树的组合，用起来手感很好，导航加详情一步到位。",
    "嗯，组件之间能自然组合，是这套框架最舒服的地方。",
    "下一轮打算补什么？",
    "在富文本和时间选择器之间挑一个，富文本受限于渲染层没有粗斜体，可能先做多色和内联图标那版。",
    "可以，稳步推进。",
    "收到，我先把这一轮的测试和示例都补齐，晚点同步。"
]

private let OTHER_SENDER = "Ada"
private let MY_SENDER = "我"

/** 由样例文案循环生成一段较长的对话，交替双方，制造长短不一的气泡以凸显变高虚拟化。 */
func seedMessages(): Array<Message> {
    let list = ArrayList<Message>()
    var id: Int64 = 1
    var round = 0
    while (list.size < 240) {
        let text = SAMPLE_TEXTS[round % SAMPLE_TEXTS.size]
        let mine = round % 2 == 1
        let sender = if (mine) {
            MY_SENDER
        } else {
            OTHER_SENDER
        }
        list.add(Message(id, sender, text, mine))
        id += 1
        round += 1
    }
    list.toArray()
}
