/*
 * 时间轴状态：一条从今天前 30 天起、长 400 天的日期带，以及当前选中的位置。
 *
 * 日期带用 `LazyRow` 虚拟化——400 个日格只物化视口附近的十几个，滚动成本恒为一屏。每个格子的日期由
 * `start.addingDays(i)` 即时算出，无需预生成整表。今天由入口传入，使模型逻辑可确定性地测试。
 */
package cui_timeline

import cui.{CalendarDate, State}

let TIMELINE_DAYS: Int64 = 400
let TIMELINE_LEAD: Int64 = 30 // 起点在今天之前的天数（今天的下标即 TIMELINE_LEAD）
// 日格宽度与间距，模型据此算出让今天开箱可见的初始滚动量；视图渲染 LazyRow 时也用它们，故集中定义。
let TIMELINE_CELL_W: Float32 = 60.0
let TIMELINE_SPACING: Float32 = 6.0

class TimelineModel {
    let today: CalendarDate
    let start: CalendarDate
    let count = TIMELINE_DAYS
    let selected: State<Int64>
    // LazyRow 的横向滚动偏移由模型持有，故可初始化到今天、并被“回到今天”复位。
    let scroll: State<Float32>

    init(today: CalendarDate) {
        this.today = today
        this.start = today.addingDays(-TIMELINE_LEAD)
        this.selected = State<Int64>(TIMELINE_LEAD) // 默认选中今天
        this.scroll = State<Float32>(todayScrollOffset())
    }

    /** 第 `index` 个格子对应的日期。 */
    func dateAt(index: Int64): CalendarDate {
        start.addingDays(clampIndex(index))
    }

    func selectedDate(): CalendarDate {
        dateAt(selected.value)
    }

    /** 今天在日期带中的下标。 */
    func todayIndex(): Int64 {
        TIMELINE_LEAD
    }

    /** 选中日期相对今天的天数（正为未来、负为过去）。 */
    func selectedDelta(): Int64 {
        selectedDate().compareTo(today)
    }

    /** 回到今天：选中今天并把日期带滚回今天位置。 */
    func backToToday(): Unit {
        selected.value = todayIndex()
        scroll.value = todayScrollOffset()
    }

    private func clampIndex(index: Int64): Int64 {
        if (index < 0) {
            0
        } else if (index >= count) {
            count - 1
        } else {
            index
        }
    }
}

// 让今天落在日期带左缘向内两格处的滚动量，使其开屏可见。写成自由函数（而非方法），
// 使 `init` 在全部字段就绪前即可调用；它只依赖常量。
func todayScrollOffset(): Float32 {
    Float32(max(0, TIMELINE_LEAD - 2)) * (TIMELINE_CELL_W + TIMELINE_SPACING)
}
