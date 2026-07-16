/*
 * 每日目标示例的类型化数据与纯统计（完成度分数、总完成度、数值更新）。
 *
 * 完成度分数、总完成度都是当前值与目标的纯函数，便于单测且与视图无关。
 */
package cui_goals

import std.collection.ArrayList

// 一个每日目标（名称、单位、目标值、每次增减步长）。
struct Goal {
    let name: String
    let unit: String
    let target: Int64
    let step: Int64

    init(name: String, unit: String, target: Int64, step: Int64) {
        this.name = name
        this.unit = unit
        this.target = target
        this.step = step
    }
}

let GOALS: Array<Goal> = [
    Goal("步数", "步", 8000, 500),
    Goal("饮水", "杯", 8, 1),
    Goal("站立", "小时", 12, 1),
    Goal("专注", "分钟", 120, 15)
]

// 完成度分数 current/target，钳到 0..1（超额也记满环）。
func goalFraction(current: Int64, target: Int64): Float32 {
    if (target <= 0) {
        return 0.0
    }
    let f = Float32(current) / Float32(target)
    if (f > 1.0) {
        1.0
    } else if (f < 0.0) {
        0.0
    } else {
        f
    }
}

// 总完成度：各目标完成度分数的平均。
func overallFraction(currents: Array<Int64>, goals: Array<Goal>): Float32 {
    if (goals.size == 0) {
        return 0.0
    }
    var sum: Float32 = 0.0
    var i = 0
    while (i < goals.size) {
        sum += goalFraction(currents[i], goals[i].target)
        i += 1
    }
    sum / Float32(goals.size)
}

// 返回把下标 index 处数值替换为 value 的新数组。
func withUpdatedInt(arr: Array<Int64>, index: Int64, value: Int64): Array<Int64> {
    let out = ArrayList<Int64>()
    for (i in 0..arr.size) {
        if (i == index) {
            out.add(value)
        } else {
            out.add(arr[i])
        }
    }
    out.toArray()
}
