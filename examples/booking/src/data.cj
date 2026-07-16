/*
 * 预订示例的纯数据与计算：房型与价目、两日期间的晚数、金额格式化。
 *
 * 晚数直接用 `CalendarDate.compareTo` 得到——它返回两日期相差的天数，恰是入住到退房的晚数；
 * 因此“退房须晚于入住”这条校验也退化为“晚数为正”，无需另写日期比较。
 */
package cui_booking

import cui.CalendarDate

let ROOM_TYPES: Array<String> = ["标准间", "大床房", "套房"]

/** 房型每晚价格（元）。 */
func rateFor(roomType: Int64): Int64 {
    match (roomType) {
        case 1 => 520
        case 2 => 880
        case _ => 380
    }
}

/** 入住到退房的晚数：两日期相差的天数，非正表示退房不晚于入住。 */
func nightsBetween(checkIn: CalendarDate, checkOut: CalendarDate): Int64 {
    checkOut.compareTo(checkIn)
}

/** 安全取房型名称，越界回退到第一项。 */
func roomTypeName(roomType: Int64): String {
    if (roomType >= 0 && roomType < ROOM_TYPES.size) {
        ROOM_TYPES[roomType]
    } else {
        ROOM_TYPES[0]
    }
}

func money(amount: Int64): String {
    "¥${amount}"
}
