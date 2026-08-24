/*
 * CUI 示例：产品看板。
 *
 * 演示内容：
 *  - 单一数据源驱动三列卡片；列头计数由 DerivedState 派生，永不与卡片脱节
 *  - ForEach 按任务 id 维持卡片身份；筛选、新增即时生效
 *  - 在制上限超出时的警示配色与紧凑/舒适两档卡片密度
 */
package cui_data_board

import cui.{DesktopApp, WindowSpec}

main(): Int64 {
    let model = BoardModel()
    let app = DesktopApp(WindowSpec("CUI 产品看板", 1180, 720, scale: 1.0), theme: boardTheme())
    app.setMinimumSize(880, 560)
    app.run {
        boardView(model)
    }
    return 0
}
