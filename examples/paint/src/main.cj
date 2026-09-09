/*
 * CUI 示例：画板。
 *
 * 演示内容：
 *  - CanvasWidget 的自绘与鼠标手势：按下起笔、拖动采样、松开收笔
 *  - 用标准 Button 组合色板，复用键盘、焦点、松开激活与语义协议
 *  - DerivedState 派生的画笔粗细与笔迹计数文本，随状态自动刷新
 */
package cui_paint

import cui.{DesktopApp, SystemCursor, WindowSpec}

main(): Int64 {
    let model = PaintModel()
    let app = DesktopApp(WindowSpec("CUI 画板", 900, 600, scale: 1.0), theme: paintTheme())
    // FlowRow 按可用宽度换行；最小尺寸为画布与操作区保留基本空间。
    app.setMinimumSize(640, 480)
    // 画布静止态用十字光标；悬停到按钮、滑块等可交互控件时，外壳会自动切换为手形光标。
    app.useBaseCursor(SystemCursor.Crosshair)
    app.run {
        paintView(model)
    }
    return 0
}
