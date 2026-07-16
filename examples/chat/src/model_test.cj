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
func seedBuildsAGroupTimelineWithSeparators(): Unit {
    let model = ChatModel()
    let messages = model.messages.value
    // 首条恒有时间分隔条锚定时间线；周期性拉开的间隔再触发若干条。
    @Expect(messages[0].showsTime)
    var separators = 0
    for (m in messages) {
        if (m.showsTime) {
            separators += 1
        }
    }
    @Expect(separators > 1)
    // 时间线单调不减，三名成员都出场。
    for (i in 1..messages.size) {
        @Expect(messages[i].minuteOfDay >= messages[i - 1].minuteOfDay)
    }
    @Expect(model.memberCount(), 3)
}

@Test
func estimateLinesGrowsWithLengthAndClamps(): Unit {
    @Expect(estimateLines("短"), 1)
    @Expect(estimateLines(""), 1) // 空串仍占一行
    // 每行 20 字：20 字为 1 行、21 字为 2 行。
    @Expect(estimateLines("一二三四五六七八九十一二三四五六七八九十"), 1)
    @Expect(estimateLines("一二三四五六七八九十一二三四五六七八九十一"), 2)
    // 超长文本钳制在 MAX_LINES。
    var long = ""
    for (_ in 0..500) {
        long = "${long}字"
    }
    @Expect(estimateLines(long), MAX_LINES)
}

@Test
func messageHeightCountsEachOptionalSegment(): Unit {
    let mineShort = Message(1, MY_SENDER, "短", true, 540, false)
    let mineTwoLines = Message(2, MY_SENDER, "一二三四五六七八九十一二三四五六七八九十三四五", true, 540, false)
    @Expect(mineShort.lines, 1)
    @Expect(mineTwoLines.lines, 2)
    // 单行正文套用 Label 单行最小高（28），两行按每行预算累加（2×24）。
    @Expect(mineShort.height, BUBBLE_MIN_TEXT_H + BUBBLE_PAD * 2.0 + ROW_GAP)
    @Expect(mineTwoLines.height - mineShort.height, TEXT_LINE_H * 2.0 - BUBBLE_MIN_TEXT_H)
    // 他人消息在气泡外多一行名字。
    let other = Message(3, "Ada", "短", false, 540, false)
    @Expect(other.height - mineShort.height, NAME_H)
    // 时间分隔条计入该条高度。
    let separated = Message(4, MY_SENDER, "短", true, 560, true)
    @Expect(separated.height - mineShort.height, TIME_SEP_H)
}

@Test
func clockAndSeparatorHelpers(): Unit {
    @Expect(formatClock(9 * 60 + 5), "09:05")
    @Expect(formatClock(0), "00:00")
    @Expect(formatClock(23 * 60 + 59), "23:59")
    @Expect(needsTimeSeparator(540, 540 + TIME_SEP_GAP_MIN))
    @Expect(!needsTimeSeparator(540, 540 + TIME_SEP_GAP_MIN - 1))
}

@Test
func sendAppendsMyMessageAndScrollsToBottom(): Unit {
    let model = ChatModel()
    let before = model.messages.value.size
    let lastMinute = model.messages.value[before - 1].minuteOfDay
    model.draft.value = "  这是一条新消息  "
    model.send()
    @Expect(model.messages.value.size, before + 1)
    let last = model.messages.value[model.messages.value.size - 1]
    @Expect(last.mine)
    @Expect(last.text, "这是一条新消息") // 已去除首尾空白
    @Expect(last.minuteOfDay, lastMinute + 1) // 记在上一条的下一分钟
    @Expect(!last.showsTime) // 间隔不足，不插时间分隔条
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
