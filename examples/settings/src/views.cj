/*
 * 设置视图层：抬头（含单开开关）+ 折叠面板设置分区。
 *
 *  - 用 `Accordion` 把设置分成外观/通知/隐私/关于四个可折叠分区，点击标题或聚焦后 Enter/Space 展开收起。
 *  - 每个分区体内是真实控件（分段/滑块/开关/复选/单选/按钮），只在展开时构建，绑定到模型字段。
 *  - 抬头的“单开模式”开关驱动 `Accordion` 的 `single`：开启后展开一个分区会自动收起其它分区。
 */
package cui_settings

import cui.{Accordion, AccordionSection, Button, ButtonRole, Checkbox, CrossAxisAlignment, FontSizes, HStack, Label,
    LengthUnits, Panel, RadioButton, ScrollView, SegmentedControl, Slider, Spacer, Switch, VStack}

func settingsView(model: SettingsModel): Unit {
    VStack {
        appHeader(model)
        Panel {
            ScrollView {
                Accordion([
                    AccordionSection("外观") {=> appearanceBody(model)},
                    AccordionSection("通知") {=> notifyBody(model)},
                    AccordionSection("隐私") {=> privacyBody(model)},
                    AccordionSection("关于") {=> aboutBody(model)}
                ], single: model.singleMode.value, initiallyExpanded: [0])
            }
        }.contentPadding(8.vp).flex()
    }.spacing(12.vp).padding(16.vp)
}

func appHeader(model: SettingsModel): Unit {
    HStack {
        VStack {
            Label("设置").fontSize(FontSizes.TITLE)
            Label(model.summary.value).muted().fontSize(FontSizes.CAPTION)
        }.spacing(2.vp).hug()
        Spacer()
        Switch("单开模式", model.singleMode)
    }.crossAxisAlignment(CrossAxisAlignment.Center).hug()
}

// A padded body under a section header, indented from the header's chevron.
func sectionBody(content: () -> Unit): Unit {
    VStack {
        content()
    }.spacing(10.vp).padding(22.0, 6.0, 16.0, 14.0)
}

func settingRow(label: String, control: () -> Unit): Unit {
    HStack {
        Label(label).width(72.vp)
        control()
        Spacer()
    }.spacing(12.vp).crossAxisAlignment(CrossAxisAlignment.Center).hug()
}

func appearanceBody(model: SettingsModel): Unit {
    sectionBody {
        =>
        settingRow("主题") {=> SegmentedControl(THEME_LABELS, model.theme)}
        settingRow("字号") {=> Slider(model.fontScale, lower: 0.8, upper: 1.4)}
        Label("当前字号 ${model.fontPercent()} %").muted().fontSize(FontSizes.CAPTION)
    }
}

func notifyBody(model: SettingsModel): Unit {
    sectionBody {
        =>
        Switch("启用通知", model.notifyEnabled)
        Switch("声音提醒", model.notifySound)
        Switch("消息预览", model.notifyPreview)
    }
}

func privacyBody(model: SettingsModel): Unit {
    sectionBody {
        =>
        Checkbox("发送匿名使用统计", model.analytics)
        Label("数据共享范围").muted().fontSize(FontSizes.CAPTION)
        // 选项文案取自 SHARING_LABELS 单一来源，与头部摘要派生共用，避免两处文案漂移。
        for (i in 0..SHARING_LABELS.size) {
            RadioButton(SHARING_LABELS[i], model.dataSharing, i)
        }
    }
}

func aboutBody(_: SettingsModel): Unit {
    sectionBody {
        =>
        Label("CUI 桌面 GUI 框架")
        Label("版本 0.2.0 · 组件 52").muted().fontSize(FontSizes.CAPTION)
        Button("检查更新", {=> ()}).role(ButtonRole.Primary)
    }
}
