/*
 * 设置示例的选项文案与其取值到文字的映射（纯函数）。
 */
package cui_settings

let THEME_LABELS: Array<String> = ["浅色", "深色", "跟随系统"]
let SHARING_LABELS: Array<String> = ["不共享", "仅崩溃日志", "完整诊断"]

func themeLabel(index: Int64): String {
    labelAt(THEME_LABELS, index)
}

func sharingLabel(index: Int64): String {
    labelAt(SHARING_LABELS, index)
}

private func labelAt(labels: Array<String>, index: Int64): String {
    if (index >= 0 && index < labels.size) {
        labels[index]
    } else {
        labels[0]
    }
}
