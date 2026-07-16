/*
 * 预订状态：入住/退房日期、房型、人数，以及全部由它们派生的晚数、单价、合计与有效性。
 *
 * 两个 `DatePicker` 绑定到 `checkIn`/`checkOut`，其余展示项都是 `derive` 的结果，编辑即刻联动。
 * `today` 由入口传入（而非模型内部读时钟），使模型可在测试中以固定日期确定性地构造。
 */
package cui_booking

import cui.{CalendarDate, DerivedState, State, derive}

class BookingModel {
    let checkIn: State<CalendarDate>
    let checkOut: State<CalendarDate>
    let roomType = State<Int64>(0)
    let guests = State<Int64>(2)
    let nights: DerivedState<Int64>
    let nightlyRate: DerivedState<Int64>
    let total: DerivedState<Int64>
    let isValid: DerivedState<Bool>
    // 确认后写入的回执文案；空串表示尚未确认。
    let confirmation = State<String>("")

    init(today: CalendarDate) {
        this.checkIn = State<CalendarDate>(today)
        this.checkOut = State<CalendarDate>(today.addingDays(2))
        this.nights = derive(this.checkIn, this.checkOut, {ci, co => nightsBetween(ci, co)})
        this.nightlyRate = this.roomType.map({t => rateFor(t)})
        this.total = derive(this.nights, this.nightlyRate, {n, r => if (n > 0) {
            n * r
        } else {
            0
        }})
        this.isValid = this.nights.map({n => n > 0})
        // 编辑任一输入即作废上一次回执，避免与新选择不一致的陈旧信息残留。
        let _ = this.checkIn.observe({_, _ => this.invalidateConfirmation()})
        let _ = this.checkOut.observe({_, _ => this.invalidateConfirmation()})
        let _ = this.roomType.observe({_, _ => this.invalidateConfirmation()})
        let _ = this.guests.observe({_, _ => this.invalidateConfirmation()})
    }

    /** 提交预订：仅当日期有效时写入回执，否则不动。 */
    func confirm(): Unit {
        if (!isValid.value) {
            return
        }
        let range = "${checkIn.value.iso()} 至 ${checkOut.value.iso()}"
        let detail = "${nights.value} 晚 · ${guests.value} 人 · 合计 ${money(total.value)}"
        confirmation.value = "已预订 ${roomTypeName(roomType.value)} · ${range} · ${detail}"
    }

    /** 编辑任何字段后作废上一次回执，避免陈旧信息。 */
    func invalidateConfirmation(): Unit {
        if (!confirmation.value.isEmpty()) {
            confirmation.value = ""
        }
    }
}
