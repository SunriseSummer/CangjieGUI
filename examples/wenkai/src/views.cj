// 随附字体：一个字体族、多份静态字重文件，使用 fontWeight 选择。
package cui_wenkai

import cui.{CrossAxisAlignment, FontSizes, Label, LengthUnits, Panel, ScrollView, SegmentedControl, VStack, TextStyle,
    CanvasWidget, Color, FontStyle}

func wenkaiView(model: WenkaiModel): Unit {
    VStack {
        header()
        SegmentedControl(weightLabels(), model.selected, key: "weights")
        ScrollView {
            VStack {
                specimenCard(model)
                weightCompareCard()
                monoCard()
            }.spacing(12.vp)
        }.flex()
        statusBar(model)
    }.spacing(12.vp).padding(20.vp)
}

private func header(): Unit {
    VStack {
        Label("本地字体样本册").fontSize(FontSizes.TITLE).bold()
        Label("一个字体族关联多份文件；用 fontWeight 选择 Light / Regular / Medium")
            .muted()
            .fontSize(FontSizes.CAPTION)
            .wrap()
    }.spacing(4.vp).crossAxisAlignment(CrossAxisAlignment.Start).hug()
}

// 大字样张：标题大字 + 词句 + 拉丁数字行，整卡随选中字重切换。
private func specimenCard(model: WenkaiModel): Unit {
    let family = model.family()
    Panel {
        VStack {
            Label(SPECIMEN_TITLE).fontSize(44.0).foregroundColor(INK_ACCENT)
            Label(SPECIMEN_POEM).fontSize(19.0).wrap()
            Label(SPECIMEN_LATIN).fontSize(14.0).muted().wrap()
        }
            .spacing(10.vp)
            .crossAxisAlignment(CrossAxisAlignment.Start)
            .hug()
            .textStyle(TextStyle(fontFamily: family, fontWeight: model.weight()))
    }.contentPadding(18.vp)
}

// 字重对比：三行同一句，共享一个字族并指定数值字重，笔画粗细并排可辨。
private func weightCompareCard(): Unit {
    Panel {
        VStack {
            Label("字重对比").fontSize(FontSizes.CAPTION).muted()
            for (weight in WEIGHTS) {
                Label("春风得意马蹄疾 · ${weight.label}")
                    .fontFamily(WENKAI_FAMILY)
                    .fontWeight(weight.value)
                    .fontSize(18.0)
            }
        }.spacing(8.vp).crossAxisAlignment(CrossAxisAlignment.Start).hug()
    }.contentPadding(16.vp)
}

// 等宽变体：代码行与易混字形（0O 1lI）的区分度。
private func monoCard(): Unit {
    Panel {
        VStack {
            Label("等宽变体 ${MONO.label}").fontSize(FontSizes.CAPTION).muted()
            for (line in MONO_LINES) {
                Label(line).fontFamily(WENKAI_MONO).fontSize(14.0).wrap()
            }
        }.spacing(6.vp).crossAxisAlignment(CrossAxisAlignment.Start).hug()
    }.contentPadding(16.vp)
}

private func statusBar(model: WenkaiModel): Unit {
    Panel {
        VStack {
            Label(model.statusText()).fontSize(FontSizes.CAPTION).wrap()
            CanvasWidget(
                {
                    renderer, rect =>
                        let result = renderer.resolveFont(font: WENKAI_FAMILY, style: FontStyle(weight: model.weight()))
                        if (!result.faces.isEmpty()) {
                            let face = result.faces[0]
                            let inner = rect.inset(6.0)
                            renderer.pushClip(inner)
                            try {
                                renderer.text("实际：${face.familyName} / ${face.styleName} / ${face.weight.value}",
                                    inner.x, inner.y, Color.rgb(90, 80, 65), pointSize: FontSizes.CAPTION)
                            } finally {
                                renderer.popClip()
                            }
                        }
                }
            ).height(34.vp)
        }.spacing(4.vp).hug()
    }.contentPadding(12.vp)
}
