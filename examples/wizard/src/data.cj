/*
 * 向导示例的步骤名与选项文案（纯函数）。
 */
package cui_wizard

let WIZARD_STEPS: Array<String> = ["账户", "资料", "偏好", "完成"]
let THEME_LABELS: Array<String> = ["浅色", "深色", "跟随系统"]

func themeLabel(index: Int64): String {
    if (index >= 0 && index < THEME_LABELS.size) {
        THEME_LABELS[index]
    } else {
        THEME_LABELS[0]
    }
}

/** 前进按钮文案：进入最后一步前是“提交”，否则“下一步”。 */
func advanceLabel(step: Int64, lastStep: Int64): String {
    if (step == lastStep - 1) {
        "提交"
    } else {
        "下一步"
    }
}
