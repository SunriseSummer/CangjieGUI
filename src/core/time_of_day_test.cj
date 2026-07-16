package cui.core

@Test
func timeOfDayNormalizesAndWraps(): Unit {
    @Expect(TimeOfDay(14, 30).format(), "14:30")
    @Expect(TimeOfDay(9, 5).format(), "09:05")
    @Expect(TimeOfDay(14, 90).format(), "15:30") // minute overflow carries into the hour
    @Expect(TimeOfDay(25, 0).format(), "01:00") // hour overflow wraps mod 24
    @Expect(TimeOfDay(0, -15).format(), "23:45") // negative wraps back across midnight
    @Expect(TimeOfDay(-1, 0).format(), "23:00")
}

@Test
func timeOfDayTotalMinutes(): Unit {
    @Expect(TimeOfDay(0, 0).totalMinutes(), 0)
    @Expect(TimeOfDay(1, 30).totalMinutes(), 90)
    @Expect(TimeOfDay(23, 59).totalMinutes(), 1439)
}

@Test
func timeOfDayAddingMinutesWraps(): Unit {
    @Expect(TimeOfDay(10, 30).addingMinutes(45), TimeOfDay(11, 15))
    @Expect(TimeOfDay(23, 50).addingMinutes(20), TimeOfDay(0, 10)) // forward across midnight
    @Expect(TimeOfDay(0, 10).addingMinutes(-20), TimeOfDay(23, 50)) // backward across midnight
    @Expect(TimeOfDay(12, 0).addingHours(13), TimeOfDay(1, 0))
}

@Test
func timeOfDayWithHourAndMinute(): Unit {
    @Expect(TimeOfDay(10, 30).withHour(14), TimeOfDay(14, 30))
    @Expect(TimeOfDay(10, 30).withMinute(5), TimeOfDay(10, 5))
    @Expect(TimeOfDay(10, 30).withHour(26), TimeOfDay(2, 30)) // wraps
}

@Test
func timeOfDayFormat12(): Unit {
    @Expect(TimeOfDay(0, 0).format12(), "12:00 AM")
    @Expect(TimeOfDay(9, 5).format12(), "9:05 AM")
    @Expect(TimeOfDay(12, 30).format12(), "12:30 PM")
    @Expect(TimeOfDay(13, 0).format12(), "1:00 PM")
    @Expect(TimeOfDay(23, 45).format12(), "11:45 PM")
}

@Test
func timeOfDayCompareAndEquality(): Unit {
    @Expect(TimeOfDay(9, 0).compareTo(TimeOfDay(10, 0)) < 0)
    @Expect(TimeOfDay(10, 0).compareTo(TimeOfDay(10, 0)), 0)
    @Expect(TimeOfDay(11, 0).compareTo(TimeOfDay(10, 30)) > 0)
    @Expect(TimeOfDay(10, 30) == TimeOfDay(10, 30))
    @Expect(TimeOfDay(10, 30) != TimeOfDay(10, 31))
}
