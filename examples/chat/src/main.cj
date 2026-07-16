/*
 * CUI 示例：聊天（变高虚拟列表）。
 *
 * 演示 `LazyList` 变高虚拟列表：一段长短不一的对话，每条气泡按预估高度定位，只物化视口附近的十几条，
 * 上翻数百条历史消息仍只付出一屏成本。输入栏发送后追加消息并滚到底部。
 */
package cui_chat

import cui.{DesktopApp, WindowSpec}

main(): Int64 {
    let model = ChatModel()
    let app = DesktopApp(WindowSpec("CUI 聊天", 640, 680, scale: 1.5), theme: chatTheme())
    app.setMinimumSize(480, 520)
    app.run {
        chatView(model)
    }
    return 0
}
