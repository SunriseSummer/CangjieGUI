/*
 * 机群监控视图：标题、填满剩余空间的可排序 `Table`，以及选中行详情栏。
 *
 *  - 表头点击排序（数值列按数值），行点击或 Tab 聚焦后方向键选择
 *  - 详情栏文本随选中行由 `State.map` 派生，右侧显示总台数
 */
package cui_data_table

import cui.{CrossAxisAlignment, FontSizes, HStack, Label, LengthUnits, Panel, Spacer, Table, VStack}

func fleetView(model: FleetModel): Unit {
    VStack {
        header()
        // Typed data table: rows stay `Array<Server>`, columns extract fields — no string matrix.
        Table.of(model.servers, serverColumns(), model.selected).flex()
        detailBar(model)
    }.spacing(14.vp).padding(18.vp)
}

func header(): Unit {
    VStack {
        Label("服务器机群监控").fontSize(TABLE_TITLE)
        Label("点击列头排序，点击行或用方向键选择").muted().fontSize(FontSizes.CAPTION)
    }.spacing(3.vp).hug()
}

func detailBar(model: FleetModel): Unit {
    Panel {
        HStack {
            Label(model.summary.value)
            Spacer()
            Label("共 ${model.servers.size} 台").muted().fontSize(FontSizes.CAPTION)
        }.crossAxisAlignment(CrossAxisAlignment.Center)
    }.contentPadding(12.vp).hug()
}
