/*
 * 聊天视图层：抬头 + 消息区（变高气泡）+ 输入栏。
 *
 *  - 消息区是 `LazyList`：每条气泡按预估高度定位，只渲染视口附近的十几条；上翻几百条历史依旧一屏成本。
 *  - 气泡左右分列（我方右、蓝底白字；对方左、白底深字），正文用 `maxLines(lines)` 封顶以吻合预估高度。
 *  - 输入栏发送后追加消息并滚到底部（`LazyList` 会把超出偏移钳到底），最新消息始终可见。
 */
package cui_chat

import cui.{Button, ButtonRole, Color, CrossAxisAlignment, FontSizes, HStack, Label, LazyList, LengthUnits, Panel,
    Spacer, TextField, VStack}

func chatView(model: ChatModel): Unit {
    VStack {
        appHeader(model)
        messagesPanel(model)
        inputBar(model)
    }.spacing(10.vp).padding(14.vp)
}

func appHeader(model: ChatModel): Unit {
    VStack {
        Label("项目群聊").fontSize(FontSizes.TITLE)
        Label("变高虚拟列表：${model.messages.value.size} 条消息，只渲染视口附近；上翻历史很稳").muted()
            .fontSize(FontSizes.CAPTION)
    }.spacing(2.vp).hug()
}

func messagesPanel(model: ChatModel): Unit {
    Panel {
        LazyList.of(model.messages.value, {m => m.height}, key: {m => "msg${m.id}"}, scroll: Some(model.scroll)) {
            m => messageRow(m)
        }
    }.contentPadding(6.vp).flex()
}

func messageRow(message: Message): Unit {
    HStack {
        if (message.mine) {
            Spacer()
        }
        bubble(message)
        if (!message.mine) {
            Spacer()
        }
    }.crossAxisAlignment(CrossAxisAlignment.Start).padding(4.0, ROW_GAP / 2.0, 4.0, ROW_GAP / 2.0)
}

func bubble(message: Message): Unit {
    VStack {
        Label(message.sender).fontSize(FontSizes.CAPTION).foregroundColor(subColor(message.mine))
        Label(message.text).maxLines(message.lines).foregroundColor(textColor(message.mine))
    }.spacing(3.vp).hug().padding(BUBBLE_PAD).background(bubbleColor(message.mine), 12.vp).maxWidth(340.vp)
}

func inputBar(model: ChatModel): Unit {
    HStack {
        TextField(model.draft).flex()
        Button("发送", {=> model.send()}).role(ButtonRole.Primary)
    }.spacing(8.vp).crossAxisAlignment(CrossAxisAlignment.Center).hug()
}

func bubbleColor(mine: Bool): Color {
    if (mine) {
        CHAT_MINE_BG
    } else {
        CHAT_OTHER_BG
    }
}

func textColor(mine: Bool): Color {
    if (mine) {
        CHAT_MINE_TEXT
    } else {
        CHAT_OTHER_TEXT
    }
}

func subColor(mine: Bool): Color {
    if (mine) {
        CHAT_MINE_SUB
    } else {
        CHAT_OTHER_SUB
    }
}
