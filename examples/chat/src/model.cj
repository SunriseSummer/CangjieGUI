/*
 * 聊天状态：消息列表、输入草稿与滚动偏移。
 *
 * 消息用整表替换触发更新；发送时追加一条“我”的消息并把滚动置到底部（`LazyList` 会把超出的偏移钳到底），
 * 于是最新消息始终可见——这也是聊天的惯例。滚动偏移由模型持有，故可初始化到底部。
 */
package cui_chat

import std.collection.{ArrayList, HashSet}
import cui.State

class ChatModel {
    let messages: State<Array<Message>>
    let draft = State<String>("")
    let scroll: State<Float32>
    private var nextId: Int64

    init() {
        let seeded = seedMessages()
        this.messages = State<Array<Message>>(seeded)
        // 一个足够大的偏移，首帧布局会把它钳到底部，于是打开即停在最新消息。
        this.scroll = State<Float32>(totalHeight(seeded))
        this.nextId = Int64(seeded.size) + 1
    }

    /** 群成员数（按出现过的发送者去重），抬头副标题用。 */
    func memberCount(): Int64 {
        let names = HashSet<String>()
        for (message in messages.value) {
            names.add(message.sender)
        }
        names.size
    }

    /** 发送草稿：非空则追加一条“我”的消息，清空输入并滚到底部。 */
    func send(): Unit {
        let text = draft.value.trimAscii()
        if (text.isEmpty()) {
            return
        }
        let arr = messages.value
        let appended = ArrayList<Message>()
        for (message in arr) {
            appended.add(message)
        }
        // 演示数据无真实时钟：新消息记在最后一条的下一分钟，间隔不足不会触发时间分隔条。
        let minute = if (arr.size > 0) {
            arr[arr.size - 1].minuteOfDay + 1
        } else {
            9 * 60
        }
        let prevMinute = if (arr.size > 0) {
            arr[arr.size - 1].minuteOfDay
        } else {
            -TIME_SEP_GAP_MIN
        }
        appended.add(Message(nextId, MY_SENDER, text, true, minute, needsTimeSeparator(prevMinute, minute)))
        nextId += 1
        messages.value = appended.toArray()
        draft.value = ""
        scroll.value = totalHeight(messages.value)
    }
}
