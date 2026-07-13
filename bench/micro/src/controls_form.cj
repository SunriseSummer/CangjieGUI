/*
 * Scenario: a controls-dense settings form — the shape of a preferences pane. Each section stacks a
 * stepper, switch, radio group, dropdown and button inside a panel, repeated `sections` times. This
 * exercises the interactive controls' layout and draw together, a common per-frame cost that the
 * table / list / text scenes do not cover.
 */
package bench_micro

import cui.{Button, Dropdown, FlowRow, HStack, Label, LengthUnits, Panel, RadioButton, Rect, Spacer, State, Stepper,
    Switch, VStack, Widget}
import bench_harness.{printSection, report, timeit}

public func runControlsFormBench(): Unit {
    printSection("控件密集表单")
    measureForm("12 分区", 12, 200)
    measureForm("40 分区", 40, 60)
}

private func measureForm(name: String, sections: Int64, frames: Int64): Unit {
    let ctx = headlessContext()
    let rect = Rect(0.0, 0.0, 560.0, 720.0)
    let form = settingsForm(sections)
    form.layout(ctx, rect)
    report("frame", "控件密集表单", timeit(name, frames, {=>
        ctx.renderer.beginScene(rect.w, rect.h, ctx.theme.bg)
        form.layout(ctx, rect)
        form.draw(ctx)
        ctx.renderer.endScene()
        0
    }))
}

private func settingsForm(sections: Int64): Widget {
    let notify = State<Bool>(true)
    let priority = State<Int64>(1)
    let minutes = State<Int64>(45)
    let density = State<Int64>(1)
    VStack {
        var i = 0
        while (i < sections) {
            formSection(i, notify, priority, minutes, density)
            i += 1
        }
    }.spacing(12.vp).flexible(false)
}

private func formSection(
    index: Int64,
    notify: State<Bool>,
    priority: State<Int64>,
    minutes: State<Int64>,
    density: State<Int64>
): Unit {
    Panel {
        VStack {
            Label("设置分区 ${index}").fontSize(16.0)
            HStack {
                Label("单次专注分钟数")
                Spacer()
                Stepper("form.min.${index}", minutes).range(15, 120).step(5)
            }.flexible(false)
            Switch("到时桌面通知", notify)
            FlowRow {
                RadioButton("从容", priority, 0)
                RadioButton("平衡", priority, 1)
                RadioButton("冲刺", priority, 2)
            }.spacing(18.vp, 8.vp)
            HStack {
                Label("内容间距")
                Spacer()
                Dropdown("form.dens.${index}", ["紧凑", "舒适", "宽松"], density)
            }.flexible(false)
            Button("保存", {=> ()}).fillWidth()
        }.spacing(10.vp).flexible(false)
    }.contentPadding(16.vp)
}
