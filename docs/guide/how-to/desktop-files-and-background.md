<!-- kind: how-to; audience: desktop-app-developer -->

# 在后台工作，并把结果安全送回界面

## 目标

发起不会冻结窗口的后台任务，用 `DesktopApp.post` 投递结果；需要合并高频结果或自行管理背压时，再用互斥信箱。文件对话框仍按异步请求轮询。完成约需 20 分钟。

## 适用场景

文件选择、目录扫描、进程查询、网络请求或其他不可放进界面回调的工作。很短的纯计算可以同步执行，不要为了异步而异步。

## 准备工作

把任务输入和输出设计为不引用 UI State 或控件的普通数据；工作线程只通过 `app.post` 的回调安排 UI 修改；列出成功、取消、失败和重复点击四条路径。确定 UI 状态中的 busy、message 和结果由谁持有，并准备在关闭页面时忽略或取消过期结果。文件对话框还要准备扩展名过滤与默认位置策略。

## 操作步骤

### 1. 划清线程边界

工作线程只处理普通数据，绝不直接写 UI `State`。完成后调用 `app.post` 投递一个短 UI 动作：它经线程安全队列唤醒正在等待事件的循环，并在 UI 线程事务中执行。一次动作内的多次状态写只产生一次视觉失效。`post` 返回 `false` 保证动作未入队，调用方应按业务规则重试、保留结果或取消；返回 `true` 表示已接收，但关闭时仍可能丢弃未执行动作。SDL 唤醒失败不改变接收结果，计入 `postStats().wakeFailures`，限时事件等待会继续排空已接收动作。成功和失败必须走同一个返回通道；应用退出前应取消或等待自己创建的工作任务结束。

### 2. 需要背压时使用信箱，并只在等待期间续帧

挂载 `FrameHandler` 会持续请求下一帧。结果收取完毕就卸下它，让静止窗口回到空闲状态。`needsPolling()` 要同时检查“仍在工作”和“已有结果未取”，避免发布结果的一瞬间提前停止轮询。

### 3. 运行完整信箱示例

```cangjie verify role=complete profile=gui-visual
package docexample

import cui.*
import std.sync.Mutex

class UiMailbox {
    private let mutex = Mutex()
    private var pending: ?String = None
    private var busy = false

    func start(): Bool {
        var accepted = false
        synchronized(mutex) {
            if (!busy) {
                busy = true
                accepted = true
            }
        }
        if (!accepted) {
            return false
        }
        let _ = spawn {publish("后台结果已就绪")}
        true
    }

    private func publish(result: String): Unit {
        synchronized(mutex) {
            pending = Some(result)
            busy = false
        }
    }

    func collect(): ?String {
        synchronized(mutex) {
            let result = pending
            pending = None
            return result
        }
    }

    func needsPolling(): Bool {
        synchronized(mutex) {
            return busy || pending.isSome()
        }
    }
}

func body(mailbox: UiMailbox, status: State<String>): Unit {
    VStack(spacing: 12.vp) {
        Label(status.value)
        Button("开始后台任务", {
            => if (mailbox.start()) {
                status.value = "正在处理"
            }
        })
    }.padding(24.vp)
}

func page(mailbox: UiMailbox, status: State<String>): Unit {
    if (mailbox.needsPolling()) {
        FrameHandler(onFrame: {
            _ => match (mailbox.collect()) {
                case Some(result) => status.value = result
                case None => ()
            }
        }) {body(mailbox, status)}
        return
    }
    body(mailbox, status)
}

main(): Unit {
    let mailbox = UiMailbox()
    let status = State<String>("尚未开始")
    let app = DesktopApp(WindowSpec("后台任务", 420, 240))
    app.run {page(mailbox, status)}
}
```

### 4. 把文件对话框接到相同轮询点

按钮回调调用 `app.openFileDialog(options: options)`，并把返回的请求句柄保存在模型中。帧回调查询
`result()` 后分别处理等待、取消、失败和已选择四种 `FileDialogResult`；选择成功时再读取返回的路径。`FileDialogRequest` 不是 `Resource`，没有 `poll()` 或 `close()`；终态处理后移除模型引用即可。对话框请求是异步句柄，
不要在按钮回调里阻塞等待。文件解析仍可放进工作线程，最终经信箱返回；取消不是异常，应该显示普通状态。

## 确认结果

点击按钮后立刻显示“正在处理”，窗口仍能移动和重绘，随后显示结果。快速连点不会启动重复任务。把后台代码改为发布错误文本，界面也应结束等待并显示失败。文件对话框路径还需人工验证选择、取消、无权限和文件不存在四条分支。

重复运行十次并在任务完成前移动窗口，状态不应卡在 busy。关闭再打开页面时，旧任务结果不能写进新页面模型。性能记录应表明等待期间只有轻量轮询帧，真正文件读取不占用 UI 线程；结果到达后帧循环停止。

## 常见错误

- `spawn` 内直接写 `State`：违反 UI 线程约束，结果可能偶发丢失。
- 锁内做文件读取：UI 收取结果时也会被长时间阻塞。
- 只轮询 `busy`：结果发布后 `busy=false`，最后一条消息可能永远不取。
- 永久挂载 `FrameHandler`：静止窗口也持续耗电和占用 CPU。

## 相关 API

[FrameHandler](../../api/cui/core/FrameHandler.md)、[State](../../api/cui/core/State.md)、[DesktopApp](../../api/cui/desktop/DesktopApp.md)。

## 下一步

用[快照与性能记录](snapshot-and-profile.md)验证界面，用[媒体性能排障](../troubleshooting/media-performance.md)检查卡顿。
