/*
 * A controls-dense settings page — the shape of a preferences pane, and the scene that most exercises
 * the interactive controls' geometry (switch knobs, radio dots and slider thumbs are drawn as circles;
 * panels and buttons as rounded rects). It is deliberately unwindowed (a plain ScrollView), so every
 * section's geometry is submitted each frame regardless of scroll — the honest worst case for
 * per-frame shape tessellation, and the counterpart to the content-page scene for panels/shadows.
 */
package bench_scenes

import cui.{Button, Dropdown, FlowRow, HStack, Label, LengthUnits, Panel, RadioButton, ScrollView, Slider, Spacer,
    State, Stepper, Switch, VStack, Widget}

/** Builds the scrollable settings page over `sections` repeated control groups, bound to `scroll`. */
public func controlsFormScene(scroll: State<Float32>, sections: Int64): Widget {
    let notify = State<Bool>(true)
    let priority = State<Int64>(1)
    let minutes = State<Int64>(45)
    let density = State<Int64>(1)
    let volume = State<Float32>(0.6)
    let view = ScrollView(key: "bench.controls") {
        VStack {
            var i = 0
            while (i < sections) {
                controlsSection(i, notify, priority, minutes, density, volume)
                i += 1
            }
        }.spacing(12.vp).flexible(false)
    }
    view.scrollState(scroll)
    view
}

private func controlsSection(
    index: Int64,
    notify: State<Bool>,
    priority: State<Int64>,
    minutes: State<Int64>,
    density: State<Int64>,
    volume: State<Float32>
): Unit {
    Panel {
        VStack {
            Label("设置分区 ${index}").fontSize(16.0)
            HStack {
                Label("单次专注分钟数")
                Spacer()
                Stepper(minutes, key: "form.min.${index}").range(15, 120).step(5)
            }.flexible(false)
            Switch("到时桌面通知", notify)
            FlowRow {
                RadioButton("从容", priority, 0)
                RadioButton("平衡", priority, 1)
                RadioButton("冲刺", priority, 2)
            }.spacing(18.vp, 8.vp)
            HStack {
                Label("提示音量")
                Spacer()
                Slider(volume, key: "form.vol.${index}").width(200.vp)
            }.flexible(false)
            HStack {
                Label("内容间距")
                Spacer()
                Dropdown(["紧凑", "舒适", "宽松"], density, key: "form.dens.${index}")
            }.flexible(false)
            Button("保存", {=> ()}).fillWidth()
        }.spacing(10.vp).flexible(false)
    }.contentPadding(16.vp)
}
