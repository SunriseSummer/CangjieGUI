/*
 * 目标状态：各目标的当前值（按下标对应 GOALS）。
 *
 * 每个目标的完成度分数与总完成度都是当前值的纯函数派生；+/- 按步长增减、下限为 0。
 */
package cui_goals

import cui.State

class GoalsModel {
    let goals: Array<Goal> = GOALS
    let currents: State<Array<Int64>>

    init() {
        this.currents = State<Array<Int64>>([5200, 6, 9, 75])
    }

    func current(index: Int64): Int64 {
        currents.value[index]
    }

    // 第 index 个目标的完成度分数（0..1）。
    func fraction(index: Int64): Float32 {
        goalFraction(currents.value[index], goals[index].target)
    }

    // 总完成度（各目标平均）。
    func overall(): Float32 {
        overallFraction(currents.value, goals)
    }

    // 按步长增减第 index 个目标的当前值，下限为 0。
    func bump(index: Int64, direction: Int64): Unit {
        let next = max(0, currents.value[index] + direction * goals[index].step)
        currents.value = withUpdatedInt(currents.value, index, next)
    }
}
