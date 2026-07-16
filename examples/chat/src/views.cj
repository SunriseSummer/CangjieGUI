/*
 * 聊天视图层：仿主流社交软件的贴边三段布局——顶栏（群头像 + 名称/人数）、消息区、底部输入栏。
 *
 *  - 消息区是 `LazyList`：每条气泡按预估高度定位，只渲染视口附近的十几条；上翻几百条历史依旧一屏成本。
 *  - 气泡左右分列（我方右、蓝底白字；对方左、白底深字带细边），头像在气泡外侧，对方名字置于气泡上方，
 *    与上一条间隔较远时在消息上方插入居中时间分隔条——各可选段都计入该条的预估高度。
 *  - 输入栏贴底：回车或点“发送”追加消息并滚到底部（`LazyList` 会把超出偏移钳到底），最新消息始终可见。
 */
package cui_chat

import cui.{Button, ButtonRole, CrossAxisAlignment, Divider, EventHandler, FontSizes, HStack, Key, Label, LazyList,
    LengthUnits, Spacer, SurfaceStyle, TextField, UiEvent, VStack}

func chatView(model: ChatModel): Unit {
    EventHandler(onEvent: {event => handleChatKeys(event, model)}) {
        VStack {
            chatHeader(model)
            Divider()
            messagesPane(model)
            Divider()
            inputBar(model)
        }
    }
}

// 回车发送（空草稿为无操作）——在根部拦截，焦点无论在输入框还是按钮上都生效，这是聊天的惯例。
func handleChatKeys(event: UiEvent, model: ChatModel): Bool {
    match (event) {
        case UiEvent.KeyDown(Key.Enter, _) =>
            model.send()
            true
        case _ => false
    }
}

func chatHeader(model: ChatModel): Unit {
    HStack {
        Avatar("项目群聊", CHAT_GROUP_AVATAR)
        VStack {
            Label("项目群聊").fontSize(FontSizes.CONTROL)
            Label("${model.memberCount()} 人 · ${model.messages.value.size} 条消息，只渲染视口附近").muted()
                .fontSize(FontSizes.CAPTION)
        }.spacing(2.vp).hug()
        Spacer()
    }.spacing(10.vp).crossAxisAlignment(CrossAxisAlignment.Center).hug().padding(14.vp, 10.vp)
        .background(CHAT_BAR_BG)
}

func messagesPane(model: ChatModel): Unit {
    LazyList.of(model.messages.value, {m => m.height}, key: {m => "msg${m.id}"}, scroll: Some(model.scroll)) {
        m => messageRow(m)
    }
}

func messageRow(message: Message): Unit {
    // spacing 置 0：分隔条自带 6px 下间距，行高预算才能与实绘严格吻合（见 data.cj 的高度推导）。
    VStack {
        if (message.showsTime) {
            timeSeparator(message)
        }
        if (message.mine) {
            mineRow(message)
        } else {
            otherRow(message)
        }
    }.spacing(0.vp).padding(14.0, ROW_GAP / 2.0)
}

// 居中的时间分隔条，间隔较远的消息由它锚定时间线（高度计入该条预估；hug 防止被弹性压缩）。
func timeSeparator(message: Message): Unit {
    HStack {
        Spacer()
        Label(message.clock()).muted().fontSize(FontSizes.CAPTION)
        Spacer()
    }.hug().height(TIME_SEP_H - 6.0).padding(0.0, 0.0, 0.0, 6.0)
}

// 对方消息：头像在左，名字置于气泡上方（气泡外）。
func otherRow(message: Message): Unit {
    HStack {
        Avatar(message.sender, senderAvatarColor(message.sender))
        VStack {
            Label(message.sender).muted().fontSize(FontSizes.CAPTION)
            Label(message.text).maxLines(message.lines).foregroundColor(CHAT_OTHER_TEXT)
                .padding(BUBBLE_PAD)
                .surface(SurfaceStyle(CHAT_OTHER_BG, border: CHAT_OTHER_EDGE, radius: 12.0, borderWidth: 1.0))
                .maxWidth(340.vp)
        }.spacing(4.vp).hug()
        Spacer()
    }.spacing(8.vp).crossAxisAlignment(CrossAxisAlignment.Start).hug()
}

// 我方消息：头像在右，不显示名字。
func mineRow(message: Message): Unit {
    HStack {
        Spacer()
        Label(message.text).maxLines(message.lines).foregroundColor(CHAT_MINE_TEXT)
            .padding(BUBBLE_PAD)
            .background(CHAT_MINE_BG, 12.vp)
            .maxWidth(340.vp)
        Avatar(MY_SENDER, senderAvatarColor(MY_SENDER))
    }.spacing(8.vp).crossAxisAlignment(CrossAxisAlignment.Start).hug()
}

func inputBar(model: ChatModel): Unit {
    HStack {
        TextField(model.draft).flex()
        Button("发送", {=> model.send()}).role(ButtonRole.Primary)
    }.spacing(8.vp).crossAxisAlignment(CrossAxisAlignment.Center).hug().padding(14.vp, 10.vp)
        .background(CHAT_BAR_BG)
}
