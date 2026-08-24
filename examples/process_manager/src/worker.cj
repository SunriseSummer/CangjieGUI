/*
 * 后台刷新链路：帧调度、工作线程执行 tasklist、受检解码。
 *
 * 快照在 spawn 的工作线程上采集，结果放进互斥量保护的“信箱”，帧循环每帧收取
 * 一次，UI 线程永远不会等在子进程上。busy 标志保证同一时刻至多一份快照在跑。
 */
package cui_process_manager

import std.process.executeWithOutput
import std.sync.Mutex
import cui.FrameInfo

class RefreshWorker {
    private let mutex = Mutex()
    private let snapshotFixture: ?String
    private var pending: ?String = None
    private var busy = false

    init(snapshotFixture!: ?String = None) {
        this.snapshotFixture = snapshotFixture
    }

    func request(): Unit {
        var shouldStart = false
        synchronized(mutex) {
            if (!busy) {
                busy = true
                shouldStart = true
            }
        }
        if (!shouldStart) {
            return
        }
        let _ = spawn {
            // 工作线程的异常绝不能逃逸：spawn 的 Future 无人 get，异常会被静默吞掉，
            // busy 从此永远为 true，之后所有自动/手动刷新都被 request() 挡住且毫无提示。
            // 因此失败也走 publish —— busy 得以复位，错误文案在进程页对用户可见。
            try {
                match (snapshotFixture) {
                    case Some(snapshot) => publish(snapshot)
                    case None => publish(loadProcesses())
                }
            } catch (e: Exception) {
                publish("进程快照采集失败：${e.message}")
            }
        }
    }

    // 在工作线程上运行。锁内只做结果交接，绝不包住耗时的快照本身，
    // 这样 UI 线程的 collect/isBusy 调用总能立即返回。
    private func publish(snapshot: String): Unit {
        synchronized(mutex) {
            pending = Some(snapshot)
            busy = false
        }
    }

    func collect(): ?String {
        synchronized(mutex) {
            let taken = pending
            pending = None
            return taken
        }
    }

    func isBusy(): Bool {
        synchronized(mutex) {
            return busy
        }
    }
}

/*
 * 每帧一次的刷新管理：先收取工作线程留在信箱里的快照，再在间隔期满后发起下一轮。
 * 记录的是“完成上屏”而非“发起请求”的时刻，状态栏的“N 秒前刷新”才与
 * 用户看到的数据一致。
 */
func tick(frame: FrameInfo, model: ProcessModel, worker: RefreshWorker): Unit {
    model.nowTick.value = frame.elapsedMs
    match (worker.collect()) {
        case Some(snapshot) =>
            // 选中存的是行索引，而新快照会重排/增删行——先记下选中进程的 PID，
            // 换过快照后按 PID 找回同一进程，避免高亮悄悄落到别的进程上。
            let pid = selectedPid(model)
            model.output.value = snapshot
            model.selectedRow.value = rowIndexOfPid(model.processRows.value, pid)
            model.refreshedTick.value = frame.elapsedMs
        case None => ()
    }
    let requested = model.requestedTick.value
    if (requested != 0 && frame.elapsedMs - requested < Refresh.INTERVAL_MS) {
        return
    }
    worker.request()
    model.requestedTick.value = frame.elapsedMs
}

func loadProcesses(): String {
    // 用 && 串联：chcp 切换 UTF-8 代码页失败时就不再执行 tasklist，
    // 否则 tasklist 会按当前代码页（如 GBK）输出字节，后续 UTF-8 解码必然出错。
    // /FO CSV /NH 输出无表头的 CSV，便于解析成表格行（列名由视图层给出）。
    match (executeWithOutput("cmd", ["/D", "/C", "chcp 65001 >NUL && tasklist /FO CSV /NH"])) {
        case (0, stdoutBytes, _) => bytesToText(stdoutBytes)
        case (_, _, stderrBytes) => "tasklist 执行失败：\n${bytesToText(stderrBytes)}"
    }
}

// 子进程输出是不可信输入，必须走受检解码：坏字节换来一句可读提示，
// 而不是免检转换的未定义行为。
func bytesToText(bytes: Array<UInt8>): String {
    try {
        String.fromUtf8(bytes)
    } catch (e: Exception) {
        "输出包含无法按 UTF-8 解码的字节，已放弃显示。"
    }
}
