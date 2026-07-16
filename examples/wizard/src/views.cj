/*
 * 向导视图层：步骤条 + 当前步表单 + 步进导航。
 *
 *  - 顶部 `StepIndicator` 展示四步进度：已完成打勾、当前高亮、未来置灰；点已完成的步节点可跳回。
 *  - 中部按当前步渲染不同表单；底部 上一步/下一步 驱动前进后退，未通过必填校验时“下一步”禁用。
 *  - 单一数据源：各步字段与当前步都在 model，步骤条、表单、导航皆由其派生。
 */
package cui_wizard

import cui.{Button, ButtonRole, CrossAxisAlignment, FontSizes, HStack, Label, LengthUnits, Panel, SegmentedControl,
    Spacer, StepIndicator, Switch, TextField, VStack}

func wizardView(model: WizardModel): Unit {
    VStack {
        appHeader()
        StepIndicator(model.steps, model.step.value, onSelect: {i => model.goTo(i)})
        Panel {
            stepBody(model)
        }.contentPadding(20.vp).flex()
        navBar(model)
    }.spacing(16.vp).padding(18.vp)
}

func appHeader(): Unit {
    VStack {
        Label("账户设置向导").fontSize(FontSizes.TITLE)
        Label("分步完成设置；上方步骤条显示进度，可点已完成的步骤跳回").muted().fontSize(FontSizes.CAPTION)
    }.spacing(2.vp).hug()
}

func stepBody(model: WizardModel): Unit {
    match (model.step.value) {
        case 0 => accountStep(model)
        case 1 => profileStep(model)
        case 2 => preferencesStep(model)
        case _ => doneStep(model)
    }
}

func navBar(model: WizardModel): Unit {
    HStack {
        Button("上一步", {=> model.back()}).enabled(model.step.value > 0)
        Spacer()
        if (model.isLast()) {
            Button("重新开始", {=> model.goTo(0)})
        }
        if (!model.isLast()) {
            Button(advanceLabel(model.step.value, model.lastStep()), {=> model.next()}).role(ButtonRole.Primary)
                .enabled(model.canAdvance())
        }
    }.crossAxisAlignment(CrossAxisAlignment.Center).hug()
}

func accountStep(model: WizardModel): Unit {
    VStack {
        Label("创建你的账户").fontSize(FontSizes.BODY)
        formField("邮箱（必填）") {=> TextField(model.email)}
        formField("用户名") {=> TextField(model.username)}
        if (!model.stepValid(0)) {
            Label("请填写邮箱以继续").foregroundColor(WIZARD_DANGER).fontSize(FontSizes.CAPTION)
        }
    }.spacing(14.vp)
}

func profileStep(model: WizardModel): Unit {
    VStack {
        Label("完善资料").fontSize(FontSizes.BODY)
        formField("显示名称（必填）") {=> TextField(model.displayName)}
        formField("一句话简介") {=> TextField(model.bio)}
        if (!model.stepValid(1)) {
            Label("请填写显示名称以继续").foregroundColor(WIZARD_DANGER).fontSize(FontSizes.CAPTION)
        }
    }.spacing(14.vp)
}

func preferencesStep(model: WizardModel): Unit {
    VStack {
        Label("偏好设置").fontSize(FontSizes.BODY)
        formField("主题") {=> SegmentedControl(THEME_LABELS, model.theme)}
        Switch("订阅产品资讯", model.newsletter)
    }.spacing(14.vp)
}

func doneStep(model: WizardModel): Unit {
    VStack {
        Label("全部完成！").fontSize(FontSizes.TITLE)
        Label("即将为你创建账户，请确认信息：").muted()
        summaryRow("邮箱", model.email.value)
        summaryRow("显示名称", model.displayName.value)
        summaryRow("主题", themeLabel(model.theme.value))
        summaryRow("订阅资讯", subscribeLabel(model.newsletter.value))
    }.spacing(8.vp)
}

func formField(label: String, control: () -> Unit): Unit {
    VStack {
        Label(label).muted().fontSize(FontSizes.CAPTION)
        control()
    }.spacing(4.vp).hug()
}

func summaryRow(label: String, value: String): Unit {
    HStack {
        Label(label).muted().width(80.vp)
        Label(value)
    }.spacing(8.vp).hug()
}

func subscribeLabel(on: Bool): String {
    if (on) {
        "是"
    } else {
        "否"
    }
}
