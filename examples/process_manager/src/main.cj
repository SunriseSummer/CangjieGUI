/*
 * CUI 示例：Windows 进程监视器。
 *
 * 演示内容：
 *  - 保持 UI 响应：tasklist 快照在 spawn 的工作线程上运行，结果经互斥量保护的
 *    信箱交回，帧循环每帧收取一次 —— UI 线程从不等待子进程
 *  - TabView 页面、可排序的 Table 进程表（由 tasklist CSV 派生）、由 State 派生的概览卡片文案
 *  - 桌面集成：CPU/显示器/电源查询、应用元数据与 SDL 提示
 *
 * 文件分工：model.cj 状态与常量，worker.cj 后台刷新链路，views.cj 界面结构，
 * system_info.cj 系统信息文案，theme.cj 主题与桌面壳设置。
 */
package cui_process_manager

import std.env.getCommandLine
import cui.{DesktopApp, FrameHandler, WindowSpec}

main(): Int64 {
    let model = ProcessModel()
    // Snapshot E2E runs inject stable source data through the same mailbox-consumption path;
    // interactive runs continue to query the live operating system on a background worker.
    let snapshotFixture = processSnapshotFixture(getCommandLine())
    let worker = RefreshWorker(snapshotFixture: snapshotFixture)
    // 启动立即拉取第一份快照，首帧就有内容可以等待，而不是干等 5 秒间隔。
    if (snapshotFixture.isNone()) {
        worker.request()
    }
    // 硬件与电源事实在应用生命周期内几乎不变，启动时查询一次即可。
    let facts = systemFacts()
    let app = DesktopApp(WindowSpec("CUI 进程管理器", 940, 620, scale: 1.0), metadata: Some(processMetadata()),
        hints: processHints(), theme: processTheme())
    // 布局没有为更小的窗口做回流设计，锁定最小尺寸防止内容被挤出屏幕。
    app.setMinimumSize(720, 520)
    app.run {
        FrameHandler(onFrame: {frame => tick(frame, model, worker)}) {
            processView(model, worker, facts)
        }
    }
    return 0
}
