/*
 * CUI 示例：线性渐变。
 *
 * 演示 `gradientBackground(Gradient)` 样式修饰符：两色线性渐变填充圆角背景，可纵向（顶→底）或横向（左→右）。
 * 一张大预览随选中的预设与方向实时更新，下方是全部预设的渐变样本墙。渐变复用与实填相同的缓存网格、
 * 逐顶点着色，不额外增加三角剖分。综合演示渐变样式 + 状态绑定 + 派生。
 */
package cui_gradients

import cui.{DesktopApp, WindowSpec}

main(): Int64 {
    let model = GradientsModel()
    let app = DesktopApp(WindowSpec("CUI 线性渐变", 640, 660, scale: 1.0), theme: gradientsTheme())
    app.setMinimumSize(540, 560)
    app.run {
        gradientsView(model)
    }
    return 0
}
