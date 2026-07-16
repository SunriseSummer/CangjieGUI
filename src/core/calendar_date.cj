package cui.core

import sdl.system.Time

/**
 * A calendar day — year, month (1–12) and day (1–31) — with no time-of-day or zone. It is the value a
 * `DatePicker` binds to. Construction always yields a valid date: the month is clamped into 1–12 and
 * the day into the resulting month's length, so a `DatePicker` can never produce (or be seeded with)
 * an impossible date such as February 30.
 *
 * The calendar arithmetic (leap years, month lengths, weekday, day offsets) is computed directly from
 * the proleptic Gregorian calendar rather than the platform clock, so it is pure and deterministic;
 * only `today()` reads the system clock.
 */
public struct CalendarDate <: Equatable<CalendarDate> {
    public let year: Int64
    public let month: Int64
    public let day: Int64

    public init(year: Int64, month: Int64, day: Int64) {
        let m = clampInt(month, 1, 12)
        this.year = year
        this.month = m
        this.day = clampInt(day, 1, daysInGregorianMonth(year, m))
    }

    /** Today's date from the system clock. Throws `CuiException` if the clock cannot be read. */
    public static func today(): CalendarDate {
        let now = Time.currentDateTime()
        CalendarDate(Int64(now.year), Int64(now.month), Int64(now.day))
    }

    /** The number of days in this date's month (Gregorian, leap-aware). */
    public func daysInMonth(): Int64 {
        daysInGregorianMonth(year, month)
    }

    /** Weekday of this date: 0 = Sunday through 6 = Saturday. */
    public func weekdayIndex(): Int64 {
        weekdayFromEpochDay(toEpochDay(year, month, day))
    }

    /** Weekday of the first of this date's month: 0 = Sunday through 6 = Saturday. */
    public func firstWeekdayIndex(): Int64 {
        weekdayFromEpochDay(toEpochDay(year, month, 1))
    }

    /** This date with the day replaced (clamped into the month), keeping year and month. */
    public func withDay(newDay: Int64): CalendarDate {
        CalendarDate(year, month, newDay)
    }

    /** This date shifted by `delta` whole months; the day is clamped to the target month's length. */
    public func addingMonths(delta: Int64): CalendarDate {
        // Convert to a zero-based month ordinal so negative deltas wrap the year correctly.
        let ordinal = year * 12 + (month - 1) + delta
        let newYear = floorDiv(ordinal, 12)
        let newMonth = ordinal - newYear * 12 + 1
        CalendarDate(newYear, newMonth, day)
    }

    /** This date shifted by `delta` whole days, rolling across months and years exactly. */
    public func addingDays(delta: Int64): CalendarDate {
        fromEpochDay(toEpochDay(year, month, day) + delta)
    }

    /** ISO-8601 `YYYY-MM-DD`, zero-padded. */
    public func iso(): String {
        "${pad4(year)}-${pad2(month)}-${pad2(day)}"
    }

    /** Negative when this date precedes `other`, zero when equal, positive when it follows. */
    public func compareTo(other: CalendarDate): Int64 {
        toEpochDay(year, month, day) - toEpochDay(other.year, other.month, other.day)
    }

    public operator func ==(other: CalendarDate): Bool {
        year == other.year && month == other.month && day == other.day
    }

    public operator func !=(other: CalendarDate): Bool {
        !(this == other)
    }
}

private func clampInt(value: Int64, low: Int64, high: Int64): Int64 {
    if (value < low) {
        low
    } else if (value > high) {
        high
    } else {
        value
    }
}

// Floor division (rounds toward negative infinity), so month/day rollover is correct for dates before
// the common era as well as after — the built-in `/` truncates toward zero.
private func floorDiv(a: Int64, b: Int64): Int64 {
    let q = a / b
    if ((a % b != 0) && ((a < 0) != (b < 0))) {
        q - 1
    } else {
        q
    }
}

private func isLeapYear(year: Int64): Bool {
    (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
}

private func daysInGregorianMonth(year: Int64, month: Int64): Int64 {
    match (month) {
        case 1 | 3 | 5 | 7 | 8 | 10 | 12 => 31
        case 4 | 6 | 9 | 11 => 30
        case _ => if (isLeapYear(year)) {
            29
        } else {
            28
        }
    }
}

/*
 * Days since 1970-01-01 (Howard Hinnant's civil-from-days algorithm, valid across the whole proleptic
 * Gregorian range). Paired with fromEpochDay, this gives exact day arithmetic and a weekday with no
 * dependence on the platform clock.
 */
private func toEpochDay(year: Int64, month: Int64, day: Int64): Int64 {
    let y = if (month <= 2) {
        year - 1
    } else {
        year
    }
    let era = if (y >= 0) {
        y
    } else {
        y - 399
    } / 400
    let yoe = y - era * 400
    let mp = if (month > 2) {
        month - 3
    } else {
        month + 9
    }
    let doy = (153 * mp + 2) / 5 + day - 1
    let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
    era * 146097 + doe - 719468
}

private func fromEpochDay(epochDay: Int64): CalendarDate {
    let z = epochDay + 719468
    let era = if (z >= 0) {
        z
    } else {
        z - 146096
    } / 146097
    let doe = z - era * 146097
    let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365
    let y = yoe + era * 400
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
    let mp = (5 * doy + 2) / 153
    let day = doy - (153 * mp + 2) / 5 + 1
    let month = if (mp < 10) {
        mp + 3
    } else {
        mp - 9
    }
    let year = if (month <= 2) {
        y + 1
    } else {
        y
    }
    CalendarDate(year, month, day)
}

// 1970-01-01 was a Thursday; with Sunday as 0 that is index 4, so offset the epoch day by 4 and take a
// non-negative modulo.
private func weekdayFromEpochDay(epochDay: Int64): Int64 {
    ((epochDay + 4) % 7 + 7) % 7
}

private func pad2(value: Int64): String {
    if (value >= 0 && value < 10) {
        "0${value}"
    } else {
        "${value}"
    }
}

private func pad4(value: Int64): String {
    if (value < 0) {
        return "${value}"
    }
    if (value < 10) {
        "000${value}"
    } else if (value < 100) {
        "00${value}"
    } else if (value < 1000) {
        "0${value}"
    } else {
        "${value}"
    }
}
