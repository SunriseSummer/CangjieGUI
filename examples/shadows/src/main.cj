/*
 * CUI 示例：多重阴影。
 *
 * 演示 `shadow(layers)` 叠层投影与 `Shadow.keyAmbient` 双层预设：同一层级下单层与双层并排对照，
 * 双层由宽而淡的环境光叠上窄而深的方向光，深度感更接近商用基准。综合演示叠层阴影 + 层级预设。
 */
package cui_shadows

import cui.{DesktopApp, WindowSpec}

main(): Int64 {
    let model = ShadowsModel()
    let app = DesktopApp(WindowSpec("CUI 多重阴影", 640, 560, scale: 1.0), theme: shadowsTheme())
    app.setMinimumSize(560, 460)
    app.run {
        shadowsView(model)
    }
    return 0
}
