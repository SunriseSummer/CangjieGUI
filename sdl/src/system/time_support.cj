/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package sdl.system

import sdl.{CuiException, lastSdlError, SDL_DATE_FORMAT_DDMMYYYY, SDL_DATE_FORMAT_MMDDYYYY, SDL_DATE_FORMAT_YYYYMMDD, 
    SDL_TIME_FORMAT_12HR, SDL_TIME_FORMAT_24HR, SdlDateTime}

internal func dateFormatFromCode(code: Int32): DateFormat {
    if (code == SDL_DATE_FORMAT_YYYYMMDD) {
        DateFormat.YearMonthDay
    } else if (code == SDL_DATE_FORMAT_DDMMYYYY) {
        DateFormat.DayMonthYear
    } else if (code == SDL_DATE_FORMAT_MMDDYYYY) {
        DateFormat.MonthDayYear
    } else {
        DateFormat.UnknownDateFormat(code)
    }
}

internal func clockFormatFromCode(code: Int32): ClockFormat {
    if (code == SDL_TIME_FORMAT_24HR) {
        ClockFormat.TwentyFourHour
    } else if (code == SDL_TIME_FORMAT_12HR) {
        ClockFormat.TwelveHour
    } else {
        ClockFormat.UnknownClockFormat(code)
    }
}

internal func weekdayFromCode(code: Int32): ?Weekday {
    if (code == 0) {
        Some(Weekday.Sunday)
    } else if (code == 1) {
        Some(Weekday.Monday)
    } else if (code == 2) {
        Some(Weekday.Tuesday)
    } else if (code == 3) {
        Some(Weekday.Wednesday)
    } else if (code == 4) {
        Some(Weekday.Thursday)
    } else if (code == 5) {
        Some(Weekday.Friday)
    } else if (code == 6) {
        Some(Weekday.Saturday)
    } else {
        None
    }
}

internal func weekdayCode(weekday: ?Weekday): Int32 {
    match (weekday) {
        case Some(value) => match (value) {
            case Weekday.Sunday => 0
            case Weekday.Monday => 1
            case Weekday.Tuesday => 2
            case Weekday.Wednesday => 3
            case Weekday.Thursday => 4
            case Weekday.Friday => 5
            case Weekday.Saturday => 6
        }
        case None => 0
    }
}

internal func dateTimeFromRaw(raw: SdlDateTime): DateTimeParts {
    var parts = DateTimeParts()
    parts.year = raw.year
    parts.month = raw.month
    parts.day = raw.day
    parts.hour = raw.hour
    parts.minute = raw.minute
    parts.second = raw.second
    parts.nanosecond = raw.nanosecond
    parts.dayOfWeek = weekdayFromCode(raw.dayOfWeek)
    parts.utcOffsetSeconds = raw.utcOffset
    parts
}

internal func dateTimeToRaw(parts: DateTimeParts): SdlDateTime {
    var raw = SdlDateTime()
    raw.year = parts.year
    raw.month = parts.month
    raw.day = parts.day
    raw.hour = parts.hour
    raw.minute = parts.minute
    raw.second = parts.second
    raw.nanosecond = parts.nanosecond
    raw.dayOfWeek = weekdayCode(parts.dayOfWeek)
    raw.utcOffset = parts.utcOffsetSeconds
    raw
}

/**
 * Throws `CuiException` when SDL reports a negative result.
 */
internal func ensureNonNegative(value: Int32, api: String): Int32 {
    if (value < 0) {
        throw CuiException("${api} failed: ${lastSdlError()}")
    }
    value
}

/**
 * Throws `CuiException` when SDL reports an invalid weekday result.
 */
internal func ensureWeekday(value: Int32, api: String): Weekday {
    match (weekdayFromCode(value)) {
        case Some(day) => day
        case None => throw CuiException("${api} failed: ${lastSdlError()}")
    }
}
