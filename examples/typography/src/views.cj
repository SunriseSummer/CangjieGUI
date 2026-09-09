/*
 * 字体样式视图层：标题 + 样式开关 Chip 行 + 实时字号阶梯 + 静态样式参考卡 + 页脚摘要。
 *
 * 字号阶梯每档与页脚摘要都由当前样式现算；点顶部 Chip 切换样式，阶梯与摘要随之更新。
 * 参考卡固定展示各样式的样子，不随开关变化，作为对照。
 */
package cui_typography

import cui.{Chip, CrossAxisAlignment, Divider, FontSizes, HStack, Label, LengthUnits, Panel, ScrollView, Spacer, VStack,
    FontStyle, FontWeight, TextStyle}

// 阶梯与参考卡共用的示范文本：中西混排，验证同一样式对两种脚本一致生效。
private let SPECIMEN = "永远滚烫 The quick brown fox"

func typographyView(model: TypographyModel): Unit {
    ScrollView {
        VStack {
            header()
            toolbar(model)
            inheritancePanel(model)
            livePanel(model)
            referencePanel()
            footer(model)
        }.spacing(16.vp).padding(22.vp)
    }
}

private func header(): Unit {
    VStack {
        Label("字体样式").fontSize(FontSizes.TITLE).bold()
        Label("真实字体面优先；字重、倾斜、装饰独立继承，缺失样式按策略合成").muted().fontSize(FontSizes.CAPTION)
    }.spacing(4.vp).crossAxisAlignment(CrossAxisAlignment.Start).hug()
}

// 四个样式开关，直接绑定模型各 State（State 即 Bindable<Bool>）。
private func toolbar(model: TypographyModel): Unit {
    HStack {
        Chip("粗体", model.bold, key: "chip-bold")
        Chip("斜体", model.italic, key: "chip-italic")
        Chip("下划线", model.underline, key: "chip-underline")
        Chip("删除线", model.strikethrough, key: "chip-strike")
        Spacer()
    }.spacing(8.vp).crossAxisAlignment(CrossAxisAlignment.Center).hug()
}

// 实时字号阶梯：每档以当前合成样式渲染同一示范文本，档名与字号在上方小字标注。
private func livePanel(model: TypographyModel): Unit {
    let style = model.style()
    Panel {
        VStack {
            Label("实时预览").muted().fontSize(FontSizes.CAPTION)
            for (step in TYPE_SCALE) {
                VStack {
                    Label(stepCaption(step)).muted().fontSize(FontSizes.CAPTION)
                    Label(SPECIMEN).fontSize(step.size).fontStyle(style).maxLines(1)
                }.spacing(2.vp).crossAxisAlignment(CrossAxisAlignment.Start).hug()
            }
        }.spacing(12.vp).crossAxisAlignment(CrossAxisAlignment.Start).hug()
    }.contentPadding(16.vp)
}

// 静态样式参考卡：每行左侧样式名，右侧以该样式渲染同一短语，作为对照（不随开关变化）。
private func referencePanel(): Unit {
    Panel {
        VStack {
            Label("样式参考").muted().fontSize(FontSizes.CAPTION)
            for (sample in STYLE_REFERENCE) {
                referenceRow(sample)
            }
        }.spacing(10.vp).crossAxisAlignment(CrossAxisAlignment.Start).hug()
    }.contentPadding(16.vp)
}

private func referenceRow(sample: StyleSample): Unit {
    HStack {
        Label(sample.label).muted().fontSize(FontSizes.CAPTION).width(150.vp)
        Label("样张 Almost before we knew it").fontStyle(sample.style)
        Spacer()
    }.spacing(12.vp).crossAxisAlignment(CrossAxisAlignment.Center).hug()
}

private func footer(model: TypographyModel): Unit {
    VStack {
        Divider()
        Label("当前样式：${model.summary()}").muted().fontSize(FontSizes.CAPTION)
    }.spacing(8.vp).crossAxisAlignment(CrossAxisAlignment.Start).hug()
}

// 独立构建器只覆盖一项；fontStyle 明确表示整组替换。
private func inheritancePanel(model: TypographyModel): Unit {
    Panel {
        VStack {
            Label("继承与局部覆盖").fontWeight(FontWeight.semiBold)
            VStack {
                Label("完全继承上方四个开关").wrap()
                Label("只设字重 400，保留倾斜和装饰").fontWeight(FontWeight.normal).wrap()
                Label("只取消斜体，保留字重和装饰").italic(value: false).wrap()
                Label("显式整组重置：regular").fontStyle(FontStyle.regular).wrap()
            }.spacing(8.vp).textStyle(TextStyle(fontSize: 18.fp, fontStyle: model.style()))
        }.spacing(10.vp).hug()
    }.contentPadding(16.vp)
}
