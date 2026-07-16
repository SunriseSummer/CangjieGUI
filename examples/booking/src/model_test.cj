package cui_booking

import cui.CalendarDate

// 固定的“今天”使派生默认值在不同机器与时钟下保持确定。
private let ANCHOR = CalendarDate(2026, 7, 16)

@Test
func defaultsSpanTwoNightsFromToday(): Unit {
    let model = BookingModel(ANCHOR)
    @Expect(model.checkIn.value, CalendarDate(2026, 7, 16))
    @Expect(model.checkOut.value, CalendarDate(2026, 7, 18))
    @Expect(model.nights.value, 2)
    @Expect(model.isValid.value)
}

@Test
func nightsAndTotalTrackDates(): Unit {
    let model = BookingModel(ANCHOR)
    model.checkOut.value = CalendarDate(2026, 7, 21) // 5 晚
    @Expect(model.nights.value, 5)
    // 标准房默认每晚 380。
    @Expect(model.nightlyRate.value, 380)
    @Expect(model.total.value, 380 * 5)
}

@Test
func roomTypeChangesRateAndTotal(): Unit {
    let model = BookingModel(ANCHOR) // 默认 2 晚
    model.roomType.value = 2 // 套房 → 880
    @Expect(model.nightlyRate.value, 880)
    @Expect(model.total.value, 880 * 2)
}

@Test
func checkoutNotAfterCheckinIsInvalid(): Unit {
    let model = BookingModel(ANCHOR)
    model.checkOut.value = model.checkIn.value // 同日 → 0 晚
    @Expect(!model.isValid.value)
    @Expect(model.nights.value, 0)
    @Expect(model.total.value, 0) // 无效时合计归零

    model.checkOut.value = CalendarDate(2026, 7, 10) // 早于入住 → 跨度为负
    @Expect(!model.isValid.value)
    @Expect(model.nights.value < 0)
}

@Test
func confirmOnlyRecordsWhenValid(): Unit {
    let model = BookingModel(ANCHOR)
    model.checkOut.value = model.checkIn.value // 无效
    model.confirm()
    @Expect(model.confirmation.value.isEmpty()) // 被拒绝

    model.checkOut.value = CalendarDate(2026, 7, 19) // 重新有效（3 晚）
    model.confirm()
    @Expect(model.confirmation.value.contains("3 晚"))
    @Expect(model.confirmation.value.contains("2026-07-16"))
}

@Test
func editingAfterConfirmClearsStaleReceipt(): Unit {
    let model = BookingModel(ANCHOR)
    model.confirm()
    @Expect(!model.confirmation.value.isEmpty())
    // 任何编辑都会作废回执，避免其误表述新的选择。
    model.guests.value = 3
    @Expect(model.confirmation.value.isEmpty())
}
