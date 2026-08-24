/*
 * CUI 示例：样式卡片。
 *
 * 演示样式修饰符 `shadow`（可配 offset/blur/spread/color 的软阴影，含 Material 式 `Shadow.elevation` 预设）、
 * `background(color, radius)`（圆角填充）与 `border`（圆角描边）：一张预览卡片的阴影层级、圆角与边框可用
 * Stepper/Switch 实时调整，下方另有 elevation 阶梯参考。综合演示样式属性 + 状态绑定 + 派生描述。
 */
package cui_cards

import cui.{DesktopApp, WindowSpec}

main(): Int64 {
    let model = CardsModel()
    let app = DesktopApp(WindowSpec("CUI 样式卡片", 640, 640, scale: 1.0), theme: cardsTheme())
    app.setMinimumSize(560, 560)
    app.run {
        cardsView(model)
    }
    return 0
}
