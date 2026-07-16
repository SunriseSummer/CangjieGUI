package cui_chat

@Test
func seedProducesAConversationWithVaryingHeights(): Unit {
    let model = ChatModel()
    let messages = model.messages.value
    @Expect(messages.size >= 240)
    // 高度随消息长度变化，虚拟列表需要各行高度不同才有意义。
    var distinct = false
    for (m in messages) {
        if (m.height != messages[0].height) {
            distinct = true
            break
        }
    }
    @Expect(distinct)
}

@Test
func estimateLinesGrowsWithLengthAndClamps(): Unit {
    @Expect(estimateLines("短"), 1)
    @Expect(estimateLines(""), 1) // 空串仍占一行
    // 每行 18 字：19 字为 2 行。
    @Expect(estimateLines("一二三四五六七八九十一二三四五六七八九"), 2)
    // 超长文本钳制在 MAX_LINES。
    var long = ""
    for (_ in 0..500) {
        long = "${long}字"
    }
    @Expect(estimateLines(long), MAX_LINES)
}

@Test
func messageHeightMatchesItsLineBudget(): Unit {
    let one = Message(1, "我", "短", true)
    let two = Message(2, "我", "一二三四五六七八九十一二三四五六七八九", true)
    @Expect(one.lines, 1)
    @Expect(two.lines, 2)
    // 每多一行恰好为该行预留高度增加一个 TEXT_LINE_H。
    @Expect(two.height - one.height, TEXT_LINE_H)
}

@Test
func sendAppendsMyMessageAndScrollsToBottom(): Unit {
    let model = ChatModel()
    let before = model.messages.value.size
    model.draft.value = "  这是一条新消息  "
    model.send()
    @Expect(model.messages.value.size, before + 1)
    let last = model.messages.value[model.messages.value.size - 1]
    @Expect(last.mine)
    @Expect(last.text, "这是一条新消息") // 已去除首尾空白
    @Expect(model.draft.value, "") // 已清空
    // 滚动跳到不小于内容总高度的位置，由布局钳制到底部。
    @Expect(model.scroll.value >= totalHeight(model.messages.value))
}

@Test
func sendIgnoresBlankDraft(): Unit {
    let model = ChatModel()
    let before = model.messages.value.size
    model.draft.value = "   "
    model.send()
    @Expect(model.messages.value.size, before) // 未追加任何消息
}
