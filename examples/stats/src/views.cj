/*
 * 数据看板视图层：标题 + 时段分段 + 指标卡网格。每张卡的数值行由「大号粗体数值 + 小号弱化单位」拼成一行富文本。
 *
 * 逐段字号使两种字号在行内居中对齐、行高随最大字号增长；环比变化按好坏着色。切时段即换整组指标。
 */
package cui_stats

import cui.{Color, CrossAxisAlignment, FontSizes, Grid, Label, LengthUnits, Panel, RetainedSubtree, RichSpan, RichText,
    SegmentedControl, VStack}

func statsView(model: StatsModel): Unit {
    VStack {
        header()
        SegmentedControl(PERIOD_LABELS, model.period, key: "period")
        // The transparent gaps keep showing the ancestor background. A retained value-command list
        // replays the cards without baking that background into a per-node GPU texture.
        RetainedSubtree("stats-grid", cachePaint: true) {
            Grid(2) {
                for (stat in model.stats()) {
                    tile(stat)
                }
            }.spacing(14.vp, 14.vp).flex()
        }
    }.spacing(14.vp).padding(20.vp)
}

private func header(): Unit {
    VStack {
        Label("数据看板").fontSize(FontSizes.TITLE).bold()
        Label("每张卡的「大号数值 + 小号单位」是一行 RichText，逐段字号：行内居中、行高随最大字号增长")
            .muted()
            .fontSize(FontSizes.CAPTION)
            .wrap()
    }.spacing(4.vp).crossAxisAlignment(CrossAxisAlignment.Start).hug()
}

private func tile(stat: Stat): Unit {
    Panel {
        VStack {
            Label(stat.name).muted().fontSize(FontSizes.CAPTION)
            // The per-span-size showcase: a big bold value and a small muted unit share one line.
            RichText(
                [
                    RichSpan.text("${stat.value}").bold().fontSize(30.0),
                    RichSpan.muted(" ${stat.unit}").fontSize(14.0)
                ]
            )
            // A coloured delta below, small.
            RichText(
                [
                    RichSpan.text(deltaText(stat.deltaPct), color: deltaColor(stat)).bold().fontSize(13.0),
                    RichSpan.muted(" vs 上期").fontSize(12.0)
                ]
            )
        }.spacing(6.vp).crossAxisAlignment(CrossAxisAlignment.Start).hug()
    }.contentPadding(16.vp)
}

private func deltaColor(stat: Stat): Color {
    if (deltaIsGood(stat)) {
        DELTA_GOOD
    } else {
        DELTA_BAD
    }
}
