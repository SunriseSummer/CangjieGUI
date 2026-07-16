/*
 * 通知状态：一个 `Toaster` 控制器（持有活动通知与计时），以及已弹出计数。
 *
 * `Toaster` 是应用级控制器，从任意处 `show` 一条通知即可；视图里放一个 `ToastLayer(toaster)` 负责渲染与计时，
 * 每条通知滑入、停留数秒后淡出。初始化时先弹两条，使应用打开即有可见通知。
 */
package cui_notify

import cui.{ToastKind, Toaster}

class NotifyModel {
    let toaster = Toaster()
    var shown: Int64 = 0

    init() {
        toaster.show("欢迎使用 CUI 通知组件", kind: ToastKind.Info, durationMs: 8000)
        toaster.show("已连接到示例服务", kind: ToastKind.Success, durationMs: 8000)
    }

    /** 弹出一条指定类型的通知，文案带自增序号。 */
    func notify(kind: ToastKind): Unit {
        shown += 1
        toaster.show(messageFor(kind, shown), kind: kind, durationMs: 3200)
    }
}
