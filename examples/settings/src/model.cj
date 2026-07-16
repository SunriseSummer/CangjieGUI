/*
 * 设置状态：各分区的开关、选择与滑块，以及由它们派生的一句话摘要。
 *
 * 每个字段是单一数据源，被折叠面板各分区里的控件双向绑定；摘要由若干字段 `derive` 得到，改动即刻反映。
 * `singleMode` 控制折叠面板是否“单开”（手风琴模式），传给 `Accordion` 的 `single` 参数。
 */
package cui_settings

import cui.{DerivedState, State, derive}

class SettingsModel {
    // 外观
    let theme = State<Int64>(1) // 深色
    let fontScale = State<Float32>(1.0)
    // 通知
    let notifyEnabled = State<Bool>(true)
    let notifySound = State<Bool>(false)
    let notifyPreview = State<Bool>(true)
    // 隐私
    let analytics = State<Bool>(true)
    let dataSharing = State<Int64>(1) // 仅崩溃日志
    // 折叠面板是否单开
    let singleMode = State<Bool>(false)

    let summary: DerivedState<String>

    init() {
        this.summary = derive(this.theme, this.dataSharing, {t, s => "${themeLabel(t)} · 共享：${sharingLabel(s)}"})
    }

    /** 字号百分比整数（用于展示）。 */
    func fontPercent(): Int64 {
        Int64(fontScale.value * 100.0 + 0.5)
    }
}
