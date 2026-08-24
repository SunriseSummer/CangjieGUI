/*
 * CUI 示例：桌面计算器。
 *
 * 演示内容：
 *  - Flexible 等权单元构成的均匀键盘网格，“0”键以 weight 2.0 横跨两列
 *  - 枚举化按键 + 集中样式映射；标准/科学模式用 if 控制流增减一行键位
 *  - EventHandler 接入键盘：数字/运算符直接键入，Enter 求值，Backspace 删位
 */
package cui_calculator

import cui.{DesktopApp, EventHandler, WindowSpec}

main(): Int64 {
    let model = CalcModel()
    let app = DesktopApp(WindowSpec("CUI 计算器", 480, 600, scale: 1.0, resizable: false), theme: calculatorTheme())
    app.run {
        EventHandler(onEvent: {event => handleCalculatorEvent(model, event)}) {
            calculatorView(model)
        }
    }
    return 0
}
