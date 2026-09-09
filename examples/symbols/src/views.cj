package cui_symbols

import cui.*
import cui.symbols.calendar.ICON_CALENDAR
import cui.symbols.clock.ICON_CLOCK
import cui.symbols.heart.ICON_HEART
import cui.symbols.search.ICON_SEARCH
import cui.symbols.star.ICON_STAR

private let INK = Color.rgb(25, 51, 61)
private let TEAL = Color.rgb(27, 119, 112)
private let PAPER = Color.rgb(250, 249, 245)
private let LINE = Color.rgb(220, 227, 225)

func symbolsView(model: SymbolsModel): Unit {
    VStack(spacing: 20.vp) {
        HStack(spacing: 16.vp) {
            Icon(ICON_STAR).iconSize(42.vp).foregroundColor(TEAL)
            VStack(spacing: 3.vp) {
                Label("日常的形状").fontSize(28.fp).bold().foregroundColor(INK)
                Label("40 枚原创图标 · 一致的圆头线条与留白 · 全部嵌入源码").fontSize(12.fp).muted()
            }.hug()
            Spacer()
            Label("CUI SYMBOLS    /    01").fontSize(12.fp).foregroundColor(TEAL)
        }.hug().width(1120.vp)
        VStack(spacing: 12.vp) {
            for (row in 0..5) {
                HStack(spacing: 12.vp) {
                    for (column in 0..8) {
                        symbolCell(model.entries[row * 8 + column])
                    }
                }.hug()
            }
        }.hug()
        HStack(spacing: 16.vp) {
            scaleCard()
            themeCard(model)
            pickerCard(model)
        }.crossAxisAlignment(CrossAxisAlignment.Start).hug()
        HStack {
            Label("24 × 24 网格   /   1.75 描边   /   透明背景   /   DPI 自适应").fontSize(11.fp).muted()
            Spacer()
            Label("按单图标导入，让每一份资源都有用途。").fontSize(11.fp).foregroundColor(TEAL)
        }.hug().width(1120.vp)
    }.crossAxisAlignment(CrossAxisAlignment.Start).hug().padding(30.vp)
}

private func symbolCell(entry: SymbolEntry): Unit {
    VStack(spacing: 6.vp) {
        Icon(entry.source).iconSize(30.vp).foregroundColor(INK).height(42.vp)
        Label(entry.label).fontSize(12.fp).foregroundColor(INK).textAlign(TextAlign.Center)
        Label(entry.name).fontSize(10.fp).muted().textAlign(TextAlign.Center)
    }.hug().padding(10.vp).width(129.5.vp).height(128.vp).background(PAPER, 12.vp).border(LINE, width: 1.0,
        radius: 12.vp)
}

private func scaleCard(): Unit {
    VStack(spacing: 15.vp) {
        Label("一份矢量，多个尺寸").fontSize(14.fp).bold().foregroundColor(INK)
        HStack(spacing: 21.vp) {
            for (extent in [16, 20, 24, 32, 48]) {
                VStack(spacing: 8.vp) {
                    Icon(ICON_SEARCH).iconSize(Float32(extent)).foregroundColor(TEAL).height(52.vp)
                    Label("${extent}").fontSize(11.fp).muted()
                }.hug()
            }
        }.hug()
        Label("根据显示尺寸与 DPI 生成并复用纹理").fontSize(11.fp).muted()
    }
        .crossAxisAlignment(CrossAxisAlignment.Start)
        .hug()
        .padding(18.vp)
        .width(360.vp)
        .background(PAPER, 14.vp)
        .border(LINE, width: 1.0, radius: 14.vp)
}

private func themeCard(model: SymbolsModel): Unit {
    VStack(spacing: 12.vp) {
        Label("颜色与状态，由界面决定").fontSize(14.fp).bold().foregroundColor(Color.rgb(239, 244, 237))
        HStack(spacing: 24.vp) {
            Icon(ICON_CALENDAR).iconSize(28.vp).foregroundColor(Color.rgb(120, 199, 180))
            Icon(ICON_CLOCK).iconSize(28.vp).foregroundColor(Color.rgb(246, 194, 121))
            Icon(ICON_HEART).iconSize(28.vp).foregroundColor(Color.rgb(240, 162, 163))
            Icon(ICON_STAR).iconSize(28.vp).foregroundColor(Color.rgb(239, 244, 237)).iconOpacity(0.4)
        }.hug().height(48.vp)
        IconButton(ICON_HEART, label: "喜欢 ${model.clicks.value}", onClick: {=> model.clicks.value += 1})
            .accessibilityLabel("喜欢图标集")
    }.crossAxisAlignment(CrossAxisAlignment.Start).hug().padding(18.vp).width(352.vp).background(INK, 14.vp)
}

private func pickerCard(model: SymbolsModel): Unit {
    VStack(spacing: 12.vp) {
        Label("熟悉的日期与时间").fontSize(14.fp).bold().foregroundColor(INK)
        DatePicker(model.date, key: "symbol-date")
        TimePicker(model.time, key: "symbol-time")
    }
        .crossAxisAlignment(CrossAxisAlignment.Start)
        .hug()
        .padding(18.vp)
        .width(376.vp)
        .background(PAPER, 14.vp)
        .border(LINE, width: 1.0, radius: 14.vp)
}
