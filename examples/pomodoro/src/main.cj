/*
 * 番茄钟入口：组装模型与窗口。
 *
 * 计时只在运行中才挂 FrameHandler（它每帧请求下一帧）；暂停或到点停下后不包裹，
 * 渲染循环回到脏帧跳过的零开销空闲——按需驱动动画的标准做法。
 */
package cui_pomodoro

import cui.{DesktopApp, FrameHandler, WindowSpec}

main(): Unit {
    let model = newPomodoroModel()
    let app = DesktopApp(WindowSpec("CUI 番茄钟", 560, 660, scale: 1.0), theme: pomodoroTheme())
    app.run {
        if (model.running.value) {
            FrameHandler(onFrame: {info => model.tick(Int64(info.deltaMs))}, body: {=> pomodoroView(model)})
        }
        if (!model.running.value) {
            pomodoroView(model)
        }
    }
}
