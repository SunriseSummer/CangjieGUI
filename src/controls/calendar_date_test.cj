package cui.controls

@Test
func calendarDateConstructionClampsToValidDate(): Unit {
    @Expect(CalendarDate(2020, 13, 1).month, 12)
    @Expect(CalendarDate(2020, 0, 5).month, 1)
    // February clamps to the month's real length, leap-aware.
    @Expect(CalendarDate(2021, 2, 30).day, 28)
    @Expect(CalendarDate(2020, 2, 30).day, 29)
    @Expect(CalendarDate(2021, 4, 31).day, 30)
}

@Test
func calendarDateDaysInMonthIsLeapAware(): Unit {
    @Expect(CalendarDate(2020, 2, 1).daysInMonth(), 29)
    @Expect(CalendarDate(2021, 2, 1).daysInMonth(), 28)
    @Expect(CalendarDate(1900, 2, 1).daysInMonth(), 28) // century, not divisible by 400
    @Expect(CalendarDate(2000, 2, 1).daysInMonth(), 29) // divisible by 400
    @Expect(CalendarDate(2021, 1, 1).daysInMonth(), 31)
    @Expect(CalendarDate(2021, 4, 1).daysInMonth(), 30)
}

@Test
func calendarDateWeekdayMatchesKnownDates(): Unit {
    @Expect(CalendarDate(1970, 1, 1).weekdayIndex(), 4) // Thursday
    @Expect(CalendarDate(2000, 1, 1).weekdayIndex(), 6) // Saturday
    @Expect(CalendarDate(2024, 1, 1).weekdayIndex(), 1) // Monday
    // firstWeekdayIndex is the weekday of day 1 of the same month.
    @Expect(CalendarDate(2026, 7, 15).firstWeekdayIndex(), CalendarDate(2026, 7, 1).weekdayIndex())
}

@Test
func calendarDateAddingDaysRollsAcrossBoundaries(): Unit {
    @Expect(CalendarDate(2020, 2, 28).addingDays(1), CalendarDate(2020, 2, 29)) // leap day
    @Expect(CalendarDate(2020, 2, 28).addingDays(2), CalendarDate(2020, 3, 1))
    @Expect(CalendarDate(2019, 12, 31).addingDays(1), CalendarDate(2020, 1, 1)) // year rollover
    @Expect(CalendarDate(2020, 1, 1).addingDays(-1), CalendarDate(2019, 12, 31)) // backward
    @Expect(CalendarDate(2026, 7, 16).addingDays(7).day, 23) // a week later
}

@Test
func calendarDateAddingMonthsClampsDayAndWrapsYear(): Unit {
    @Expect(CalendarDate(2021, 1, 31).addingMonths(1), CalendarDate(2021, 2, 28)) // clamp to Feb
    @Expect(CalendarDate(2020, 1, 31).addingMonths(1), CalendarDate(2020, 2, 29)) // leap clamp
    @Expect(CalendarDate(2020, 12, 15).addingMonths(1), CalendarDate(2021, 1, 15)) // forward year wrap
    @Expect(CalendarDate(2020, 1, 15).addingMonths(-1), CalendarDate(2019, 12, 15)) // backward year wrap
    @Expect(CalendarDate(2020, 6, 10).addingMonths(-8), CalendarDate(2019, 10, 10))
}

@Test
func calendarDateIsoFormatsZeroPadded(): Unit {
    @Expect(CalendarDate(2026, 7, 6).iso(), "2026-07-06")
    @Expect(CalendarDate(2026, 12, 25).iso(), "2026-12-25")
    @Expect(CalendarDate(999, 1, 1).iso(), "0999-01-01")
}

@Test
func calendarDateComparesAndEquals(): Unit {
    @Expect(CalendarDate(2020, 1, 1) == CalendarDate(2020, 1, 1))
    @Expect(CalendarDate(2020, 1, 1) != CalendarDate(2020, 1, 2))
    @Expect(CalendarDate(2020, 1, 1).compareTo(CalendarDate(2020, 1, 2)) < 0)
    @Expect(CalendarDate(2021, 1, 1).compareTo(CalendarDate(2020, 12, 31)) > 0)
    @Expect(CalendarDate(2020, 5, 5).compareTo(CalendarDate(2020, 5, 5)), 0)
}

@Test
func calendarDateWithDayReplacesAndClamps(): Unit {
    @Expect(CalendarDate(2020, 2, 10).withDay(29), CalendarDate(2020, 2, 29))
    @Expect(CalendarDate(2021, 2, 10).withDay(31), CalendarDate(2021, 2, 28)) // clamped
}
