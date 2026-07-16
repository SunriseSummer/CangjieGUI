/*
 * 时间轴示例的星期名与日期文案（纯函数）。日期运算全部委托给框架的 `CalendarDate`。
 */
package cui_timeline

import cui.CalendarDate

// weekdayIndex 约定 0=周日..6=周六，与下表下标一致。
let WEEKDAYS_SHORT: Array<String> = ["日", "一", "二", "三", "四", "五", "六"]
let WEEKDAYS_FULL: Array<String> = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]

func weekdayShort(date: CalendarDate): String {
    WEEKDAYS_SHORT[date.weekdayIndex()]
}

func weekdayFull(date: CalendarDate): String {
    WEEKDAYS_FULL[date.weekdayIndex()]
}

/** 相对今天的措辞：0 为今天，正为未来，负为过去。 */
func relativeLabel(deltaDays: Int64): String {
    if (deltaDays == 0) {
        "今天"
    } else if (deltaDays > 0) {
        "${deltaDays} 天后"
    } else {
        "${-deltaDays} 天前"
    }
}
