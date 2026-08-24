/*
 * CUI 示例：逐角圆角。
 *
 * 演示 `Corners`（四角各自取半径的背景）：聊天气泡整体圆润、唯独发送者一侧的下角收成小尾角；底部输入条用
 * `Corners.top` 只圆上面两角。圆角与尾角可用 Stepper 实时调整。综合演示逐角圆角 + 文本输入 + 列表状态。
 */
package cui_corners

import cui.{DesktopApp, WindowSpec}

main(): Int64 {
    let model = CornersModel()
    let app = DesktopApp(WindowSpec("CUI 逐角圆角", 620, 620, scale: 1.0), theme: cornersTheme())
    app.setMinimumSize(520, 480)
    app.run {
        cornersView(model)
    }
    return 0
}
