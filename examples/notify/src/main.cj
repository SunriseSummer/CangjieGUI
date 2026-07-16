/*
 * CUI 示例：通知（Toast）。
 *
 * 演示 `Toaster` + `ToastLayer` 瞬态通知：从任意处 `show` 一条通知，`ToastLayer` 负责在右下角堆叠渲染、
 * 计时、滑入与淡出，并在有通知时驱动帧刷新（时间动画需 `ctx.requestFrame`，否则空闲循环会冻结动画）。
 */
package cui_notify

import cui.{DesktopApp, WindowSpec}

main(): Int64 {
    let model = NotifyModel()
    let app = DesktopApp(WindowSpec("CUI 通知", 620, 480, scale: 1.5), theme: notifyTheme())
    app.setMinimumSize(480, 380)
    app.run {
        notifyView(model)
    }
    return 0
}
