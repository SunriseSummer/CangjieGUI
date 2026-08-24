/*
 * CUI 示例：缓动实验室。
 *
 * 演示缓动曲线库 `Easing` 与时长动画 `Animator`：七条轨道各绑一种缓动曲线（线性、二/三次 In/Out/InOut、
 * 正弦、回弹、CSS ease 贝塞尔），共享同一时长；点“播放”让标记点并排推进，直观对比各曲线的运动分布，
 * 回弹曲线会略微越过终点再回落。自定义 Widget 逐帧推进并请求下一帧，即时模式下驱动连续动画。
 */
package cui_motion

import cui.{DesktopApp, WindowSpec}

main(): Int64 {
    let model = MotionModel()
    let app = DesktopApp(WindowSpec("CUI 缓动实验室", 640, 560, scale: 1.0), theme: motionTheme())
    app.setMinimumSize(520, 460)
    app.run {
        motionView(model)
    }
    return 0
}
