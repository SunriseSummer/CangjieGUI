# 桌面线程、后台任务与关闭确认

在程序主线程创建并运行 DesktopApp。SdlWindow 在调用 SDL 前自动固定当前仓颉线程对应的原生线程；同一线程的多个窗口共享绑定，最后一个窗口关闭后释放，构造失败会回滚。该行为无需应用添加特殊包装，当前已验证仓颉运行时 1.0.5。耗时计算与文件操作放到后台，结果通过 `post` 返回。`post == false` 保证没有入队，可以按业务需求重试或取消；`true` 只表示接收，应用关闭会丢弃尚未执行的动作。不要从工作线程读写 UI State，也不要在 UI 回调中阻塞等待 Future。

默认最多等待 4096 个动作，每轮最多执行 256 个。以 `postStats()` 观察队列压力与唤醒失败；框架合并唤醒，剩余任务会请求续帧。入队顺序决定执行顺序，来自不同线程的业务结果仍需自行检查请求版本，避免较旧结果覆盖新结果。

关闭确认保持事件循环可用。以下示例展示继续编辑与放弃修改；实际保存流程应在确认成功后接受请求，失败时保留请求并展示错误，或调用 `cancel()`。

```cangjie verify
package docexample

import cui.{Button, CloseRequest, DesktopApp, Label, Modal, State, VStack, WindowSpec}

main(): Unit {
    let app = DesktopApp(WindowSpec("关闭确认", 520, 320), maxPendingPosts: 1024)
    let dirty = State<Bool>(false)
    let open = State<Bool>(false)
    let pending = State<?CloseRequest>(None)
    let cancel: () -> Unit = {=>
        if (let Some(request) <- pending.value) { request.cancel() }
        pending.value = None
        open.value = false
    }
    app.setCloseRequestHandler({request =>
        if (!dirty.value) { request.accept() }
        else { pending.value = Some(request); open.value = true }
    })
    app.run {
        VStack {
            Button("模拟修改", {=> dirty.value = true})
            Button("退出", {=> app.requestClose()})
        }
        Modal(open, initialFocus: "cancel", dismissOnBackdrop: false, onDismiss: cancel) {
            VStack {
                Label("放弃尚未保存的修改？")
                Button("继续编辑", cancel).key("cancel")
                Button("放弃并退出", {=>
                    if (let Some(request) <- pending.value) { request.accept() }
                })
            }
        }
    }
}
```

系统关闭事件与 `app.requestClose()` 使用同一协议，未决请求期间重复关窗不会重复弹框。程序主动调用 `UiContext.requestClose()` 会直接退出，适用于测试或明确的强制关闭路径。

资源按登记逆序关闭，某个资源清理失败不会阻止其余资源清理；单个异常保持原类型，多个异常通过 `UiAggregateException` 一并报告。应用应在退出前停止自己的后台生产任务。关闭协议不替应用实现文件保存、版本冲突或业务事务。

参见 [editor 示例](../../../examples/editor/README.md)、[DesktopApp API](../../api/cui/desktop/DesktopApp.md)。

## 异常恢复与诊断

单个异常保持原类型；主流程与清理同时失败，或多个观察者／资源同时失败时，捕获 [`UiAggregateException`](../../api/cui/core/UiAggregateException.md)。使用 `primary` 定位最先发生的问题，逐个检查 `failures` 的消息和堆栈，不能只看外层异常的堆栈。关停会尝试所有阶段，清理失败本身不会被吞掉。

事件路由抛出异常后仍完成鼠标释放收尾，事件元数据也会恢复。`WidgetTestHost.reset()` 在 effect 清理失败时仍清除焦点、按压、拖拽、浮层和输入锚点，再报告清理异常，以便测试继续检查恢复路径。DesktopApp 的未处理异常仍结束运行，不会静默重试业务回调。
