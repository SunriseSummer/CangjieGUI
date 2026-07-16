/*
 * 目标视图层：标题 + 总完成度环 + 四个目标卡（每卡一个进度环 + 名称 + 当前/目标 + 增减按钮）。
 *
 * 每个环的完成度分数与总完成度都由当前值现算；点 +/- 调整当前值，环随之更新。
 */
package cui_goals

import cui.{Button, ButtonRole, CrossAxisAlignment, FontSizes, Grid, HStack, Label, LengthUnits, Panel, ProgressRing,
    VStack}

func goalsView(model: GoalsModel): Unit {
    VStack {
        header(model)
        Grid(2) {
            for (i in 0..model.goals.size) {
                goalCard(model, i)
            }
        }.spacing(14.vp, 14.vp).flex()
    }.spacing(14.vp).padding(18.vp)
}

func header(model: GoalsModel): Unit {
    HStack {
        VStack {
            Label("每日目标").fontSize(FontSizes.TITLE)
            Label("点 +/- 调整，圆环显示完成度").muted().fontSize(FontSizes.CAPTION)
        }.spacing(3.vp).hug().flex()
        VStack {
            ProgressRing(model.overall(), diameter: 58.0, thickness: 7.0)
            Label("总完成度").muted().fontSize(FontSizes.CAPTION)
        }.spacing(4.vp).crossAxisAlignment(CrossAxisAlignment.Center).hug()
    }.spacing(12.vp).crossAxisAlignment(CrossAxisAlignment.Center).hug()
}

private func goalCard(model: GoalsModel, index: Int64): Unit {
    let goal = model.goals[index]
    Panel {
        VStack {
            ProgressRing(model.fraction(index), diameter: 88.0)
            Label(goal.name).fontSize(FontSizes.BODY)
            Label("${model.current(index)} / ${goal.target} ${goal.unit}").muted().fontSize(FontSizes.CAPTION)
            HStack {
                Button("-", {=> model.bump(index, -1)})
                Button("+", {=> model.bump(index, 1)}).role(ButtonRole.Primary)
            }.spacing(8.vp).hug()
        }.spacing(8.vp).crossAxisAlignment(CrossAxisAlignment.Center).hug()
    }.contentPadding(14.vp)
}
