/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
/*
 * CUI example: a small Windows process monitor.
 *
 * What it demonstrates:
 *  - keeping the UI responsive: the `tasklist` snapshot runs on a worker thread
 *    (`spawn`) and hands its result back through a mutex-guarded mailbox that the
 *    frame loop collects once per frame — the UI thread never blocks on a process
 *  - TabView pages, a read-only scrolling TextArea over live text, summary cards
 *  - desktop integration: CPU/display/power queries, app metadata, and SDL hints
 */
package cui_process_manager

import std.process.executeWithOutput
import std.sync.Mutex
import cui.AppMetadata
import cui.AppMetadataType
import cui.ButtonRole
import cui.Color
import cui.DesktopApp
import cui.DisplayInfo
import cui.DisplayMode
import cui.FontSizes
import cui.FrameHandler
import cui.FrameInfo
import cui.HStack
import cui.IconButton
import cui.IconName
import cui.Insets
import cui.Label
import cui.Panel
import cui.PowerInfo
import cui.PowerState
import cui.ProgressBar
import cui.Spacer
import cui.State
import cui.SdlHint
import cui.SdlHintSetting
import cui.TabView
import cui.TextArea
import cui.Theme
import cui.VStack
import cui.WindowSpec
import cui.cpuInfo
import cui.allDisplayInfos
import cui.platformName
import cui.powerInfo

struct Refresh {
    static let INTERVAL_MS: UInt64 = 5000
}

class ProcessModel {
    let output = State<String>("正在载入进程快照……")
    let outputScroll = State<Float32>(0.0)
    let status = State<String>("正在启动")
    let lastRefresh = State<UInt64>(0)
    let tab = State<Int64>(0)
}

/*
 * Runs the process snapshot off the UI thread. `request` is a no-op while a snapshot
 * is already in flight, and the finished text waits in the mailbox until the frame
 * loop collects it — so clicks and tab switches never wait on `tasklist`.
 */
class RefreshWorker {
    private let mutex = Mutex()
    private var pending: ?String = None
    private var busy = false

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
            publish(loadProcesses())
        }
    }

    // Runs on the worker thread. Only the hand-off is under the lock — never the slow
    // snapshot itself, so the UI thread's collect/isBusy calls always return at once.
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

main(): Int64 {
    let model = ProcessModel()
    let worker = RefreshWorker()
    worker.request()
    let app = DesktopApp(WindowSpec("CUI 进程管理器", 940, 620, scale: 1.5), metadata: Some(processMetadata()),
        hints: processHints(), theme: processTheme())
    let system = systemLine()
    let display = displayLine(allDisplayInfos())
    let power = powerSummary(powerInfo())
    app.run {
        FrameHandler(onFrame: {frame => tick(frame, model, worker)}) {
            processView(model, worker, [system, display, power])
        }
    }
    return 0
}

// One frame of housekeeping: collect a finished snapshot if the worker left one in
// the mailbox, then start the next refresh once the interval has elapsed.
func tick(frame: FrameInfo, model: ProcessModel, worker: RefreshWorker): Unit {
    match (worker.collect()) {
        case Some(snapshot) =>
            model.output.value = snapshot
            model.status.value = "已于 ${frame.elapsedMs / 1000} 秒更新"
        case None => ()
    }
    let last = model.lastRefresh.value
    if (last != 0 && frame.elapsedMs - last < Refresh.INTERVAL_MS) {
        return
    }
    worker.request()
    model.lastRefresh.value = frame.elapsedMs
}

func processView(model: ProcessModel, worker: RefreshWorker, facts: Array<String>): Unit {
    VStack(padding: Insets(14.0)) {
        Panel(padding: Insets(10.0), flexible: false) {
            HStack {
                IconButton(IconName.Refresh, label: Some("刷新"), role: ButtonRole.Primary) {
                    => worker.request()
                }
                Label(statusText(model, worker), muted: true)
                Spacer()
                Label("每 ${Refresh.INTERVAL_MS / 1000} 秒自动刷新", muted: true, fontSize: FontSizes.CAPTION)
            }
        }
        TabView(["进程", "概览"], model.tab) {
            TextArea("process.output", model.output, scroll: Some(model.outputScroll), editable: false)
            summaryPage(model, facts)
        }
    }
}

func statusText(model: ProcessModel, worker: RefreshWorker): String {
    if (worker.isBusy()) {
        "正在刷新……"
    } else {
        model.status.value
    }
}

func summaryPage(model: ProcessModel, facts: Array<String>): Unit {
    let titles = ["系统", "显示器", "电源"]
    VStack(spacing: 10.0, padding: Insets(6.0)) {
        for (i in 0..facts.size) {
            factCard(titles[i], facts[i])
        }
        snapshotCard(model)
        Spacer()
    }
}

func factCard(title: String, value: String): Unit {
    Panel(padding: Insets(12.0), flexible: false) {
        VStack(spacing: 6.0, flexible: false) {
            Label(title, muted: true, fontSize: FontSizes.CAPTION)
            Label(value, fontSize: FontSizes.TITLE)
        }
    }
}

func snapshotCard(model: ProcessModel): Unit {
    Panel(padding: Insets(12.0), flexible: false) {
        VStack(spacing: 8.0, flexible: false) {
            Label("进程快照大小", muted: true, fontSize: FontSizes.CAPTION)
            ProgressBar(State<Float32>(snapshotAmount(model.output.value)))
            Label("tasklist 返回 ${model.output.value.size} 字节", muted: true, fontSize: FontSizes.CAPTION)
        }
    }
}

func systemLine(): String {
    let cpu = cpuInfo()
    "${platformName()} | ${cpu.logicalCores} 个逻辑核心 | ${cpu.systemRamMb} MiB 内存"
}

func displayLine(displays: Array<DisplayInfo>): String {
    let display = displays[0]
    "${displays.size} 台显示器 | ${display.name} ${modeLabel(display.modes.current)} | 缩放 ${display.geometry.contentScale}"
}

func modeLabel(mode: ?DisplayMode): String {
    match (mode) {
        case Some(value) => "${value.width}x${value.height} @ ${Int64(value.refreshRate)} Hz"
        case None => "显示模式未知"
    }
}

func powerSummary(info: PowerInfo): String {
    "${powerStateLabel(info.state)} | ${percentLabel(info.percent)}"
}

func powerStateLabel(state: PowerState): String {
    match (state) {
        case PowerState.Error => "不可用"
        case PowerState.Unknown => "未知"
        case PowerState.OnBattery => "使用电池"
        case PowerState.NoBattery => "已接通电源"
        case PowerState.Charging => "充电中"
        case PowerState.Charged => "已充满"
    }
}

func percentLabel(percent: ?Int32): String {
    match (percent) {
        case Some(value) => "${value}%"
        case None => "电量未知"
    }
}

func snapshotAmount(text: String): Float32 {
    clampUnit(Float32(text.size) / 60000.0)
}

func clampUnit(value: Float32): Float32 {
    if (value > 1.0) {
        1.0
    } else if (value < 0.0) {
        0.0
    } else {
        value
    }
}

func loadProcesses(): String {
    match (executeWithOutput("cmd", ["/D", "/C", "chcp 65001 >NUL & tasklist"])) {
        case (0, stdoutBytes, _) => bytesToText(stdoutBytes)
        case (_, _, stderrBytes) => "tasklist 执行失败：\n${bytesToText(stderrBytes)}"
    }
}

func bytesToText(bytes: Array<UInt8>): String {
    unsafe { String.fromUtf8Unchecked(bytes) }
}

func processTheme(): Theme {
    Theme(
        Color.rgb(17, 24, 39),
        Color.rgb(24, 32, 46),
        Color.rgb(54, 68, 89),
        Color.rgb(236, 253, 245),
        Color.rgb(148, 163, 184),
        Color.rgb(52, 211, 153),
        Color.rgb(6, 32, 24),
        Color.rgb(251, 113, 133),
        Color.rgb(31, 41, 55),
        Color.rgb(36, 61, 55),
        panelRaised: Color.rgb(30, 41, 59),
        accentSoft: Color.rgb(26, 77, 66),
        shadow: Color.rgba(0, 0, 0, 82),
        radius: 16.0,
        controlRadius: 11.0
    )
}

func processMetadata(): AppMetadata {
    var metadata = AppMetadata(
        name: Some("CUI Process Manager"),
        version: Some("0.1.0"),
        identifier: Some("dev.cui.examples.process-manager")
    )
    metadata.creator = Some("CUI Examples")
    metadata.appType = Some(AppMetadataType.Application)
    metadata
}

func processHints(): Array<SdlHintSetting> {
    [
        SdlHintSetting(SdlHint.AppName, "CUI Process Manager"),
        SdlHintSetting(SdlHint.AppId, "dev.cui.examples.process-manager"),
        SdlHintSetting(SdlHint.RenderVSync, "1")
    ]
}
