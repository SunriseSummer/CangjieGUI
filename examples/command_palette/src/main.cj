/*
 * CUI 示例：命令面板。
 *
 * 集中演示累积能力：TextField 自动聚焦 + 选区/撤销、ListView 高亮、应用级键盘路由、
 * DerivedState 派生结果、State.observe 归零高亮——键盘驱动的模糊命令启动器。
 */
package cui_command_palette

import cui.{DesktopApp, WindowSpec}

main(): Int64 {
    let model = PaletteModel()
    let app = DesktopApp(WindowSpec("CUI 命令面板", 720, 640, scale: 1.0), theme: paletteTheme())
    app.setMinimumSize(520, 480)
    app.run {
        paletteView(model)
    }
    return 0
}
