/*
 * 向导状态：当前步骤、各步表单字段，以及步进导航与逐步校验。
 *
 * `StepIndicator` 展示进度，`step` 由 上一步/下一步 按钮驱动、也可点已完成的步节点跳回。每一步有各自的
 * 必填校验（`stepValid`），`canAdvance` 决定“下一步”是否可用；单一数据源，各步字段互不干扰。
 */
package cui_wizard

import cui.State

class WizardModel {
    let steps = WIZARD_STEPS
    let step = State<Int64>(0)
    // 账户
    let email = State<String>("")
    let username = State<String>("")
    // 资料
    let displayName = State<String>("")
    let bio = State<String>("")
    // 偏好
    let theme = State<Int64>(1)
    let newsletter = State<Bool>(true)

    func lastStep(): Int64 {
        steps.size - 1
    }

    func isLast(): Bool {
        step.value >= lastStep()
    }

    /** 某一步是否满足必填校验。 */
    func stepValid(index: Int64): Bool {
        match (index) {
            case 0 => !email.value.trimAscii().isEmpty()
            case 1 => !displayName.value.trimAscii().isEmpty()
            case _ => true
        }
    }

    /** 当前步是否可前进（满足校验且非最后一步）。 */
    func canAdvance(): Bool {
        stepValid(step.value) && !isLast()
    }

    func next(): Unit {
        if (canAdvance()) {
            step.value = step.value + 1
        }
    }

    func back(): Unit {
        if (step.value > 0) {
            step.value = step.value - 1
        }
    }

    /** 跳到第 `index` 步——仅允许回到已完成/当前步（不许跳到未来）。 */
    func goTo(index: Int64): Unit {
        if (index >= 0 && index <= step.value) {
            step.value = index
        }
    }
}
