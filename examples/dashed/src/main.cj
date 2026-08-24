/*
 * CUI 示例：虚线边框。
 *
 * 演示 `dashedBorder` 样式修饰符：沿圆角矩形周边等距行进画虚线（实线段/间隔/圆角/线宽可配）。一张预览框
 * 随 Stepper 实时调整，另有拖放区、占位卡等常见用法。虚线沿路径连续行进，转角处仍均匀。综合演示虚线边框
 * 样式 + 状态绑定 + 派生。
 */
package cui_dashed

import cui.{DesktopApp, WindowSpec}

main(): Int64 {
    let model = DashedModel()
    let app = DesktopApp(WindowSpec("CUI 虚线边框", 620, 640, scale: 1.0), theme: dashedTheme())
    app.setMinimumSize(540, 540)
    app.run {
        dashedView(model)
    }
    return 0
}
