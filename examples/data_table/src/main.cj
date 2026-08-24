/*
 * CUI 示例：数据表格。
 *
 * 用一张“服务器机群监控表”演示 `Table`：固定表头、窗口化滚动、点击列头排序（数值列按数值）、
 * 行选择跟随原始数据行，以及选中行驱动的详情栏（`State.map` 派生）。
 */
package cui_data_table

import cui.{DesktopApp, WindowSpec}

main(): Int64 {
    let model = FleetModel()
    let app = DesktopApp(WindowSpec("CUI 机群监控", 800, 620, scale: 1.0), theme: fleetTheme())
    app.setMinimumSize(680, 480)
    app.run {
        fleetView(model)
    }
    return 0
}
